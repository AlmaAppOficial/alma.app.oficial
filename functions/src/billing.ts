// ─────────────────────────────────────────────────────────────────────────────
// DRAFT — validação server-side de compras Android (Google Play Billing).
//
// ⚠️  NÃO DEPLOYADO. O deploy é do Felipe (ver passos no fim deste arquivo).
//
// O que esta função faz:
//   1. Recebe `purchaseToken` + `productId` do app Android (chamada autenticada).
//   2. Valida a assinatura com a Google Play Developer API (purchases.subscriptionsv2).
//   3. Se ativa, **seta o custom claim `isPremium: true`** no Firebase Auth.
//   4. Grava um registro de auditoria em `users/{uid}` (Firestore).
//
// 🔑  POR QUE CUSTOM CLAIM (e não só Firestore):
//   O gate premium do app — iOS (`AccessManager`) e Android (`AccessRepository`)
//   — lê o **custom claim `isPremium` do ID token**, NÃO um campo do Firestore.
//   Setar só o Firestore (como no rascunho inicial do M5) NÃO destravaria nada.
//   Por isso a verdade do entitlement aqui é o claim; o Firestore é só auditoria.
//   Depois de setar o claim, o cliente força `getIdToken(refresh=true)` para ele
//   valer na hora (BillingRepository.validatePending faz isso).
//
// Padrão: firebase-functions v2 (`onCall`), igual ao resto do index.ts.
// ─────────────────────────────────────────────────────────────────────────────

import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { google } from 'googleapis';

// admin.initializeApp() já roda no index.ts ao importar este módulo. O guard
// cobre o caso de este arquivo ser carregado isoladamente (testes/scripts).
if (admin.apps.length === 0) {
  admin.initializeApp();
}

/** Package name do app Android (= applicationId do build.gradle.kts). */
const ANDROID_PACKAGE = 'com.almaapp.app';

export const validateAndroidPurchase = onCall(
  {
    region: 'southamerica-east1',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (request) => {
    // ── Autenticação ──────────────────────────────────────────────────────
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login obrigatório.');
    }
    const uid = request.auth.uid;

    // ── Validação de entrada ──────────────────────────────────────────────
    const data = (request.data ?? {}) as {
      purchaseToken?: unknown;
      productId?: unknown;
    };
    const purchaseToken = typeof data.purchaseToken === 'string' ? data.purchaseToken : '';
    const productId = typeof data.productId === 'string' ? data.productId : '';

    if (!purchaseToken || !productId) {
      throw new HttpsError('invalid-argument', 'purchaseToken e productId são obrigatórios.');
    }

    // ── Cliente autenticado da Google Play Developer API ──────────────────
    // Credencial: Application Default Credentials da conta de serviço das
    // Functions. Essa conta precisa ter acesso concedido no Play Console
    // (ver passos de deploy no fim do arquivo). Sem esse acesso, a chamada
    // falha com 401/403.
    const auth = new google.auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    const androidpublisher = google.androidpublisher({ version: 'v3', auth });

    let isActive = false;
    let expiryTimeMillis: number | null = null;

    try {
      // subscriptionsv2 expõe `subscriptionState` (enum) — mais robusto que a
      // API v1 (paymentState + comparação de strings de expiryTimeMillis, que
      // era a fonte do bug no rascunho original).
      const res = await androidpublisher.purchases.subscriptionsv2.get({
        packageName: ANDROID_PACKAGE,
        token: purchaseToken,
      });

      const state = res.data.subscriptionState ?? '';

      // Expiração: maior expiryTime entre os line items (RFC3339 → millis).
      const expiries = (res.data.lineItems ?? [])
        .map((li) => (li.expiryTime ? Date.parse(li.expiryTime) : NaN))
        .filter((n) => !Number.isNaN(n));
      expiryTimeMillis = expiries.length ? Math.max(...expiries) : null;

      const notExpired = expiryTimeMillis === null || expiryTimeMillis > Date.now();

      // Ativo: ACTIVE/GRACE liberam direto; CANCELED (auto-renovação desligada)
      // ainda dá acesso até expirar.
      isActive =
        state === 'SUBSCRIPTION_STATE_ACTIVE' ||
        state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' ||
        (state === 'SUBSCRIPTION_STATE_CANCELED' && notExpired);
    } catch (err) {
      console.error('[billing] Falha ao validar compra com a Google Play API:', err);
      throw new HttpsError('internal', 'Não foi possível validar a compra agora.');
    }

    // ── Aplica o entitlement ──────────────────────────────────────────────
    //
    // [2026-08-06 — decisão do Assis: "mínimo agora, RTDN depois"]
    //
    // ANTES: esta função escrevia SÓ o custom claim e `users/{uid}`. A função
    // `chat` não lê nenhum dos dois — ela lê `entitlements/{uid}`. Então o
    // assinante Android era validado com sucesso e mesmo assim caía no limite
    // de 20 mensagens/hora do não-assinante, igualzinho ao iOS, por um caminho
    // diferente.
    //
    // AGORA: `entitlements/{uid}` é a fonte de verdade ÚNICA do servidor, e a
    // Google escreve nela como a Apple escreve. Com `expiresAt` real, o acesso
    // EXPIRA SOZINHO — que é a metade barata de consertar do problema abaixo.
    //
    // ⚠️ DÍVIDA CONHECIDA E ACEITA — RTDN (Real-time Developer Notifications)
    // Esta função só roda quando o APP a chama. Reembolso, cancelamento e
    // expiração acontecem no servidor da Google e nunca chegam aqui. Sem RTDN:
    //   • o `expiresAt` limita o estrago a, no máximo, um ciclo de cobrança
    //     (antes era acesso eterno — o claim subia e ninguém nunca o derrubava);
    //   • um REEMBOLSO no meio do ciclo continua sem cortar o acesso na hora.
    // Fechar isso exige endpoint Pub/Sub + configuração no Play Console.
    //
    // ⚠️ O CLAIM CONTINUA SÓ SUBINDO, de propósito. `isPremium` é o gate do
    // CLIENTE Android (`AccessRepository`), não do servidor. Rebaixá-lo aqui
    // seria mexer no acesso de gente em campo sem poder testar num device —
    // e o device de teste não está disponível nesta sessão. O servidor, que é
    // o que estava sangrando, já passa a ver a verdade por `entitlements`.
    const db = admin.firestore();

    await db.doc(`entitlements/${uid}`).set(
      {
        active: isActive,
        productId,
        expiresAt: expiryTimeMillis
          ? admin.firestore.Timestamp.fromMillis(expiryTimeMillis)
          : null,
        origem: 'google',
        motivo: isActive
          ? `assinatura Google ativa${expiryTimeMillis ? ` até ${new Date(expiryTimeMillis).toISOString()}` : ''}`
          : 'assinatura Google não está ativa',
        atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    if (isActive) {
      // Custom claim — gate do cliente Android (preserva claims já existentes).
      const userRecord = await admin.auth().getUser(uid);
      const existingClaims = userRecord.customClaims ?? {};
      await admin.auth().setCustomUserClaims(uid, {
        ...existingClaims,
        isPremium: true,
      });

      // Auditoria no Firestore (não é fonte de verdade de nada).
      await db.doc(`users/${uid}`).set(
        {
          isPremium: true,
          subscriptionSource: 'android',
          subscriptionProductId: productId,
          subscriptionExpiryMillis: expiryTimeMillis,
          subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    return { isPremium: isActive, expiryTimeMillis };
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// PASSOS DE DEPLOY (Felipe) — fazer só quando o produto estiver no Play Console:
//
//   1. Expor a função no index.ts:
//        adicionar  ->  export * from './billing';
//
//   2. Instalar a dependência da Google API (ainda não está no package.json):
//        cd functions && npm install googleapis
//
//   3. Dar acesso à conta de serviço das Functions no Play Console:
//        Play Console → Users and permissions → conceder à service account
//        (a do projeto Firebase, normalmente
//         <project>@appspot.gserviceaccount.com) a permissão
//        "View financial data / Manage orders & subscriptions".
//        (Pode levar até ~24h para propagar.)
//
//   4. Criar a assinatura no Play Console com o productId:
//        alma_premium_monthly   (= BillingRepository.SUBSCRIPTION_ID no Android)
//        com base plan mensal a R$ 24,90.
//
//   5. Deploy:
//        firebase deploy --only functions:validateAndroidPurchase
// ─────────────────────────────────────────────────────────────────────────────
