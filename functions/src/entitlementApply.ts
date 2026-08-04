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
 * Quem faz a ponte é o app: ao entrar, ao comprar e ao restaurar, ele chama
 * `vincularAssinatura` com o `originalTransactionId` da própria conta. Guardamos
 * em `apple_transaction_links/{originalTransactionId} → { uid }`.
 *
 * Sem esse vínculo, a notificação chega, é verificada, é persistida — e fica
 * esperando. `reprocessarPendentes` existe para isso: quando o vínculo aparece,
 * o histórico guardado desde 04/08 é aplicado, e ninguém perde assinatura por
 * ter comprado antes de o vínculo existir.
 */
import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { decidirEstado, EventoApple, EstadoEntitlement } from './entitlementState';

const COLECAO_VINCULO = 'apple_transaction_links';
const COLECAO_ENTITLEMENT = 'entitlements';
const COLECAO_NOTIFS = 'apple_notifications';

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
 * @returns o que aconteceu — para o log e para o campo `processada`.
 */
export async function aplicarEvento(
  db: FirebaseFirestore.Firestore,
  evento: EventoApple,
  agoraMs: number = Date.now(),
): Promise<{ aplicado: boolean; motivo: string; estado: EstadoEntitlement }> {
  const estado = decidirEstado(evento, agoraMs);

  if (!estado.deveGravar) {
    return { aplicado: false, motivo: estado.motivo, estado };
  }
  const tx = estado.originalTransactionId;
  if (!tx) {
    return { aplicado: false, motivo: 'sem originalTransactionId', estado };
  }

  const uid = await uidDaTransacao(db, tx);
  if (!uid) {
    // Não é erro: é ordem de chegada. A notificação fica guardada e
    // `reprocessarPendentes` a aplica assim que o app vincular.
    return { aplicado: false, motivo: `sem vínculo para a transação ${tx}`, estado };
  }

  await db.collection(COLECAO_ENTITLEMENT).doc(uid).set(
    {
      active: estado.active,
      productId: estado.productId,
      expiresAt: estado.expiresAtMs
        ? admin.firestore.Timestamp.fromMillis(estado.expiresAtMs)
        : null,
      originalTransactionId: tx,
      ambiente: estado.ambiente,
      motivo: estado.motivo,
      atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { aplicado: true, motivo: estado.motivo, estado };
}

/**
 * Aplica as notificações que já chegaram mas ficaram sem dono.
 * Chamada depois de um vínculo novo — em ordem cronológica, para que o último
 * evento seja o que fica valendo.
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
    if (r.aplicado) {
      await doc.ref.update({ processada: true, resultado: r.motivo });
      aplicadas += 1;
    }
  }
  return aplicadas;
}

/**
 * Chamado pelo app: "esta transação é minha".
 *
 * Segurança: o uid vem do token do Firebase Auth, NUNCA do corpo da chamada.
 * O cliente só informa o `originalTransactionId` — que sozinho não concede nada,
 * porque quem decide o estado é a notificação assinada pela Apple.
 *
 * Se duas contas reivindicarem a mesma transação, a última ganha e o histórico
 * fica no documento: é o comportamento da Apple para conta trocada no aparelho,
 * e o registro permite investigar abuso depois.
 */
export const vincularAssinatura = onCall(
  { region: 'southamerica-east1' },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Precisa estar autenticado.');
    }
    const tx = (req.data as { originalTransactionId?: unknown })?.originalTransactionId;
    if (typeof tx !== 'string' || tx.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'originalTransactionId ausente.');
    }
    const transacao = tx.trim();

    const db = admin.firestore();
    await db.collection(COLECAO_VINCULO).doc(transacao).set(
      {
        uid,
        vinculadoEm: admin.firestore.FieldValue.serverTimestamp(),
        historicoDeUids: admin.firestore.FieldValue.arrayUnion(uid),
      },
      { merge: true },
    );

    const aplicadas = await reprocessarPendentes(db, transacao);
    console.info(`[entitlement] vínculo ${transacao} → ${uid}; ${aplicadas} pendente(s) aplicada(s)`);
    return { ok: true, pendentesAplicadas: aplicadas };
  },
);
