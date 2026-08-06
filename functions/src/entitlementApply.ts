/**
 * Peça 4 — parte 2: do evento decidido até o Firestore, e o vínculo transação→uid.
 *
 * A decisão vive em `entitlementState.ts` e é função pura (testada por mutação).
 * Aqui mora o acoplamento com o mundo, de propósito burro: resolver o uid,
 * gravar, registrar. Quanto menos regra houver neste arquivo, melhor.
 *
 * O VÍNCULO — o que faltava para tudo funcionar
 *
 * A Apple não sabe quem é o usuário do Alma. Ela fala em `originalTransactionId`.
 * Quem faz a ponte é o app: ao entrar, ao comprar e ao restaurar, ele manda a
 * TRANSAÇÃO ASSINADA (`Transaction.jwsRepresentation`) para `vincularAssinatura`.
 * Guardamos em `apple_transaction_links/{originalTransactionId} → { uid }`.
 *
 * [2026-08-06 — decisão do Assis: desenho B2] O app manda o JWS, não o id solto.
 * A diferença é a prova: um `originalTransactionId` é só uma string, e quem
 * soubesse o id de outra pessoa reivindicaria a assinatura dela — e a TIRARIA
 * do dono, porque o último vínculo vence. O JWS é assinado pela Apple e passa
 * pela mesma cadeia de verificação do webhook, até a raiz Apple Root CA G3.
 *
 * O segundo ganho do B2 é operacional e vale tanto quanto: a transação assinada
 * já traz `expiresDate` e `productId`, então o vínculo e o entitlement são
 * gravados NA MESMA CHAMADA. A compra vale na hora, sem esperar o webhook, e
 * toda abertura do app reconcilia o estado — um webhook perdido ou atrasado não
 * deixa mais ninguém pagante trancado do lado de fora.
 *
 * LIMITE HONESTO DESTE DESENHO: o JWS prova que a APPLE emitiu aquela compra,
 * não que ela pertence a quem está mandando. Quem obtiver o JWS de outra pessoa
 * (aparelho comprometido, backup vazado) consegue reivindicar. É o padrão da
 * indústria e não há como fazer melhor com o que a Apple expõe; o histórico de
 * uids fica registrado no vínculo justamente para permitir investigar depois.
 */
import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { decidirEstado, EventoApple, EstadoEntitlement } from './entitlementState';
import { eventoDeTransacao } from './appleEvento';
import {
  verificarTransacao,
  AssinaturaInvalida,
  PRODUTOS_DE_ASSINATURA,
} from './appleVerificador';

const COLECAO_VINCULO = 'apple_transaction_links';
const COLECAO_ENTITLEMENT = 'entitlements';
const COLECAO_NOTIFS = 'apple_notifications';

export interface ResultadoAplicacao {
  aplicado: boolean;
  motivo: string;
  estado: EstadoEntitlement;
  /**
   * `true` só quando falhou por FALTA DE VÍNCULO — o único motivo que o tempo
   * resolve sozinho. Qualquer outro "não aplicado" é definitivo e a notificação
   * deve ser marcada como processada, senão fica sendo retentada para sempre.
   */
  pendente: boolean;
}

/** Descobre de quem é a transação. `null` quando o app ainda não vinculou. */
export async function uidDaTransacao(
  db: FirebaseFirestore.Firestore,
  originalTransactionId: string,
): Promise<string | null> {
  const doc = await db.collection(COLECAO_VINCULO).doc(originalTransactionId).get();
  if (!doc.exists) return null;
  const uid = doc.data()?.uid;
  return typeof uid === 'string' && uid.length > 0 ? uid : null;
}

/**
 * Aplica um evento já verificado.
 *
 * IDEMPOTÊNCIA E ORDEM — o que esta função protege
 *
 * A Apple reentrega até receber 200, e não garante ordem. Duas coisas diferentes
 * precisam de defesa:
 *
 *   1. REPETIÇÃO — aplicar o mesmo evento duas vezes. Inofensivo por
 *      construção: a gravação é o estado inteiro, não um incremento. Gravar
 *      "ativo até 4 de setembro" mil vezes dá o mesmo documento.
 *
 *   2. ORDEM — este é o que morde. `set(merge)` é o último a chegar vence.
 *      Se um `DID_RENEW` de terça for reentregue depois do `REFUND` de quarta,
 *      o reembolsado volta a ter acesso. Por isso guardamos `ultimoEventoMs` e
 *      recusamos evento mais antigo que o já aplicado.
 *
 *      EXCEÇÃO: `REFUND` e `REVOKE` vencem mesmo fora de ordem. Perder um corte
 *      de acesso custa dinheiro do dono e é irreversível na prática; aplicar um
 *      corte a mais custa um suporte. Coerente com o princípio declarado em
 *      `entitlementState.ts`: na dúvida, NÃO é assinante.
 *
 * Tudo dentro de uma transação do Firestore: ler-decidir-gravar sem janela.
 */
export async function aplicarEvento(
  db: FirebaseFirestore.Firestore,
  evento: EventoApple,
  agoraMs: number = Date.now(),
): Promise<ResultadoAplicacao> {
  const estado = decidirEstado(evento, agoraMs);

  if (!estado.deveGravar) {
    return { aplicado: false, motivo: estado.motivo, estado, pendente: false };
  }
  const tx = estado.originalTransactionId;
  if (!tx) {
    return { aplicado: false, motivo: 'sem originalTransactionId', estado, pendente: false };
  }

  const uid = await uidDaTransacao(db, tx);
  if (!uid) {
    // Não é erro: é ordem de chegada. A notificação fica guardada e
    // `reprocessarPendentes` a aplica assim que o app vincular.
    return {
      aplicado: false,
      motivo: `sem vínculo para a transação ${tx}`,
      estado,
      pendente: true,
    };
  }

  const cortePrioritario = evento.tipo === 'REFUND' || evento.tipo === 'REVOKE';
  const novoMs = evento.signedDateMs ?? null;
  const ref = db.collection(COLECAO_ENTITLEMENT).doc(uid);

  const resultado = await db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    const anteriorMs = (snap.data()?.ultimoEventoMs as number | undefined) ?? null;

    // A guarda só age quando os DOIS lados têm data. Evento sem `signedDate`
    // (histórico antigo, teste) passa direto — é o comportamento de antes, e
    // recusar por falta de data travaria o documento para sempre.
    if (!cortePrioritario && anteriorMs !== null && novoMs !== null && novoMs <= anteriorMs) {
      return {
        aplicado: false,
        motivo: `evento de ${new Date(novoMs).toISOString()} é mais antigo que o último aplicado — ignorado`,
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
        originalTransactionId: tx,
        ambiente: estado.ambiente,
        motivo: estado.motivo,
        origem: 'apple',
        // Nunca regride: um corte fora de ordem não pode rebaixar o relógio e
        // reabrir a porta para o evento antigo seguinte.
        ultimoEventoMs: Math.max(anteriorMs ?? 0, novoMs ?? 0) || null,
        atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { aplicado: true, motivo: estado.motivo };
  });

  return { ...resultado, estado, pendente: false };
}

/**
 * Aplica as notificações que já chegaram mas ficaram sem dono.
 * Chamada depois de um vínculo novo — em ordem cronológica, para que o último
 * evento seja o que fica valendo.
 *
 * [2026-08-06] Esta função estava quebrada de nascença e de forma SILENCIOSA:
 * consultava `originalTransactionId` e lia `evento`, dois campos que o
 * `appleNotifications.ts` nunca gravou (ele gravava `payload` cru). A consulta
 * achava zero documentos, devolvia 0, e nada no log dizia que estava cega.
 * Agora o webhook grava os dois campos e a consulta encontra de verdade.
 */
export async function reprocessarPendentes(
  db: FirebaseFirestore.Firestore,
  originalTransactionId: string,
  agoraMs: number = Date.now(),
): Promise<number> {
  const pendentes = await db
    .collection(COLECAO_NOTIFS)
    .where('originalTransactionId', '==', originalTransactionId)
    .where('processada', '==', false)
    .orderBy('recebidaEm', 'asc')
    .get();

  let aplicadas = 0;
  for (const doc of pendentes.docs) {
    const ev = doc.data()?.evento as EventoApple | undefined;
    if (!ev) continue;
    const r = await aplicarEvento(db, ev, agoraMs);
    // Só continua pendente o que falhou por falta de vínculo. "Evento antigo",
    // "sem efeito" e "tipo desconhecido" são veredictos finais — deixá-los
    // pendentes faria a fila crescer para sempre.
    if (!r.pendente) {
      await doc.ref.update({ processada: true, resultado: r.motivo });
    }
    if (r.aplicado) aplicadas += 1;
  }
  return aplicadas;
}

/**
 * Grava o vínculo transação→uid e aplica o estado que a transação afirma.
 * Separado do endpoint para poder ser exercitado no emulador sem HTTP.
 */
export async function vincularEAplicar(
  db: FirebaseFirestore.Firestore,
  uid: string,
  transacao: {
    originalTransactionId?: string;
    productId?: string;
    expiresDate?: number;
    revocationDate?: number;
    signedDate?: number;
    environment?: string;
  },
  agoraMs: number = Date.now(),
): Promise<{ ok: boolean; motivo: string; ativo: boolean; pendentesAplicadas: number }> {
  const tx = transacao.originalTransactionId;
  if (!tx) {
    return { ok: false, motivo: 'transação sem originalTransactionId', ativo: false, pendentesAplicadas: 0 };
  }

  // Produto que não é assinatura nossa não vira entitlement. Sem esta guarda,
  // qualquer compra verificada do bundle concederia Premium.
  if (!transacao.productId || !PRODUTOS_DE_ASSINATURA.has(transacao.productId)) {
    return {
      ok: false,
      motivo: `produto fora da lista de assinaturas: ${transacao.productId ?? 'ausente'}`,
      ativo: false,
      pendentesAplicadas: 0,
    };
  }

  await db.collection(COLECAO_VINCULO).doc(tx).set(
    {
      uid,
      vinculadoEm: admin.firestore.FieldValue.serverTimestamp(),
      historicoDeUids: admin.firestore.FieldValue.arrayUnion(uid),
    },
    { merge: true },
  );

  const r = await aplicarEvento(db, eventoDeTransacao(transacao, agoraMs), agoraMs);
  const pendentesAplicadas = await reprocessarPendentes(db, tx, agoraMs);

  return {
    ok: true,
    motivo: r.motivo,
    ativo: r.estado.active && r.aplicado,
    pendentesAplicadas,
  };
}

/**
 * Chamado pelo app: "esta compra é minha, e aqui está a prova da Apple".
 *
 * `onRequest` e não `onCall` DE PROPÓSITO: o app iOS não linka o SDK
 * FirebaseFunctions (ver `Feed/FeedRepository.swift:10`), e todo o tráfego dele
 * já é HTTPS puro com `Authorization: Bearer <idToken>` — o mesmo padrão do
 * `chat`. Um `onCall` obrigaria a adicionar o SDK ou a imitar o envelope
 * `{data:…}/{result:…}` na mão. Este endpoint fala a língua que o app já fala.
 *
 * Segurança: o uid vem SEMPRE do ID token verificado, NUNCA do corpo.
 */
export const vincularAssinatura = onRequest(
  { region: 'southamerica-east1', cors: false, timeoutSeconds: 30 },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Método não permitido.' });
      return;
    }

    const authHeader = (req.headers.authorization as string | undefined) ?? '';
    if (!authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Não autorizado.' });
      return;
    }

    let uid: string;
    try {
      uid = (await admin.auth().verifyIdToken(authHeader.slice(7))).uid;
    } catch {
      res.status(401).json({ error: 'Token inválido ou expirado.' });
      return;
    }

    const jws = (req.body as { jws?: unknown })?.jws;
    if (typeof jws !== 'string' || jws.trim().length === 0) {
      res.status(400).json({ error: 'Campo "jws" é obrigatório.' });
      return;
    }

    let transacao;
    try {
      transacao = (await verificarTransacao(jws.trim())).valor;
    } catch (e) {
      if (e instanceof AssinaturaInvalida) {
        console.error(`[entitlement] JWS REJEITADO para ${uid}: ${e.detalhes.join(' | ')}`);
        res.status(401).json({ error: 'transação não verificada' });
        return;
      }
      throw e;
    }

    const db = admin.firestore();
    const r = await vincularEAplicar(db, uid, transacao);

    if (!r.ok) {
      console.warn(`[entitlement] vínculo recusado para ${uid}: ${r.motivo}`);
      res.status(400).json({ error: r.motivo });
      return;
    }

    console.info(
      `[entitlement] vínculo ${transacao.originalTransactionId} → ${uid}; ` +
        `ativo=${r.ativo}; ${r.pendentesAplicadas} pendente(s) aplicada(s); ${r.motivo}`,
    );
    res.status(200).json({
      ok: true,
      ativo: r.ativo,
      pendentesAplicadas: r.pendentesAplicadas,
    });
  },
);
