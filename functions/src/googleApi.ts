/**
 * A única porta de saída para a Google Play Developer API.
 *
 * Existe por dois motivos, e o segundo é o que dói:
 *
 * 1. O RTDN não traz estado. Toda decisão de acesso precisa de uma consulta a
 *    `purchases.subscriptionsv2.get`, então essa chamada nasceria duplicada
 *    entre `billing.ts` (validação vinda do app) e `googleNotifications.ts`
 *    (notificação vinda da Google). Duplicada, ela divergiria.
 *
 * 2. O NOME DO PACOTE ESTAVA ERRADO. Até 13/08 o `billing.ts` consultava
 *    `com.almaapp.app` — que é o applicationId do app ANTIGO, suspenso nesta
 *    conta. O app novo é `com.almaapp.android` (`alma-android/app/build.gradle.kts`,
 *    linha 36; o `com.almaapp.app` de lá é o `namespace`, que é outra coisa e é
 *    de onde vem a confusão). Consulta com o pacote errado não devolve dado
 *    errado: devolve 404/403, cai no `catch` e vira "não foi possível validar a
 *    compra agora". Ninguém assinaria nada no Android, e o log culparia a
 *    credencial. Com a constante em UM lugar, esse erro não volta por descuido.
 *
 * ⚠️ CONFERIR COM O ASSIS ANTES DO DEPLOY: se o produto de assinatura for
 * criado sob outro pacote, é ESTA constante que muda — e ela é a única.
 */
import { google } from 'googleapis';

/** applicationId do app Android em produção. NÃO é o `namespace` do Gradle. */
export const PACOTE_ANDROID = 'com.almaapp.android';

export interface FatosDaAssinatura {
  /** `subscriptionState` da API. */
  estado: string | null;
  /** Maior `expiryTime` entre os line items, em ms. */
  expiraEmMs: number | null;
  /** `productId` do primeiro line item — o que a Google acha que foi comprado. */
  productId: string | null;
}

/**
 * Pergunta à Google o que ela sabe sobre esta compra.
 *
 * Credencial: Application Default Credentials da conta de serviço das Functions.
 * Ela precisa ter acesso concedido no Play Console (passo do Assis, no fim de
 * `billing.ts`). Sem isso, a chamada falha com 401/403.
 *
 * LANÇA em qualquer falha, de propósito. Quem chama decide o que fazer com o
 * silêncio da Google, e as duas respostas certas são diferentes:
 *   • `billing.ts` (app esperando): devolve erro para o app tentar de novo;
 *   • `googleNotifications.ts`: deixa a notificação PENDENTE e não grava nada —
 *     jamais interpreta o silêncio como "não é assinante".
 */
export async function consultarAssinatura(purchaseToken: string): Promise<FatosDaAssinatura> {
  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const androidpublisher = google.androidpublisher({ version: 'v3', auth });

  const res = await androidpublisher.purchases.subscriptionsv2.get({
    packageName: PACOTE_ANDROID,
    token: purchaseToken,
  });

  const itens = res.data.lineItems ?? [];
  const expiries = itens
    .map((li) => (li.expiryTime ? Date.parse(li.expiryTime) : NaN))
    .filter((n) => !Number.isNaN(n));

  return {
    estado: res.data.subscriptionState ?? null,
    expiraEmMs: expiries.length ? Math.max(...expiries) : null,
    productId: itens[0]?.productId ?? null,
  };
}
