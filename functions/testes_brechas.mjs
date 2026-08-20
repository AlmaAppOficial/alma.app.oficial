/**
 * Asserções das correções de 18/08/2026 — as quatro brechas de custo.
 *
 * Roda contra o JS COMPILADO (`lib/`), não contra uma reimplementação: é o
 * mesmo código que vai para produção. Sai com código != 0 se qualquer asserção
 * reprovar, para que o teste de mutação seja objetivo.
 *
 *   cd functions && npm run build && node testes_brechas.mjs
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * O QUE ESTE ARQUIVO PRENDE
 *
 *   G — `ehAssinante`: o gate que passou a valer no servidor. Inclui o caminho
 *       do custom claim, que existe para o revisor da Apple e para a origem
 *       `web` não serem bloqueados.
 *   L — `limitesSeguros`: a faixa do `config/limites`, que antes era spread cru.
 *   S — `chaveDaSemanaISO`: a janela do scan corporal (3 por SEMANA).
 *
 * CANÁRIO: o último bloco planta casos que TÊM de reprovar. Se passarem, este
 * arquivo está cego e o resultado inteiro é descartado — em voz alta.
 * ═══════════════════════════════════════════════════════════════════════════
 */
import { ehAssinante } from './lib/entitlementLeitura.js';
import {
  limitesSeguros, LIMITES_ASSINANTE_PADRAO,
  MENSAL_MAX_ABSOLUTO, DIARIO_MAX_ABSOLUTO, RAJADA_MAX_ABSOLUTO,
} from './lib/limitesDoChat.js';
import { chaveDaSemanaISO } from './lib/analiseDeFoto.js';

let ok = 0;
const falhas = [];

function checa(id, desc, condicao, observado) {
  if (condicao) {
    ok += 1;
    console.log(`  ✓ ${id} ${desc} — ${observado}`);
  } else {
    falhas.push(`${id} ${desc}`);
    console.log(`  ✗ ${id} ${desc} — OBSERVADO: ${observado}`);
  }
}

// ── Dublês de Firestore ────────────────────────────────────────────────────
// `ehAssinante` recebe o `db` por parâmetro, então o dublê exercita o código de
// produção de verdade — não uma cópia da regra dentro do teste.

/** Devolve o documento pedido. Conta quantas leituras houve. */
function dbCom(doc) {
  const espiao = { leituras: 0 };
  return [{
    collection: () => ({
      doc: () => ({
        get: async () => { espiao.leituras += 1; return doc; },
      }),
    }),
  }, espiao];
}

/** Explode se alguém tentar ler. Prova que um caminho NÃO tocou o Firestore. */
const dbQueExplode = {
  collection: () => ({
    doc: () => ({
      get: async () => { throw new Error('LEITURA_INDEVIDA'); },
    }),
  }),
};

const existe = (dados) => ({ exists: true, data: () => dados });
const naoExiste = { exists: false, data: () => undefined };
const ts = (ms) => ({ toMillis: () => ms });

const FUTURO = Date.now() + 30 * 86_400_000;
const PASSADO = Date.now() - 86_400_000;

console.log('═══ BRECHAS DE CUSTO — correções de 18/08 ═══\n');

// ── G — gate de premium ────────────────────────────────────────────────────
console.log('— G: ehAssinante —');
{
  // O caminho do revisor da Apple e da origem `web`. A asserção de "sem
  // leitura" não é preciosismo: se o claim só valesse DEPOIS de consultar o
  // Firestore, uma falha de leitura derrubaria o revisor junto.
  const r = await ehAssinante(dbQueExplode, 'uid', { isPremium: true });
  checa('G1', 'custom claim isPremium concede acesso sem ler o Firestore', r === true, String(r));
}
{
  const [db, espiao] = dbCom(naoExiste);
  const r = await ehAssinante(db, 'uid', { isPremium: 'true' });
  checa('G2', 'claim em STRING não vale (cai para o Firestore e nega)',
        r === false && espiao.leituras === 1, `${r}, leituras=${espiao.leituras}`);
}
{
  const [db] = dbCom(naoExiste);
  const r = await ehAssinante(db, 'uid', { isPremium: 1 });
  checa('G3', 'claim 1 (número) não vale', r === false, String(r));
}
{
  const [db] = dbCom(existe({ active: true, expiresAt: ts(FUTURO) }));
  const r = await ehAssinante(db, 'uid', {});
  checa('G4', 'entitlements ativo e no prazo concede acesso', r === true, String(r));
}
{
  const [db] = dbCom(existe({ active: true, expiresAt: ts(PASSADO) }));
  const r = await ehAssinante(db, 'uid', {});
  checa('G5', 'entitlements ativo mas EXPIRADO nega', r === false, String(r));
}
{
  const [db] = dbCom(naoExiste);
  const r = await ehAssinante(db, 'uid', {});
  checa('G6', 'sem documento e sem claim, nega', r === false, String(r));
}
{
  // `legado` mora em `users/{uid}`, documento que o próprio dono edita. Se um
  // dia alguém "consertar" o legado lendo esse campo aqui, esta asserção cai.
  const [db] = dbCom(existe({ legacyCorpoEntitlement: true }));
  const r = await ehAssinante(db, 'uid', {});
  checa('G7', 'legacyCorpoEntitlement NÃO concede acesso (furo de receita)', r === false, String(r));
}
{
  const r = await ehAssinante(dbQueExplode, 'uid', {});
  checa('G8', 'erro de leitura nega — falha para o lado seguro', r === false, String(r));
}
{
  const [db] = dbCom(existe({ active: true }));
  const r = await ehAssinante(db, 'uid', undefined);
  checa('G9', 'claims omitido não quebra a chamada antiga', r === true, String(r));
}

// ── L — faixa do config/limites ────────────────────────────────────────────
console.log('\n— L: limitesSeguros —');
{
  const l = limitesSeguros({});
  checa('L1', 'documento vazio devolve os padrões',
        l.mensalMax === LIMITES_ASSINANTE_PADRAO.mensalMax
        && l.diarioMax === LIMITES_ASSINANTE_PADRAO.diarioMax, JSON.stringify(l));
}
{
  const l = limitesSeguros({ mensalMax: 999_999 });
  checa('L2', 'mensalMax absurdo é preso no teto absoluto',
        l.mensalMax === MENSAL_MAX_ABSOLUTO, String(l.mensalMax));
}
{
  // O caso silencioso: `doMes >= "3000"` compara número com string. Antes isto
  // passava e o teto sumia sem erro nenhum no log.
  //
  // ⚠️ O VALOR AQUI NÃO PODE SER '3000'. Foi assim que esta asserção nasceu, e
  // o teste de mutação de 18/08 provou que ela era CEGA: apagando a checagem de
  // tipo, `Math.floor('3000')` dá 3000, que é o próprio padrão — a asserção
  // continuava verde protegendo nada. Com '1500' os dois caminhos divergem, e é
  // por isso que ela agora enxerga. Ver a Regra 1 do `CLAUDE.md`.
  const l = limitesSeguros({ mensalMax: '1500' });
  checa('L3', 'mensalMax em string cai no padrão, não vira teto mudo',
        l.mensalMax === LIMITES_ASSINANTE_PADRAO.mensalMax, String(l.mensalMax));
}
{
  const l = limitesSeguros({ mensalMax: 0, diarioMax: -5 });
  checa('L4', 'zero e negativo viram 1, não trancam todo assinante fora',
        l.mensalMax === 1 && l.diarioMax === 1, `${l.mensalMax} ${l.diarioMax}`);
}
{
  const l = limitesSeguros({ mensalMax: null, rajadaMax: NaN });
  checa('L5', 'null e NaN caem no padrão',
        l.mensalMax === LIMITES_ASSINANTE_PADRAO.mensalMax
        && l.rajadaMax === LIMITES_ASSINANTE_PADRAO.rajadaMax, `${l.mensalMax} ${l.rajadaMax}`);
}
{
  const l = limitesSeguros({ mensalMax: 1_500, diarioMax: 120 });
  checa('L6', 'valor válido dentro da faixa é respeitado',
        l.mensalMax === 1_500 && l.diarioMax === 120, `${l.mensalMax} ${l.diarioMax}`);
}
{
  const l = limitesSeguros({ inventado: 42, mensalMax: 100 });
  checa('L7', 'chave desconhecida não entra no objeto',
        l.inventado === undefined && Object.keys(l).length === 4, JSON.stringify(l));
}
{
  const l = limitesSeguros(null);
  checa('L8', 'documento inexistente (null) devolve os padrões',
        l.mensalMax === LIMITES_ASSINANTE_PADRAO.mensalMax, String(l.mensalMax));
}
{
  const l = limitesSeguros({ rajadaMax: 5_000, rajadaJanelaMs: 999_999_999 });
  checa('L9', 'rajada e janela também têm teto',
        l.rajadaMax === RAJADA_MAX_ABSOLUTO && l.rajadaJanelaMs === 3_600_000,
        `${l.rajadaMax} ${l.rajadaJanelaMs}`);
}
{
  // A asserção que prende a REGRA DE NEGÓCIO, não o código: no teto absoluto,
  // somando TODOS os caminhos pagos, o assinante ainda tem de dar lucro.
  //
  // Os 0,60 do TTS estão aqui porque a primeira versão desta conta os esqueceu
  // e deixou o teto colado na linha de prejuízo. Quem criar um caminho pago
  // novo soma ele aqui — senão esta asserção passa a mentir.
  const SCANS_TETO_USD = 2.54;   // 5 comida/dia + 3 corpo/semana, tudo no máximo
  const TTS_TETO_USD   = 0.60;   // 40.000 caracteres/mês
  const RECEITA_USD    = 8.16;   // R$ 42,42 ÷ 5,2005
  const pior = MENSAL_MAX_ABSOLUTO * 0.001525 + SCANS_TETO_USD + TTS_TETO_USD;
  checa('L10', 'no teto absoluto, somando TUDO, o assinante ainda dá lucro',
        pior < RECEITA_USD, `US$ ${pior.toFixed(2)} < US$ ${RECEITA_USD.toFixed(2)}`);
}
{
  checa('L12', 'o padrão é MENOR que o teto absoluto (há folga para ajustar sem deploy)',
        LIMITES_ASSINANTE_PADRAO.mensalMax < MENSAL_MAX_ABSOLUTO,
        `${LIMITES_ASSINANTE_PADRAO.mensalMax} < ${MENSAL_MAX_ABSOLUTO}`);
}
{
  checa('L11', 'DIARIO_MAX_ABSOLUTO existe e é menor que o mês',
        DIARIO_MAX_ABSOLUTO > 0 && DIARIO_MAX_ABSOLUTO < MENSAL_MAX_ABSOLUTO,
        `${DIARIO_MAX_ABSOLUTO} < ${MENSAL_MAX_ABSOLUTO}`);
}

// ── S — janela semanal do scan corporal ────────────────────────────────────
console.log('\n— S: chaveDaSemanaISO —');
{
  // Segunda 17/08/2026 e domingo 23/08/2026 são a MESMA semana ISO. Se a chave
  // divergisse, a cota de 3/semana reiniciaria no meio da semana.
  const seg = chaveDaSemanaISO(new Date('2026-08-17T00:00:00Z'));
  const dom = chaveDaSemanaISO(new Date('2026-08-23T23:59:59Z'));
  checa('S1', 'segunda e domingo da mesma semana dão a mesma chave',
        seg === dom, `${seg} === ${dom}`);
}
{
  const dom = chaveDaSemanaISO(new Date('2026-08-23T23:59:59Z'));
  const seg = chaveDaSemanaISO(new Date('2026-08-24T00:00:00Z'));
  checa('S2', 'a segunda seguinte abre semana NOVA',
        dom !== seg, `${dom} !== ${seg}`);
}
{
  const a = chaveDaSemanaISO(new Date('2026-08-18T10:00:00Z'));
  const b = chaveDaSemanaISO(new Date('2026-08-19T10:00:00Z'));
  checa('S3', 'dias diferentes da mesma semana NÃO reiniciam a cota',
        a === b, `${a} === ${b}`);
}
{
  // Virada de ano: 01/01/2027 é sexta, logo pertence à semana 53 de 2026.
  const k = chaveDaSemanaISO(new Date('2027-01-01T12:00:00Z'));
  checa('S4', 'virada de ano segue a norma ISO (01/01/2027 = 2026-W53)',
        k === '2026-W53', k);
}
{
  const k = chaveDaSemanaISO(new Date('2026-01-05T12:00:00Z'));
  checa('S5', 'formato é yyyy-Www com dois dígitos', /^\d{4}-W\d{2}$/.test(k), k);
}

// ── CANÁRIO ────────────────────────────────────────────────────────────────
// Casos que TÊM de reprovar. Se algum passar, o arquivo está cego.
console.log('\n— CANÁRIO (estes TÊM de reprovar) —');
const canarios = [];
{
  const [db] = dbCom(naoExiste);
  const r = await ehAssinante(db, 'uid', {});
  canarios.push(['C1', 'conta sem nada seria assinante', r === true]);
}
{
  const l = limitesSeguros({ mensalMax: 999_999 });
  canarios.push(['C2', 'teto absurdo teria passado', l.mensalMax === 999_999]);
}
{
  const a = chaveDaSemanaISO(new Date('2026-08-17T00:00:00Z'));
  const b = chaveDaSemanaISO(new Date('2026-08-18T00:00:00Z'));
  canarios.push(['C3', 'a chave mudaria a cada dia', a !== b]);
}

let cego = false;
for (const [id, desc, passou] of canarios) {
  if (passou) { cego = true; console.log(`  ✗✗ ${id} DETECTOR CEGO — ${desc}`); }
  else        { console.log(`  ✓ ${id} detector vivo — ${desc}: reprovou como devia`); }
}

// ── Resultado ──────────────────────────────────────────────────────────────
console.log(`\n═══ ${ok} asserções passaram, ${falhas.length} reprovaram ═══`);
if (falhas.length > 0) {
  console.log('REPROVADAS:');
  for (const f of falhas) console.log(`  · ${f}`);
}
if (cego) {
  console.log('\n✗✗ CANÁRIO PASSOU — este arquivo está CEGO. Resultado inteiro DESCARTADO.');
  process.exit(2);
}
process.exit(falhas.length > 0 ? 1 : 0);
