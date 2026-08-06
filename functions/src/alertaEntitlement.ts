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
): Promise<ResumoPendencias> {
  const corte = admin.firestore.Timestamp.fromMillis(agoraMs - dias * DIA_MS);

  const snap = await db
    .collection('apple_notifications')
    .where('processada', '==', false)
    .where('recebidaEm', '<', corte)
    .orderBy('recebidaEm', 'asc')
    .get();

  const transacoes = [
    ...new Set(
      snap.docs
        .map((d) => d.data()?.originalTransactionId)
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

  const r = await apurarPendencias(db, agoraMs, cfg);

  await db.collection('alertas').doc('entitlement_pendentes').set({
    total: r.total,
    transacoes: r.transacoes.slice(0, 50),
    maisAntigaEm: r.maisAntigaEm
      ? admin.firestore.Timestamp.fromDate(r.maisAntigaEm)
      : null,
    diasDeCorte: r.diasDeCorte,
    verificadoEm: admin.firestore.FieldValue.serverTimestamp(),
  });

  if (r.total > 0) {
    // Marcador em MAIÚSCULA e sem acento de propósito: é o texto que o filtro
    // do Cloud Logging procura, e filtro não deve depender de acentuação.
    console.error(
      `[ALERTA-RECEITA] ${r.total} notificacao(oes) da Apple pendente(s) ha mais de ` +
        `${r.diasDeCorte} dia(s) — ha assinante pagando e NAO recebendo. ` +
        `transacoes=${r.transacoes.join(',')} ` +
        `maisAntiga=${r.maisAntigaEm?.toISOString() ?? '?'}`,
    );
  } else {
    console.info(
      `[alerta-entitlement] nenhuma pendencia acima de ${r.diasDeCorte} dia(s).`,
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
