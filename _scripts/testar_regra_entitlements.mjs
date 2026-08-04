/**
 * Prova REAL de que o cliente não escreve em entitlements/{uid}.
 *
 * [2026-08-04] Não é leitura da regra — é uma tentativa de escrita autenticada
 * como usuário comum, pela REST do Firestore, exatamente como o app faria.
 * Esperado: 403 na escrita, 200 na leitura do próprio doc.
 */
import { readFileSync } from 'node:fs';
const PROJETO = 'alma-app-7dae6';
const RAIZ = '/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main';
const API_KEY = readFileSync(`${RAIZ}/Shared/GoogleService-Info.plist`, 'utf8')
  .match(/<key>API_KEY<\/key>\s*<string>([^<]+)<\/string>/)[1];
const cfg = JSON.parse(readFileSync(`${process.env.HOME}/.config/configstore/firebase-tools.json`, 'utf8'));
const tokAdm = (await (await fetch('https://oauth2.googleapis.com/token', {
  method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: cfg.tokens.refresh_token, grant_type: 'refresh_token' }) })).json()).access_token;
const FS = `https://firestore.googleapis.com/v1/projects/${PROJETO}/databases/(default)/documents`;

const u = await (await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
  { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ returnSecureToken: true }) })).json();
const { idToken, localId: uid } = u;
let falhas = 0;
const checa = (id, ok, obs) => { console.log(`${ok ? '✓' : '✗'} ${id} — ${obs}`); if (!ok) falhas++; };

// 1) cliente tenta se autoconceder premium
const w = await fetch(`${FS}/entitlements/${uid}`, { method: 'PATCH',
  headers: { Authorization: `Bearer ${idToken}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ fields: { active: { booleanValue: true } } }) });
checa('R1 cliente NÃO consegue se autoconceder assinatura',
      w.status === 403, `PATCH entitlements/${uid.slice(0, 8)}… → HTTP ${w.status}`);

// 2) cliente tenta escrever no doc de OUTRO usuário
const w2 = await fetch(`${FS}/entitlements/uid-de-outra-pessoa`, { method: 'PATCH',
  headers: { Authorization: `Bearer ${idToken}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ fields: { active: { booleanValue: true } } }) });
checa('R2 cliente NÃO escreve no entitlement de outro', w2.status === 403, `HTTP ${w2.status}`);

// 3) servidor grava, cliente LÊ o próprio (a UI precisa)
await fetch(`${FS}/entitlements/${uid}`, { method: 'PATCH',
  headers: { Authorization: `Bearer ${tokAdm}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ fields: { active: { booleanValue: true } } }) });
const r = await fetch(`${FS}/entitlements/${uid}`, { headers: { Authorization: `Bearer ${idToken}` } });
checa('R3 cliente LÊ o próprio entitlement', r.status === 200, `GET → HTTP ${r.status}`);

// 4) cliente não lê o dos outros
const r2 = await fetch(`${FS}/entitlements/uid-de-outra-pessoa`, { headers: { Authorization: `Bearer ${idToken}` } });
checa('R4 cliente NÃO lê o entitlement de outro', r2.status === 403, `HTTP ${r2.status}`);

// 5) config/limites é invisível ao cliente
const r3 = await fetch(`${FS}/config/limites`, { headers: { Authorization: `Bearer ${idToken}` } });
checa('R5 cliente NÃO lê config/limites', r3.status === 403, `HTTP ${r3.status}`);

await fetch(`${FS}/entitlements/${uid}`, { method: 'DELETE', headers: { Authorization: `Bearer ${tokAdm}` } });
await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${API_KEY}`,
  { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ idToken }) });
console.log(falhas === 0 ? '\n═══ REGRA PROVADA ═══' : `\n═══ ${falhas} FALHA(S) ═══`);
process.exit(falhas ? 1 : 0);
