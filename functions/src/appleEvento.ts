/**
 * Do payload decodificado da Apple até o `EventoApple`. Puro, sem Firestore.
 *
 * [2026-08-06] ESTE ARQUIVO É A PEÇA QUE FALTAVA.
 *
 * `entitlementState.decidirEstado()` estava pronto e testado desde 04/08 — e
 * nunca tinha recebido um evento na vida, porque ninguém construía um.
 * O motivo é sutil e vale registrar: `verifyAndDecodeNotification()` devolve
 * `data.signedTransactionInfo` como uma STRING JWS opaca, não como objeto.
 * Todos os campos que a decisão precisa (`originalTransactionId`, `expiresDate`,
 * `revocationDate`, `productId`) moram DENTRO daquela string, atrás de uma
 * segunda verificação (`verifyAndDecodeTransaction`). Quem lê o payload de
 * fora vê `notificationType` e conclui que já tem tudo. Não tem.
 *
 * Puro de propósito, mesma razão do `entitlementState.ts`: dá para exercitar a
 * conversão inteira com dezenas de casos sem subir emulador e sem rede.
 */
import { EventoApple } from './entitlementState';

/** O que a lib da Apple entrega depois de verificada a transação. */
export interface TransacaoDecodificada {
  originalTransactionId?: string;
  transactionId?: string;
  productId?: string;
  expiresDate?: number;
  revocationDate?: number;
  revocationReason?: number | string;
  signedDate?: number;
  environment?: string;
  type?: string;
}

/** O que a lib entrega depois de verificada a informação de renovação. */
export interface RenovacaoDecodificada {
  gracePeriodExpiresDate?: number;
  autoRenewStatus?: number;
  autoRenewProductId?: string;
  expirationIntent?: number;
  isInBillingRetryPeriod?: boolean;
  signedDate?: number;
}

/** O envelope da notificação, já verificado. */
export interface NotificacaoDecodificada {
  notificationType?: string;
  subtype?: string;
  notificationUUID?: string;
  signedDate?: number;
  data?: { environment?: string };
}

/**
 * Evento a partir de uma NOTIFICAÇÃO (o caminho autoritativo — vale também com
 * o app fechado: renovação, expiração, reembolso).
 *
 * A tolerância (`gracePeriodExpiresDate`) só existe no RenewalInfo, nunca na
 * transação. Sem juntar os dois, todo `DID_FAIL_TO_RENEW/GRACE_PERIOD` cairia
 * em "falha de cobrança sem tolerância vigente" e cortaria o acesso de quem a
 * Apple ainda está tentando cobrar — cliente pagante barrado por um cartão que
 * falhou uma vez.
 */
export function eventoDeNotificacao(
  notificacao: NotificacaoDecodificada,
  transacao: TransacaoDecodificada | null,
  renovacao: RenovacaoDecodificada | null,
): EventoApple {
  return {
    tipo: String(notificacao.notificationType ?? ''),
    subtipo: notificacao.subtype ?? null,
    originalTransactionId: transacao?.originalTransactionId ?? null,
    productId: transacao?.productId ?? null,
    expiresDateMs: transacao?.expiresDate ?? null,
    revocationDateMs: transacao?.revocationDate ?? null,
    gracePeriodExpiresDateMs: renovacao?.gracePeriodExpiresDate ?? null,
    ambiente: notificacao.data?.environment ?? transacao?.environment ?? null,
    signedDateMs: notificacao.signedDate ?? transacao?.signedDate ?? null,
  };
}

/**
 * Evento a partir de uma TRANSAÇÃO SOLTA — o caminho B2, quando o app manda o
 * `jwsRepresentation` da própria compra.
 *
 * Aqui não existe `notificationType`: a Apple não está contando um
 * acontecimento, está afirmando um fato ("esta assinatura existe, deste
 * produto, até esta data"). Traduzimos o fato para o vocabulário de eventos
 * para que a decisão continue passando por UMA função só. Se esta conversão
 * inventasse a sua própria regra de acesso, passariam a existir dois lugares
 * onde "quem é assinante" é decidido — e eles divergiriam.
 *
 * @param agoraMs relógio injetado; teste precisa de tempo determinístico
 */
export function eventoDeTransacao(
  transacao: TransacaoDecodificada,
  agoraMs: number,
): EventoApple {
  const expira = transacao.expiresDate ?? null;
  const revogada = transacao.revocationDate ?? null;

  // Reembolso/revogação: a Apple carimba `revocationDate` na própria transação.
  // Corta na hora, mesmo com a data de expiração ainda no futuro.
  const tipo = revogada
    ? 'REVOKE'
    : expira && expira > agoraMs
      ? 'SUBSCRIBED'
      : 'EXPIRED';

  return {
    tipo,
    subtipo: null,
    originalTransactionId: transacao.originalTransactionId ?? null,
    productId: transacao.productId ?? null,
    expiresDateMs: expira,
    revocationDateMs: revogada,
    // Uma transação nunca carrega tolerância; só o RenewalInfo carrega.
    gracePeriodExpiresDateMs: null,
    ambiente: transacao.environment ?? null,
    signedDateMs: transacao.signedDate ?? null,
  };
}
