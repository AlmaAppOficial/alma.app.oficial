/**
 * Alerta diário: alguém pagou e não está recebendo.
 *
 * [2026-08-06] Isto existe porque o furo que consertamos hoje era INVISÍVEL.
 * O servidor recebia a notificação da Apple, verificava a assinatura, guardava
 * tudo direitinho — e não tinha a quem conceder. Ninguém era avisado. O único
 * jeito de descobrir era alguém reclamar, ou eu ir ler o Firestore à mão.
 *
 * Um assinante preso nesse estado é a pior falha possível do produto: ele pagou,
 * está usando o app, e leva o limite do plano grátis no recurso que comprou.
 * Ele não vai abrir um chamado — vai pedir reembolso e deixar uma avaliação de
 * uma estrela.
 *
 * POR QUE 3 DIAS
 *
 * A pendência é NORMAL nas primeiras horas: a notificação da Apple chega em
 * segundos, e o vínculo só aparece quando a pessoa abre o app com a versão que
 * tem o `AlmaEntitlementBridge`. Alertar cedo demais é ruído garantido, e alerta
 * que grita todo dia sem motivo é alerta que se aprende a ignorar.
 *
 *   • atualização automática do iOS costuma acontecer em 24–48h;
 *   • 3 dias cobre esse prazo com um dia de folga, então o que sobrar depois
 *     disso não é "ainda vai resolver" — é alguém que não vai atualizar sozinho;
 *   • e 3 dias ainda está dentro da janela em que dá para consertar antes de
 *     virar pedido de reembolso.
 *
 * Ajustável sem deploy por `config/alertas.diasPendencia`, porque este número é
 * um palpite educado e a realidade pode desmenti-lo.
 *
 * CANAL: log + Firestore, de propósito. Mandar WhatsApp daqui exigiria o número
 * do Assis num secret e um template aprovado pela Meta — dependência nova e
 * mais uma coisa para quebrar, para avisar de um evento que deve ser raro.
 *   • o log sai com o marcador `[ALERTA-RECEITA]`, que é o texto exato para
 *     criar um alerta no Cloud Logging (instrução no fim do arquivo);
 *   • e o resumo fica em `alertas/entitlement_pendentes`, legível no Console do
 *     Firebase sem rodar comando nenhum.
 */
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';

const DIAS_PADRAO = 3;
const DIA_MS = 86_400_000;

export interface ResumoPendencias {
  total: number;
  transacoes: string[];
  maisAntigaEm: Date | null;
  diasDeCorte: number;
}

/**
 * Conta as notificações que estão pendentes há tempo demais.
 * Separada do agendamento para poder ser exercitada no emulador.
 */
export async function apurarPendencias(
  db: FirebaseFirestore.Firestore,
  agoraMs: number,
  dias: number = DIAS_PADRAO,
  /**
   * [2026-08-13] Qual loja apurar. O parâmetro tem default para não quebrar as
   * chamadas existentes — mas o `google_notifications` NÃO é opcional na
   * prática: uma pendência do Android é exatamente a mesma falha de produto que
   * uma da Apple (alguém pagou e não está recebendo), e um alerta que só olha
   * metade das lojas é um alerta que dá "tudo certo" com gente pagando e
   * trancada do outro lado.
   */
  colecao: 'apple_notifications' | 'google_notifications' = 'apple_notifications',
): Promise<ResumoPendencias> {
  const corte = admin.firestore.Timestamp.fromMillis(agoraMs - dias * DIA_MS);

  const snap = await db
    .collection(colecao)
    .where('processada', '==', false)
    .where('recebidaEm', '<', corte)
    .orderBy('recebidaEm', 'asc')
    .get();

  // A Apple identifica a compra por `originalTransactionId`; a Google, por
  // `purchaseToken`. Um campo por loja, mesma pergunta.
  const chave = colecao === 'google_notifications' ? 'purchaseToken' : 'originalTransactionId';

  const transacoes = [
    ...new Set(
      snap.docs
        .map((d) => d.data()?.[chave])
        .filter((t): t is string => typeof t === 'string' && t.length > 0),
    ),
  ];

  const primeira = snap.docs[0]?.data()?.recebidaEm as
    | FirebaseFirestore.Timestamp
    | undefined;

  return {
    total: snap.size,
    transacoes,
    maisAntigaEm: primeira ? primeira.toDate() : null,
    diasDeCorte: dias,
  };
}

/** Grava o resumo e registra o log. Devolve o resumo, para o teste conferir. */
export async function registrarPendencias(
  db: FirebaseFirestore.Firestore,
  agoraMs: number = Date.now(),
): Promise<ResumoPendencias> {
  const cfg = await db
    .collection('config')
    .doc('alertas')
    .get()
    .then((d) => (d.data()?.diasPendencia as number | undefined) ?? DIAS_PADRAO)
    .catch(() => DIAS_PADRAO);

  const r = await apurarPendencias(db, agoraMs, cfg, 'apple_notifications');
  const g = await apurarPendencias(db, agoraMs, cfg, 'google_notifications');

  await db.collection('alertas').doc('entitlement_pendentes').set({
    total: r.total,
    transacoes: r.transacoes.slice(0, 50),
    maisAntigaEm: r.maisAntigaEm
      ? admin.firestore.Timestamp.fromDate(r.maisAntigaEm)
      : null,
    // Google em campos próprios, e não somado ao total: o conserto de cada lado
    // é diferente (App Store Connect vs. Play Console), então juntar os números
    // só faria alguém procurar no lugar errado.
    totalGoogle: g.total,
    comprasGoogle: g.transacoes.slice(0, 50),
    maisAntigaGoogleEm: g.maisAntigaEm
      ? admin.firestore.Timestamp.fromDate(g.maisAntigaEm)
      : null,
    diasDeCorte: r.diasDeCorte,
    verificadoEm: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Marcador em MAIÚSCULA e sem acento de propósito: é o texto que o filtro
  // do Cloud Logging procura, e filtro não deve depender de acentuação.
  if (r.total > 0) {
    console.error(
      `[ALERTA-RECEITA] ${r.total} notificacao(oes) da Apple pendente(s) ha mais de ` +
        `${r.diasDeCorte} dia(s) — ha assinante pagando e NAO recebendo. ` +
        `transacoes=${r.transacoes.join(',')} ` +
        `maisAntiga=${r.maisAntigaEm?.toISOString() ?? '?'}`,
    );
  }

  if (g.total > 0) {
    console.error(
      `[ALERTA-RECEITA] ${g.total} notificacao(oes) da Google pendente(s) ha mais de ` +
        `${g.diasDeCorte} dia(s) — ha assinante pagando e NAO recebendo. ` +
        `compras=${g.transacoes.join(',')} ` +
        `maisAntiga=${g.maisAntigaEm?.toISOString() ?? '?'}`,
    );
  }

  if (r.total === 0 && g.total === 0) {
    console.info(
      `[alerta-entitlement] nenhuma pendencia acima de ${r.diasDeCorte} dia(s) (Apple nem Google).`,
    );
  }

  return r;
}

/**
 * Todo dia às 9h de Brasília — horário em que dá para agir no mesmo dia.
 */
export const alertaEntitlementPendente = onSchedule(
  {
    schedule: 'every day 09:00',
    timeZone: 'America/Sao_Paulo',
    region: 'southamerica-east1',
  },
  async () => {
    await registrarPendencias(admin.firestore());
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// COMO SER AVISADO DE VERDADE (Felipe — 5 minutos, uma vez só)
//
//   Google Cloud Console → Logging → Logs Explorer
//   filtro:  severity=ERROR AND textPayload:"[ALERTA-RECEITA]"
//   → "Create alert"  → notificação por e-mail
//
// E para consultar a qualquer momento, sem comando:
//   Firebase Console → Firestore → coleção `alertas` → `entitlement_pendentes`
//
// Se um dia isto alertar: o conserto é descobrir o uid dono da transação (App
// Store Connect → a compra) e criar `apple_transaction_links/{tx} → {uid}`.
// `reprocessarPendentes` aplica o histórico guardado sozinho depois disso.
// ─────────────────────────────────────────────────────────────────────────────
