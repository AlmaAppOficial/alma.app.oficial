import { readFileSync } from 'node:fs';
const PROJETO = 'alma-app-7dae6';
const URL_CHAT = 'https://chat-vjtqolhmiq-rj.a.run.app';
const RAIZ = '/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main';
const plist = readFileSync(`${RAIZ}/Shared/GoogleService-Info.plist`, 'utf8');
const API_KEY = plist.match(/<key>API_KEY<\/key>\s*<string>([^<]+)<\/string>/)[1];
const cfg = JSON.parse(readFileSync(`${process.env.HOME}/.config/configstore/firebase-tools.json`, 'utf8'));
const r = await fetch('https://oauth2.googleapis.com/token', {
  method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: cfg.tokens.refresh_token, grant_type: 'refresh_token' }) });
const tok = (await r.json()).access_token;
const FS = `https://firestore.googleapis.com/v1/projects/${PROJETO}/databases/(default)/documents`;

const u = await (await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
  { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ returnSecureToken: true }) })).json();
const { idToken, localId: uid } = u;
console.log('uid:', uid);

const w1 = await fetch(`${FS}/entitlements/${uid}`, { method: 'PATCH',
  headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ fields: { active: { booleanValue: true } } }) });
console.log('write entitlements HTTP', w1.status, (await w1.text()).slice(0, 200));

const w2 = await fetch(`${FS}/config/limites`, { method: 'PATCH',
  headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ fields: {
    rajadaMax: { integerValue: '2' }, rajadaJanelaMs: { integerValue: '300000' },
    diarioMax: { integerValue: '300' }, mensalMax: { integerValue: '3000' } } }) });
console.log('write config HTTP', w2.status, (await w2.text()).slice(0, 300));

const rd = await (await fetch(`${FS}/config/limites`, { headers: { Authorization: `Bearer ${tok}` } })).json();
console.log('leitura config:', JSON.stringify(rd.fields));

for (let i = 1; i <= 4; i++) {
  const res = await fetch(URL_CHAT, { method: 'POST',
    headers: { Authorization: `Bearer ${idToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: `diag ${i}` }) });
  const j = await res.json().catch(() => ({}));
  console.log(`chamada ${i}: HTTP ${res.status} ${j.error ?? ''}`);
}

const rl = await (await fetch(`${FS}/rate_limits/${uid}`, { headers: { Authorization: `Bearer ${tok}` } })).json();
console.log('rate_limits doc:', JSON.stringify(rl.fields ?? rl).slice(0, 400));

for (const p of [`entitlements/${uid}`, 'config/limites', `rate_limits/${uid}`])
  await fetch(`${FS}/${p}`, { method: 'DELETE', headers: { Authorization: `Bearer ${tok}` } });
await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${API_KEY}`,
  { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ idToken }) });
console.log('limpo');
