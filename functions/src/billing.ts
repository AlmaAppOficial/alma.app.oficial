// ─────────────────────────────────────────────────────────────────────────────
// Validação server-side de compras Android (Google Play Billing).
//
// O que esta função faz:
//   1. Recebe `purchaseToken` + `productId` do app Android (chamada autenticada).
//   2. Confere a assinatura com a Google Play Developer API (subscriptionsv2).
//   3. Grava o VÍNCULO `google_purchase_links/{purchaseToken} → { uid }`.
//   4. Aplica o entitlement (Firestore + custom claim) pelo caminho compartilhado.
//
// ─────────────────────────────────────────────────────────────────────────────
// [2026-08-13] O QUE MUDOU, E POR QUÊ — leia antes de mexer
//
// Esta função foi reescrita para deixar de ser um caminho paralelo. Antes ela
// tinha regra própria (lista de estados da API embutida, gravação do Firestore
// na mão, claim só subindo) e era o ÚNICO lugar que concedia acesso no Android.
// Três defeitos vinham disso:
//
//   1. O CLAIM SÓ SUBIA. `isPremium` era setado como `true` e nada, em lugar
//      nenhum, o rebaixava. Como `AccessRepository.currentAccess` lê SÓ o claim,
//      quem fosse reembolsado continuava premium no app para sempre. O comentário
//      que ficava aqui reconhecia isso e chamava de "dívida conhecida e aceita".
//      A dívida está paga: `googleApply.sincronizarClaim` desce o claim quando o
//      entitlement morre, e a decisão de subir/descer/não-mexer é uma função pura
//      (`decidirClaim`) exercitada por asserção.
//
//   2. NÃO HAVIA VÍNCULO. Nada guardava de quem era o `purchaseToken`, então uma
//      notificação da Google (reembolso, expiração) não teria a quem se aplicar
//      nem que já existisse o RTDN. O vínculo é o passo 3 acima.
//
//   3. O NOME DO PACOTE ESTAVA ERRADO — ver `googleApi.ts`. Consultava
//      `com.almaapp.app` (o app antigo, suspenso) em vez de `com.almaapp.android`.
//
// A regra de acesso agora vive em `googleEstado.decidirEstadoGoogle`, a mesma que
// o RTDN usa. Dois caminhos, uma regra: é o que impede o app e a Google de terem
// opiniões diferentes sobre quem é assinante.
// ─────────────────────────────────────────────────────────────────────────────

import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { consultarAssinatura } from './googleApi';
import { vincularEAplicarGoogle } from './googleApply';
import { EventoGoogle, TIPO_VALIDACAO_APP } from './googleEstado';

// admin.initializeApp() já roda no index.ts ao importar este módulo. O guard
// cobre o caso de este arquivo ser carregado isoladamente (testes/scripts).
if (admin.apps.length === 0) {
  admin.initializeApp();
}

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

    // ── O que a Google diz sobre esta compra ──────────────────────────────
    //
    // O `productId` que o app mandou NÃO é usado para decidir nada: quem diz o
    // que foi comprado é a Google. Um cliente adulterado poderia mandar qualquer
    // string aqui, e a única coisa que ele não controla é a resposta da API.
    let fatos;
    try {
      fatos = await consultarAssinatura(purchaseToken);
    } catch (err) {
      console.error('[billing] Falha ao validar compra com a Google Play API:', err);
      throw new HttpsError('internal', 'Não foi possível validar a compra agora.');
    }

    const evento: EventoGoogle = {
      tipo: TIPO_VALIDACAO_APP,
      purchaseToken,
      estadoApi: fatos.estado,
      expiraEmMs: fatos.expiraEmMs,
      productId: fatos.productId ?? productId,
      // Sem `eventoMs`: a validação vinda do app não é um evento datado pela
      // Google, e carimbá-la com o relógio do servidor a faria vencer, na guarda
      // de ordem, notificações legítimas mais recentes. Sem data, ela passa pela
      // guarda sem MOVER o relógio — que é o comportamento correto para uma
      // reconciliação. O que a protege de reabrir acesso indevido é a marca de
      // estorno (`reconcessaoBloqueada`), não a data.
    };

    const db = admin.firestore();
    const r = await vincularEAplicarGoogle(db, uid, evento);

    if (!r.ok) {
      console.warn(`[billing] vínculo recusado para ${uid}: ${r.motivo}`);
      throw new HttpsError('failed-precondition', r.motivo);
    }

    console.info(
      `[billing] compra ${purchaseToken.slice(0, 12)}… → ${uid}; ativo=${r.ativo}; ` +
        `${r.pendentesAplicadas} pendente(s) aplicada(s); ${r.motivo}`,
    );

    // Auditoria no Firestore (não é fonte de verdade de nada — a verdade do
    // servidor é `entitlements/{uid}`, e a do cliente é o custom claim).
    await db.doc(`users/${uid}`).set(
      {
        isPremium: r.ativo,
        subscriptionSource: 'android',
        subscriptionProductId: fatos.productId ?? productId,
        subscriptionExpiryMillis: fatos.expiraEmMs,
        subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { isPremium: r.ativo, expiryTimeMillis: fatos.expiraEmMs };
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// PENDÊNCIAS DO ASSIS — sem elas, este código roda e não serve para nada.
// O roteiro completo, com os nomes exatos, está em
// `PLANO_RTDN_GOOGLE_20260813.md` (raiz do ALMA). Resumo:
//
//   1. Criar a assinatura no Play Console com o productId
//        alma_premium_monthly   (= BillingRepository.SUBSCRIPTION_ID)
//      ⚠️ Em 05/08 o Console dizia "O app ainda não tem assinaturas"
//      (`PLAY_CONSOLE_ESTADO_REAL_20260805.md`). Enquanto não existir, o paywall
//      do Android não funciona e NADA aqui é exercitado.
//
//   2. Dar acesso à conta de serviço das Functions no Play Console:
//      Users and permissions → "View financial data" + "Manage orders and
//      subscriptions". Pode levar ~24h para propagar.
//
//   3. Ativar as Notificações do desenvolvedor em tempo real apontando para o
//      tópico Pub/Sub `alma-play-rtdn` (nome em `googleNotifications.TOPICO_RTDN`).
//
//   4. Deploy (gate do Assis):
//        firebase deploy --only functions:validateAndroidPurchase,functions:googleNotifications
// ─────────────────────────────────────────────────────────────────────────────
