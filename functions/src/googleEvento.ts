/**
 * Do envelope cru da Google para `EventoGoogle` — espelho de `appleEvento.ts`.
 *
 * Função pura, sem rede e sem Firestore, para que o formato do fio seja
 * exercitável por asserção. O erro que este arquivo existe para evitar é o
 * mesmo que quebrou o `reprocessarPendentes` da Apple em 06/08: o webhook
 * gravava um formato e quem lia esperava outro, e nada acusava.
 *
 * O ENVELOPE (referência lida em 13/08/2026):
 *
 *   {
 *     "version": "1.0",
 *     "packageName": "com.almaapp.android",
 *     "eventTimeMillis": "1503349566168",
 *     "subscriptionNotification":  { "notificationType": 4, "purchaseToken": "…" }
 *     // — ou, MUTUAMENTE EXCLUSIVO com o de cima —
 *     "voidedPurchaseNotification": { "purchaseToken": "…", "orderId": "…",
 *                                     "productType": 1, "refundType": 1 }
 *     // — ou "testNotification", "oneTimeProductNotification",
 *     //   "pendingRefundReviewNotification"
 *   }
 *
 * `eventTimeMillis` chega como STRING (a doc mostra `"1503349566168"` entre
 * aspas, apesar de dizer `long`). Converter na entrada, uma vez, em vez de
 * descobrir isso na guarda de ordem, onde `"170…" <= 170…` compara string com
 * número e devolve o contrário do esperado sem erro nenhum.
 */
import { EventoGoogle, TIPOS_ASSINATURA, TIPO_REEMBOLSO, TIPO_TESTE } from './googleEstado';

/** O envelope `DeveloperNotification` já decodificado de base64. */
export interface NotificacaoGoogle {
  version?: string;
  packageName?: string;
  eventTimeMillis?: string | number;
  subscriptionNotification?: {
    version?: string;
    notificationType?: number;
    purchaseToken?: string;
  };
  voidedPurchaseNotification?: {
    purchaseToken?: string;
    orderId?: string;
    productType?: number;
    refundType?: number;
  };
  oneTimeProductNotification?: { purchaseToken?: string; sku?: string; notificationType?: number };
  pendingRefundReviewNotification?: { orderId?: string };
  testNotification?: { version?: string };
}

/** `"1503349566168"` ou `1503349566168` → número. Lixo → `null`. */
export function paraMilissegundos(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v === 'string' && /^\d+$/.test(v.trim())) return Number(v.trim());
  return null;
}

/**
 * Decodifica o campo `data` (base64) de uma mensagem do Pub/Sub.
 * Devolve `null` para qualquer coisa que não seja um JSON de objeto — nunca
 * lança, porque o Pub/Sub reentrega o que lançar, para sempre.
 */
export function decodificarEnvelope(dataBase64: string): NotificacaoGoogle | null {
  try {
    const texto = Buffer.from(dataBase64, 'base64').toString('utf8');
    const obj = JSON.parse(texto);
    return obj && typeof obj === 'object' && !Array.isArray(obj) ? (obj as NotificacaoGoogle) : null;
  } catch {
    return null;
  }
}

/**
 * Converte o envelope no evento que a decisão entende.
 *
 * Devolve `null` quando a notificação não é sobre assinatura nossa — compra
 * avulsa (o Alma não tem) e pedido de revisão de chargeback (que se responde
 * pela API `ReviewRefund`, não mexendo em acesso). Nesses casos não há o que
 * decidir, e inventar um evento só faria a fila de pendentes crescer.
 */
export function eventoDeNotificacao(n: NotificacaoGoogle): EventoGoogle | null {
  const eventoMs = paraMilissegundos(n.eventTimeMillis);

  if (n.voidedPurchaseNotification) {
    const v = n.voidedPurchaseNotification;
    // productType 2 é compra avulsa. O Alma só vende assinatura; se um dia
    // vender, o estorno de avulso não tem nada a ver com o acesso premium.
    if (v.productType === 2) return null;
    return {
      tipo: TIPO_REEMBOLSO,
      purchaseToken: v.purchaseToken ?? null,
      productType: v.productType ?? null,
      refundType: v.refundType ?? null,
      eventoMs,
    };
  }

  if (n.subscriptionNotification) {
    const s = n.subscriptionNotification;
    const numero = s.notificationType;
    // Tipo fora da tabela conhecida vira o rótulo cru. `decidirEstadoGoogle`
    // trata desconhecido como "não mexe" — e o rótulo cru é o que permite
    // descobrir, no Firestore, QUAL número novo a Google passou a mandar.
    const tipo =
      (typeof numero === 'number' ? TIPOS_ASSINATURA[numero] : undefined) ??
      `SUBSCRIPTION_TIPO_${numero ?? 'AUSENTE'}`;
    return {
      tipo,
      purchaseToken: s.purchaseToken ?? null,
      eventoMs,
    };
  }

  if (n.testNotification) {
    // O botão "Enviar notificação de teste" do Play Console. Não tem
    // purchaseToken, então `decidirEstadoGoogle` já o descarta — mas ele
    // precisa chegar lá para ser REGISTRADO: é a única prova, sem uma compra
    // real, de que o cano Play Console → Pub/Sub → esta função está de pé.
    return { tipo: TIPO_TESTE, purchaseToken: null, eventoMs };
  }

  return null;
}
