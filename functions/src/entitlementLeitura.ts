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
 */
export async function ehAssinante(
  db: FirebaseFirestore.Firestore,
  uid: string,
): Promise<boolean> {
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
