/**
 * A pergunta "esta pessoa é assinante?", num módulo próprio.
 *
 * [2026-08-06] Isto morava dentro do `index.ts` como função privada. Mudou de
 * casa por um motivo só, e é o motivo certo: era IMPOSSÍVEL de exercitar.
 * Importar `index.ts` num teste dispara `admin.initializeApp()`, o registro de
 * todas as functions e a resolução de secrets — então a única forma de "testar"
 * `ehAssinante` era reescrever a regra dentro do teste. Isso não prova nada
 * sobre o código que roda em produção; é papel pintado, exatamente o que a
 * regra de validação por mutação do CLAUDE.md proíbe.
 *
 * Aqui ela é importada pelo `index.ts` E pelo teste de emulador — o mesmo
 * código nos dois lados, que é o único jeito de a asserção significar algo.
 *
 * A regra em si não mudou uma vírgula: sem documento, `active !== true`, ou
 * data de expiração no passado, a resposta é não. Erro de leitura também é não.
 */

/**
 * Entitlement do usuário — SEMPRE do servidor, nunca do cliente.
 *
 * Lê `entitlements/{uid}`, coleção que o cliente não pode escrever
 * (`firestore.rules`), preenchida apenas pelo servidor a partir da Apple e da
 * Google. Ver a limitação de `web`/`legado` documentada no `index.ts`.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * [2026-08-18] SEGUNDA FONTE ACEITA: o custom claim `isPremium`.
 *
 * Motivo, e ele é concreto. Quando o gate de premium passou a valer no SERVIDOR
 * (antes o chat e o scan só eram trancados no cliente), esta função virou a
 * porta de entrada de tudo que custa dinheiro. E ela deixava DUAS pessoas de
 * fora que deviam entrar:
 *
 *   1. O REVISOR DA APPLE. A conta `contact@almaappoficial.com` tem premium por
 *      `users/{uid}.legacyCorpoEntitlement` — não tem compra, logo não tem
 *      documento em `entitlements/`. Sem esta segunda fonte, o revisor bate no
 *      bloqueio exatamente nas duas funcionalidades de foto que ele foi testar.
 *      Ver a seção "O PREMIUM DO REVISOR VEM DO FIRESTORE" no `CLAUDE.md`, que
 *      já apontava o custom claim como o lugar certo para resolver isso.
 *
 *   2. QUEM ASSINA PELA ORIGEM `web`. O `index.ts` documenta desde 06/08 que
 *      essa origem "vive só no custom claim" e por isso pegava 20 mensagens/hora
 *      apesar de pagar. Isso era bug de receita, não limitação aceitável.
 *
 * POR QUE O CLAIM NÃO REABRE O FURO DE RECEITA que esta coleção existe para
 * fechar: custom claim só se escreve por Admin SDK (`setCustomUserClaims`, ver
 * `googleApply.ts:107`). O cliente não alcança, nem pelas `firestore.rules`. É
 * o oposto de `users/{uid}`, que o próprio dono edita — e é por isso que
 * `legacyCorpoEntitlement` continua NÃO sendo aceito aqui. Ler premium de um
 * documento que o usuário escreve seria autoconcessão de assinatura.
 *
 * CONSEQUÊNCIA ACEITA: a origem `legado` (herdada do Corpo & Alma) segue fora.
 * Quem precisar dela entra pelo claim, posto por servidor.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * @param claims Claims do ID token JÁ VERIFICADO (`verifyIdToken`). Opcional
 *               para não quebrar chamadas antigas — omitir só desliga a
 *               segunda fonte, nunca abre acesso.
 */
export async function ehAssinante(
  db: FirebaseFirestore.Firestore,
  uid: string,
  claims?: Record<string, unknown>,
): Promise<boolean> {
  // Fonte 1 — custom claim. Vem do token já verificado, custa ZERO leitura de
  // Firestore e responde antes do I/O. `=== true` de propósito: "true" (string)
  // ou 1 não valem, para um claim mal escrito não virar assinatura de graça.
  if (claims?.isPremium === true) return true;

  // Fonte 2 — `entitlements/{uid}`, escrito pelos webhooks de Apple e Google.
  try {
    const doc = await db.collection('entitlements').doc(uid).get();
    if (!doc.exists) return false;
    const d = doc.data() ?? {};
    if (d.active !== true) return false;
    const expira = d.expiresAt as FirebaseFirestore.Timestamp | undefined;
    if (expira && expira.toMillis() < Date.now()) return false;
    return true;
  } catch (e) {
    console.error('[entitlement] falha ao ler; tratando como não-assinante', e);
    return false;
  }
}
