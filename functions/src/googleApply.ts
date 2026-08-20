/**
 * Do evento decidido até o Firestore e o custom claim — espelho de
 * `entitlementApply.ts`, com a diferença que dá nome à sessão de 13/08:
 * AQUI O CLAIM TAMBÉM DESCE.
 *
 * O VÍNCULO
 *
 * A Google não sabe quem é o usuário do Alma. Ela fala em `purchaseToken`.
 * Quem faz a ponte é o app: ao comprar, `BillingRepository` chama
 * `validateAndroidPurchase`, que grava
 * `google_purchase_links/{purchaseToken} → { uid }`.
 * É o equivalente exato de `apple_transaction_links`.
 *
 * ⚠️ DIFERENÇA DE PROVA EM RELAÇÃO À APPLE — dita em voz alta porque importa
 * na hora de julgar o risco: o lado Apple recebe um JWS assinado, que o app não
 * consegue forjar. Aqui o `purchaseToken` é uma string opaca vinda do cliente.
 * O que impede alguém de reivindicar a compra de outro é a validação em
 * `billing.ts`: o token é conferido com a Google ANTES de o vínculo ser gravado,
 * e um token que a Google não reconhece não vira vínculo nenhum. Quem obtiver o
 * token de outra pessoa consegue reivindicar — limite do que a Google expõe,
 * igual ao limite declarado do lado Apple. Por isso o histórico de uids fica
 * registrado no vínculo: dá para investigar depois.
 *
 * IDEMPOTÊNCIA E ORDEM — as duas defesas, herdadas do lado Apple
 *
 *   1. REPETIÇÃO é inofensiva por construção: gravamos o ESTADO INTEIRO, nunca
 *      um incremento. Gravar "ativo até 4 de setembro" mil vezes dá o mesmo
 *      documento. (O Pub/Sub reentrega até receber ack — isso vai acontecer.)
 *
 *   2. ORDEM é o que morde. `set(merge)` é "o último a chegar vence". Um
 *      `SUBSCRIPTION_RENEWED` de terça reentregue depois do reembolso de quarta
 *      devolveria acesso a quem foi reembolsado. Por isso `ultimoEventoMs`.
 *
 *      EXCEÇÃO: reembolso e revogação vencem mesmo fora de ordem
 *      (`cortePrioritario`). Perder um corte custa dinheiro do dono e é
 *      irreversível na prática; aplicar um corte a mais custa um suporte.
 */
import * as admin from 'firebase-admin';
import {
  EventoGoogle,
  decidirEstadoGoogle,
  decidirClaim,
  reconcessaoBloqueada,
  escritaBloqueadaPorApple,
  EstadoGoogle,
} from './googleEstado';

const COLECAO_VINCULO = 'google_purchase_links';
const COLECAO_ENTITLEMENT = 'entitlements';
const COLECAO_NOTIFS = 'google_notifications';

export interface ResultadoAplicacaoGoogle {
  aplicado: boolean;
  motivo: string;
  estado: EstadoGoogle;
  /**
   * `true` quando o tempo (ou uma nova tentativa) ainda pode resolver:
   * falta de vínculo, ou API da Google sem responder. Qualquer outro
   * "não aplicado" é definitivo e a notificação deve ser marcada como
   * processada, senão fica sendo retentada para sempre.
   */
  pendente: boolean;
}

/** Descobre de quem é a compra. `null` quando o app ainda não vinculou. */
export async function uidDaCompra(
  db: FirebaseFirestore.Firestore,
  purchaseToken: string,
): Promise<string | null> {
  const doc = await db.collection(COLECAO_VINCULO).doc(purchaseToken).get();
  if (!doc.exists) return null;
  const uid = doc.data()?.uid;
  return typeof uid === 'string' && uid.length > 0 ? uid : null;
}

/**
 * Ajusta o custom claim `isPremium` para bater com o entitlement.
 *
 * ISTO É A METADE QUE FALTAVA. `entitlements/{uid}` é a verdade do SERVIDOR (o
 * `chat` lê de lá). O claim é a verdade do CLIENTE Android: `AccessRepository`
 * não lê Firestore nenhum, lê o claim do ID token. Enquanto o claim não descer,
 * o app do reembolsado continua premium na tela, mesmo com o Firestore correto.
 *
 * O cliente só enxerga a mudança quando o ID token é renovado. `getIdToken(true)`
 * no `AccessRepository` força isso a cada leitura de acesso, então na prática
 * vale na próxima abertura do app — e o token velho expira sozinho em 1h.
 *
 * Preserva os outros claims: `setCustomUserClaims` SUBSTITUI o objeto inteiro,
 * e escrever só `{ isPremium }` apagaria qualquer outro claim da conta em
 * silêncio.
 */
export async function sincronizarClaim(
  uid: string,
  ativo: boolean,
  origemAnterior: string | null,
): Promise<'subiu' | 'rebaixou' | 'inalterado'> {
  const acao = decidirClaim(ativo, origemAnterior);
  if (acao === 'nao_mexer') return 'inalterado';

  const desejado = acao === 'subir';
  const userRecord = await admin.auth().getUser(uid);
  const claims = userRecord.customClaims ?? {};

  // Já está como deve: não gasta escrita nem invalida o token de ninguém à toa.
  if ((claims.isPremium === true) === desejado) return 'inalterado';

  await admin.auth().setCustomUserClaims(uid, { ...claims, isPremium: desejado });
  return desejado ? 'subiu' : 'rebaixou';
}

/**
 * Aplica um evento já colhido: grava `entitlements/{uid}` e acerta o claim.
 * Tudo dentro de uma transação do Firestore: ler-decidir-gravar sem janela.
 */
export async function aplicarEventoGoogle(
  db: FirebaseFirestore.Firestore,
  evento: EventoGoogle,
  agoraMs: number = Date.now(),
): Promise<ResultadoAplicacaoGoogle> {
  const estado = decidirEstadoGoogle(evento, agoraMs);

  if (!estado.deveGravar) {
    // `apiIndisponivel` é o único "não gravou" que vale tentar de novo.
    return {
      aplicado: false,
      motivo: estado.motivo,
      estado,
      pendente: estado.apiIndisponivel,
    };
  }

  const token = estado.purchaseToken;
  if (!token) {
    return { aplicado: false, motivo: 'sem purchaseToken', estado, pendente: false };
  }

  const uid = await uidDaCompra(db, token);
  if (!uid) {
    // Não é erro: é ordem de chegada. Fica guardada e `reprocessarPendentesGoogle`
    // a aplica assim que o app vincular.
    return {
      aplicado: false,
      motivo: `sem vínculo para a compra ${token.slice(0, 12)}…`,
      estado,
      pendente: true,
    };
  }

  const novoMs = evento.eventoMs ?? null;
  const ref = db.collection(COLECAO_ENTITLEMENT).doc(uid);

  const resultado = await db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    // Relógio PRÓPRIO do Google. Não é o `ultimoEventoMs` da Apple, de
    // propósito: as duas lojas datam eventos por relógios independentes, e
    // compartilhar o campo faria um evento recente da Apple levantar a régua e
    // descartar um `EXPIRED`/`ON_HOLD` legítimo da Google como "mais antigo".
    // Reembolso e revogação escapariam pelo `cortePrioritario`, mas expiração e
    // account hold não — e o acesso ficaria vivo até a próxima renovação.
    const anteriorMs = (snap.data()?.ultimoEventoGoogleMs as number | undefined) ?? null;
    const origemAnterior = (snap.data()?.origem as string | undefined) ?? null;
    const estornadoAntes = snap.data()?.estornado === true;
    const mesmoToken = snap.data()?.purchaseToken === token;
    const ativoAnterior = snap.data()?.active === true;

    if (escritaBloqueadaPorApple(origemAnterior, ativoAnterior, estado.active)) {
      return {
        aplicado: false,
        motivo: 'entitlement ativo da Apple — evento da Google não derruba',
        origemAnterior,
      };
    }

    // A guarda só age quando os DOIS lados têm data. Evento sem `eventTimeMillis`
    // passa direto — recusar por falta de data travaria o documento para sempre.
    if (
      !estado.cortePrioritario &&
      anteriorMs !== null &&
      novoMs !== null &&
      novoMs <= anteriorMs
    ) {
      return {
        aplicado: false,
        motivo: `evento de ${new Date(novoMs).toISOString()} é mais antigo que o último aplicado — ignorado`,
        origemAnterior,
      };
    }

    if (reconcessaoBloqueada(estado.active, estornadoAntes, mesmoToken)) {
      return {
        aplicado: false,
        motivo: `compra ${token.slice(0, 12)}… já foi estornada — acesso NÃO é reconcedido`,
        origemAnterior,
      };
    }

    t.set(
      ref,
      {
        active: estado.active,
        productId: estado.productId,
        expiresAt: estado.expiresAtMs
          ? admin.firestore.Timestamp.fromMillis(estado.expiresAtMs)
          : null,
        purchaseToken: token,
        motivo: estado.motivo,
        origem: 'google',
        // A marca do estorno sobrevive ao token; uma compra NOVA a limpa.
        estornado: estado.cortePrioritario ? true : mesmoToken && estornadoAntes,
        // Nunca regride: um corte fora de ordem não pode rebaixar o relógio e
        // reabrir a porta para o evento antigo seguinte.
        ultimoEventoGoogleMs: Math.max(anteriorMs ?? 0, novoMs ?? 0) || null,
        atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { aplicado: true, motivo: estado.motivo, origemAnterior };
  });

  // O claim vive no Auth, não no Firestore: fica FORA da transação, de propósito
  // — não há transação que cubra os dois. A ordem escolhida (Firestore primeiro,
  // claim depois) é a que erra para o lado seguro: se o processo morrer no meio,
  // o servidor já está correto e o cliente é reconciliado na próxima notificação
  // ou na próxima chamada de `validateAndroidPurchase`.
  //
  // ⚠️ LIMITE CONHECIDO (revisão de 13/08): se `setCustomUserClaims` falhar
  // depois de a transação ter passado, `ultimoEventoGoogleMs` já subiu, e a
  // reentrega do MESMO evento cai na guarda de ordem com `aplicado: false` —
  // então o claim não é reajustado por ele. Não é buraco no caminho do dinheiro:
  // reembolso e revogação têm `cortePrioritario` e passam pela guarda de novo, e
  // a validação vinda do app não carrega data. Um `EXPIRED` perdido assim seria
  // corrigido pelo evento seguinte da mesma assinatura. Fica registrado por ser
  // o tipo de coisa que só aparece quando alguém procura.
  let claim: 'subiu' | 'rebaixou' | 'inalterado' = 'inalterado';
  if (resultado.aplicado) {
    claim = await sincronizarClaim(uid, estado.active, resultado.origemAnterior);
    if (claim !== 'inalterado') {
      console.info(`[google-entitlement] claim isPremium ${claim} para ${uid}: ${estado.motivo}`);
    }
  }

  return { ...resultado, estado, pendente: false };
}

/**
 * Aplica as notificações que já chegaram mas ficaram sem dono, em ordem
 * cronológica, para que o último evento seja o que fica valendo.
 *
 * Chamada depois de um vínculo novo. É o mesmo desenho que a Apple, e existe
 * pelo mesmo motivo: a notificação da Google chega em segundos, o vínculo só
 * aparece quando o app chama `validateAndroidPurchase`, e nada garante a ordem.
 */
/**
 * Grava o vínculo compra→uid e aplica o estado que a Google afirma.
 * Separado do endpoint para poder ser exercitado no emulador sem HTTP.
 *
 * Espelha `vincularEAplicar` do lado Apple, inclusive na ordem: vincular
 * PRIMEIRO, aplicar depois, reprocessar pendentes por último. A ordem importa —
 * é ela que faz uma notificação que chegou antes da compra (o caso normal, já
 * que a Google avisa em segundos e o app só chama quando abre) ser aplicada em
 * vez de ficar órfã.
 *
 * ⚠️ DIVERGÊNCIA DECLARADA EM RELAÇÃO À APPLE — não é esquecimento.
 * `vincularEAplicar` (Apple) recusa produto fora de `PRODUTOS_DE_ASSINATURA`,
 * para que uma compra avulsa verificada não vire Premium. Aqui NÃO há lista
 * equivalente, por uma razão de risco: o `productId` do Android ainda não
 * existe no Play Console (`PLAY_CONSOLE_ESTADO_REAL_20260805.md` — "o app ainda
 * não tem assinaturas"), e uma lista fixa com o ID errado transformaria TODA
 * compra legítima em recusa silenciosa — o tipo de falha que este projeto já
 * pagou caro para aprender a evitar.
 *
 * O que segura o buraco enquanto isso: o `productId` que vale é o que a GOOGLE
 * devolve, nunca o que o cliente manda (`billing.ts`), e o app só vende um
 * produto. Quando a assinatura existir de verdade no Console, criar a lista
 * aqui com o ID confirmado — está anotado em `PLANO_RTDN_GOOGLE_20260813.md`.
 */
export async function vincularEAplicarGoogle(
  db: FirebaseFirestore.Firestore,
  uid: string,
  evento: EventoGoogle,
  agoraMs: number = Date.now(),
): Promise<{ ok: boolean; motivo: string; ativo: boolean; pendentesAplicadas: number }> {
  const token = evento.purchaseToken;
  if (!token) {
    return { ok: false, motivo: 'compra sem purchaseToken', ativo: false, pendentesAplicadas: 0 };
  }

  await db.collection(COLECAO_VINCULO).doc(token).set(
    {
      uid,
      productId: evento.productId ?? null,
      vinculadoEm: admin.firestore.FieldValue.serverTimestamp(),
      historicoDeUids: admin.firestore.FieldValue.arrayUnion(uid),
    },
    { merge: true },
  );

  const r = await aplicarEventoGoogle(db, evento, agoraMs);

  // A fila de pendentes é um EXTRA, e não pode derrubar a compra.
  //
  // [2026-08-13, achado na revisão] A consulta de pendentes exige índice
  // composto. Se ele faltar (ou a consulta falhar por qualquer outro motivo), a
  // exceção subiria por `validateAndroidPurchase` e o app receberia `internal`
  // — DEPOIS de o entitlement e o claim já terem sido gravados. O servidor
  // ficaria certo e a pessoa veria erro no exato segundo em que acabou de
  // pagar, que é o pior momento possível para um erro genérico.
  //
  // O índice está em `firestore.indexes.json`; este catch é o cinto além do
  // suspensório, e grita alto para não virar falha silenciosa.
  let pendentesAplicadas = 0;
  try {
    pendentesAplicadas = await reprocessarPendentesGoogle(db, token, agoraMs);
  } catch (err) {
    console.error(
      '[google-entitlement] fila de pendentes falhou (a compra em si foi aplicada):',
      err instanceof Error ? err.message : String(err),
    );
  }

  return {
    ok: true,
    motivo: r.motivo,
    ativo: r.estado.active && r.aplicado,
    pendentesAplicadas,
  };
}

export async function reprocessarPendentesGoogle(
  db: FirebaseFirestore.Firestore,
  purchaseToken: string,
  agoraMs: number = Date.now(),
): Promise<number> {
  const pendentes = await db
    .collection(COLECAO_NOTIFS)
    .where('purchaseToken', '==', purchaseToken)
    .where('processada', '==', false)
    .orderBy('recebidaEm', 'asc')
    .get();

  let aplicadas = 0;
  for (const doc of pendentes.docs) {
    const ev = doc.data()?.evento as EventoGoogle | undefined;
    if (!ev) continue;
    const r = await aplicarEventoGoogle(db, ev, agoraMs);
    if (!r.pendente) {
      await doc.ref.update({ processada: true, resultado: r.motivo });
    }
    if (r.aplicado) aplicadas += 1;
  }
  return aplicadas;
}
