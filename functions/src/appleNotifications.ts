/**
 * App Store Server Notifications V2 — endpoint de recebimento.
 *
 * [2026-08-04] Existe para fechar o furo de receita: até aqui o servidor não
 * tinha NENHUMA forma confiável de saber quem é assinante. `users/{uid}` é
 * gravável pelo próprio cliente, então ler premium de lá seria deixar qualquer
 * pessoa se autoconceder assinatura. A verdade passa a vir da Apple.
 *
 * REGRA DESTE ARQUIVO: nada é aceito sem verificação criptográfica. O payload
 * chega como JWS assinado pela Apple; a `app-store-server-library` oficial
 * valida a cadeia até a raiz `Apple Root CA - G3` antes de qualquer decodagem.
 * Um payload forjado é REJEITADO com 401 e registrado.
 *
 * O que este arquivo NÃO faz ainda (peça 4, próxima etapa): escrever
 * `entitlements/{uid}`. Falta o vínculo transação→uid, que exige o app enviar
 * o `originalTransactionId`. Enquanto isso, toda notificação verificada é
 * persistida crua em `apple_notifications/{uuid}` — nenhuma se perde, e quando
 * o vínculo existir dá para reprocessar o histórico.
 */
import { onRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { SignedDataVerifier, Environment } from '@apple/app-store-server-library';

const BUNDLE_ID = 'com.almaapp.app';
const APP_APPLE_ID = 6761478534;

/** Raízes da Apple. Sem elas não há verificação — e sem verificação não há endpoint. */
function raizesDaApple(): Buffer[] {
  const dir = join(__dirname, '..', 'apple_certs');
  return ['AppleRootCA-G3.pem'].map((f) => readFileSync(join(dir, f)));
}

/**
 * Um verificador por ambiente. A Apple manda notificações de Sandbox e de
 * Produção para URLs diferentes, mas o mesmo endpoint pode atender as duas —
 * então tentamos Produção e, se a assinatura não bater, Sandbox.
 */
function verificadores(): { ambiente: Environment; v: SignedDataVerifier }[] {
  const raizes = raizesDaApple();
  return [Environment.PRODUCTION, Environment.SANDBOX].map((ambiente) => ({
    ambiente,
    // `enableOnlineChecks = true`: consulta OCSP da Apple. Mais lento e mais
    // correto — um certificado revogado deixa de ser aceito.
    v: new SignedDataVerifier(raizes, true, ambiente, BUNDLE_ID, APP_APPLE_ID),
  }));
}

export const appleNotifications = onRequest(
  { region: 'southamerica-east1', cors: false, maxInstances: 10 },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const signedPayload = (req.body as { signedPayload?: unknown })?.signedPayload;
    if (typeof signedPayload !== 'string' || signedPayload.length === 0) {
      console.warn('[apple-notif] corpo sem signedPayload');
      res.status(400).json({ error: 'signedPayload ausente' });
      return;
    }

    // ── verificação criptográfica ────────────────────────────────────────────
    let payload: Record<string, unknown> | null = null;
    let ambienteOk: Environment | null = null;
    const erros: string[] = [];

    for (const { ambiente, v } of verificadores()) {
      try {
        payload = (await v.verifyAndDecodeNotification(signedPayload)) as unknown as Record<string, unknown>;
        ambienteOk = ambiente;
        break;
      } catch (e) {
        erros.push(`${ambiente}: ${(e as Error).message}`);
      }
    }

    if (!payload || !ambienteOk) {
      // Não decodificamos nada de um payload que não passou na assinatura.
      console.error('[apple-notif] ASSINATURA INVÁLIDA — rejeitado:', erros.join(' | '));
      res.status(401).json({ error: 'assinatura inválida' });
      return;
    }

    const tipo = String(payload.notificationType ?? '?');
    const subtipo = payload.subtype ? String(payload.subtype) : null;
    const uuid = String(payload.notificationUUID ?? `sem-uuid-${Date.now()}`);

    console.info(
      `[apple-notif] ✅ verificada · ${tipo}${subtipo ? '/' + subtipo : ''} · ${ambienteOk} · ${uuid}`,
    );

    // ── persistência ─────────────────────────────────────────────────────────
    // Idempotente pelo notificationUUID: a Apple reenvia até receber 200, e
    // reenvio não pode virar processamento duplicado.
    try {
      const db = admin.firestore();
      const ref = db.collection('apple_notifications').doc(uuid);
      const jaExiste = (await ref.get()).exists;

      if (jaExiste) {
        console.info(`[apple-notif] ${uuid} já processada — 200 sem reprocessar`);
      } else {
        await ref.set({
          notificationType: tipo,
          subtype: subtipo,
          environment: String(ambienteOk),
          recebidaEm: admin.firestore.FieldValue.serverTimestamp(),
          // Guardamos o payload verificado inteiro: quando o vínculo
          // transação→uid existir, dá para reprocessar o histórico.
          payload: JSON.parse(JSON.stringify(payload)),
          processada: false,
        });
      }
    } catch (e) {
      // Persistir é importante, mas responder 200 à Apple é mais: se
      // devolvermos erro ela reenvia, e o reenvio cai no mesmo problema.
      console.error('[apple-notif] falha ao persistir (respondendo 200 assim mesmo)', e);
    }

    res.status(200).json({ ok: true });
  },
);
