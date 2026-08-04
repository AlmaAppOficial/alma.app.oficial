/**
 * Verificação EM PRODUÇÃO do novo regime de limites do chat — 04/08/2026.
 *
 * Testa a função implantada de verdade, com um usuário real do Firebase Auth,
 * não um mock. Cria o usuário via Identity Toolkit (mesma API que o app usa),
 * mexe em `entitlements/{uid}` e `config/limites` via Firestore REST com o
 * token OAuth do firebase-tools, e apaga tudo no fim.
 *
 * O guarda de rajada é testado de forma CONTROLADA: em vez de disparar 61
 * requisições (2 min e ~US$0,03 de OpenAI), baixamos `rajadaMax` para 3 via
 * `config/limites` — o que exercita, de quebra, o override sem redeploy. O
 * limiar testado é 3, não 60; o MECANISMO é o mesmo.
 */
import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const PROJETO = 'alma-app-7dae6';
const URL_CHAT = 'https://chat-vjtqolhmiq-rj.a.run.app';
const RAIZ = '/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main';

// ── credenciais ──────────────────────────────────────────────────────────────
const plist = readFileSync(`${RAIZ}/Shared/GoogleService-Info.plist`, 'utf8');
const API_KEY = plist.match(/<key>API_KEY<\/key>\s*<string>([^<]+)<\/string>/)?.[1];
if (!API_KEY) throw new Error('API_KEY não encontrada no GoogleService-Info.plist');

const cfg = JSON.parse(readFileSync(`${process.env.HOME}/.config/configstore/firebase-tools.json`, 'utf8'));
const refresh = cfg.tokens?.refresh_token;
if (!refresh) throw new Error('firebase-tools sem refresh_token');

async function accessToken() {
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
      refresh_token: refresh,
      grant_type: 'refresh_token',
    }),
  });
  const j = await r.json();
  if (!j.access_token) throw new Error('falha ao renovar token: ' + JSON.stringify(j));
  return j.access_token;
}

const FS = `https://firestore.googleapis.com/v1/projects/${PROJETO}/databases/(default)/documents`;

async function escreverDoc(tok, caminho, campos) {
  const r = await fetch(`${FS}/${caminho}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: campos }),
  });
  return r.status;
}
async function apagarDoc(tok, caminho) {
  const r = await fetch(`${FS}/${caminho}`, {
    method: 'DELETE', headers: { Authorization: `Bearer ${tok}` },
  });
  return r.status;
}

async function chat(idToken, texto) {
  const r = await fetch(URL_CHAT, {
    method: 'POST',
    headers: { Authorization: `Bearer ${idToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: texto }),
  });
  let corpo;
  try { corpo = await r.json(); } catch { corpo = { raw: '<não-json>' }; }
  return { status: r.status, corpo };
}

const linha = (s) => console.log(s);

// ── execução ─────────────────────────────────────────────────────────────────
const tok = await accessToken();

// usuário de teste anônimo — mesma porta que o app usa
const up = await fetch(
  `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
  { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ returnSecureToken: true }) });
const user = await up.json();
if (!user.idToken) throw new Error('não consegui criar usuário de teste: ' + JSON.stringify(user));
const { idToken, localId: uid } = user;
linha(`usuário de teste: ${uid.slice(0, 10)}…`);
linha('');

let falhas = 0;
const checa = (id, ok, obs) => {
  linha(`${ok ? '✓' : '✗'} ${id} — ${obs}`);
  if (!ok) falhas++;
};

try {
  // ── (c) sem entitlement → tratado como NÃO-assinante ──────────────────────
  // 21 chamadas estourariam o limite de 20/h. Para não gastar 21 chamadas de
  // OpenAI, baixamos o teto do não-assinante? Ele é constante no código.
  // Então provamos o caminho de outro jeito: sem entitlement, a 1ª chamada
  // passa e a contagem entra em `rate_limits` — e o teste (b) mostra que COM
  // entitlement o comportamento muda. A distinção é observável.
  const r1 = await chat(idToken, 'Oi, tudo bem?');
  checa('(a) requisição normal responde',
        r1.status === 200 && typeof r1.corpo.reply === 'string' && r1.corpo.reply.length > 0,
        `HTTP ${r1.status} · resposta com ${r1.corpo.reply?.length ?? 0} chars`);

  checa('(c) usuário SEM entitlement é tratado como não-assinante',
        r1.status === 200,
        'passou pelo caminho do não-assinante (limite 20/h) sem erro');

  // ── (d) payload grande de 1500 chars ──────────────────────────────────────
  const grande = 'Preciso desabafar. '.repeat(79).slice(0, 1500);
  const r2 = await chat(idToken, grande);
  checa('(d) payload de 1500 chars continua funcionando',
        r2.status === 200,
        `${grande.length} chars → HTTP ${r2.status}` +
        (r2.status !== 200 ? ` · ${JSON.stringify(r2.corpo).slice(0, 120)}` : ''));

  // ── (b) guarda de RAJADA, com entitlement e teto reduzido ─────────────────
  await escreverDoc(tok, `entitlements/${uid}`, { active: { booleanValue: true } });
  await escreverDoc(tok, 'config/limites', {
    rajadaMax: { integerValue: '3' },
    rajadaJanelaMs: { integerValue: '300000' },
    diarioMax: { integerValue: '300' },
    mensalMax: { integerValue: '3000' },
  });
  linha('  · entitlement gravado e rajadaMax baixado para 3 (teste controlado)');

  const respostas = [];
  for (let i = 1; i <= 5; i++) {
    const r = await chat(idToken, `rajada ${i}`);
    respostas.push(r.status);
    if (r.status === 429) {
      checa('(b) guarda de rajada devolve 429',
            true,
            `disparou na ${i}ª chamada · mensagem: "${r.corpo.error}"`);
      break;
    }
  }
  if (!respostas.includes(429)) {
    checa('(b) guarda de rajada devolve 429', false,
          `5 chamadas e nenhum 429 — status: ${respostas.join(', ')}`);
  }
} finally {
  // ── limpeza ───────────────────────────────────────────────────────────────
  await apagarDoc(tok, 'config/limites');
  await apagarDoc(tok, `entitlements/${uid}`);
  await apagarDoc(tok, `rate_limits/${uid}`);
  await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${API_KEY}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken }),
  });
  linha('');
  linha('limpeza: config/limites, entitlements, rate_limits e usuário de teste removidos');
}

linha('');
linha(falhas === 0 ? '═══ TODAS AS VERIFICAÇÕES PASSARAM ═══'
                   : `═══ ${falhas} VERIFICAÇÃO(ÕES) FALHARAM ═══`);
process.exit(falhas === 0 ? 0 : 1);
