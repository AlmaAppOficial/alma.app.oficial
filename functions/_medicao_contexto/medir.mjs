/**
 * Mede quanto do que desce para a OpenAI, a cada mensagem do chat, fala da
 * pessoa que está falando.
 *
 * ── COMO ISTO EVITA MEDIR O NADA ───────────────────────────────────────────
 * Três defesas, porque o `CLAUDE.md` deste projeto tem um histórico de
 * harnesses que aprovavam sem olhar:
 *
 *  1. NADA É TRANSCRITO À MÃO. Os dois prompts — o "antes" e o "depois" — são
 *     extraídos mecanicamente do `index.ts` (de `git show HEAD` e da árvore,
 *     respectivamente) e avaliados. Se eu tivesse copiado o prompt para cá, a
 *     medição seria da minha cópia.
 *  2. A SEGMENTAÇÃO SE AUTOVERIFICA. O prompt é remontado com marcas no lugar
 *     dos blocos do usuário, fatiado nelas, e o resultado da junta dos pedaços
 *     é comparado byte a byte com o prompt real. Diferiu, aborta.
 *  3. CANÁRIO. O usuário novo TEM de dar 0 token de contexto. Se der qualquer
 *     coisa acima de zero, o classificador está contando estático como pessoal
 *     e o resto do relatório não vale. E o controle positivo: uma persona com
 *     dado TEM de dar acima de zero — senão o classificador está cego para o
 *     outro lado.
 *
 * Uso:
 *   node medir.mjs            → tabela + gravação dos payloads crus
 *
 * A mutação da reconciliação roda sempre — não é opcional.
 */

import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync } from 'node:fs';
import { fonteDeHead, fonteDaArvore, montarSystemPrompt, montarUserProfileAntes, commitDaLinhaDeBase } from './extrairAntes.mjs';
import { PERSONAS, HOJE } from './fixtures.mjs';

const require = createRequire(import.meta.url);
const { encode } = require('gpt-tokenizer/encoding/o200k_base');   // gpt-4o-mini
const ctx = require('../lib/contextoDoUsuario.js');
const crise = require('../lib/apoioEmCrise.js');

const AQUI = new URL('.', import.meta.url).pathname;
const SAIDA = `${AQUI}payloads`;
mkdirSync(SAIDA, { recursive: true });


/** Sobrecarga do protocolo de chat da OpenAI: 3 tokens por mensagem + 3 de priming. */
const POR_MENSAGEM = 3;
const PRIMING = 3;

const t = (s) => (s ? encode(s).length : 0);

/* ─────────────────────────────────────────────────────────────────────────────
 * Segmentação com marcas + autoverificação
 * ────────────────────────────────────────────────────────────────────────── */
function segmentar(src, vars, chavesDoUsuario) {
  const ativas = chavesDoUsuario.filter(
    (k) => typeof vars[k] === 'string' && vars[k].length > 0,
  );
  const marcas = ativas.map((_, i) => `M${i}`);

  const comMarcas = { ...vars };
  ativas.forEach((k, i) => { comMarcas[k] = marcas[i]; });
  let resto = montarSystemPrompt(src, comMarcas);

  const segs = [];
  ativas.forEach((k, i) => {
    const p = resto.indexOf(marcas[i]);
    if (p < 0) throw new Error(`marca de "${k}" sumiu do prompt — segmentação inválida`);
    segs.push({ origem: 'estatico', chave: 'prompt', texto: resto.slice(0, p) });
    segs.push({ origem: 'usuario', chave: k, texto: vars[k] });
    resto = resto.slice(p + marcas[i].length);
  });
  segs.push({ origem: 'estatico', chave: 'prompt', texto: resto });

  const real = montarSystemPrompt(src, vars);
  const juntado = segs.map((s) => s.texto).join('');
  if (juntado !== real) {
    throw new Error('AUTOVERIFICAÇÃO FALHOU: os segmentos não remontam o prompt real');
  }
  return { segs, systemPrompt: real };
}

/* ─────────────────────────────────────────────────────────────────────────────
 * ANTES — como HEAD monta
 * ────────────────────────────────────────────────────────────────────────── */
const SRC_ANTES = fonteDeHead();

function montarAntes(p) {
  const userProfile = montarUserProfileAntes(SRC_ANTES, p.mapa);
  const conversationSummary = p.resumo ?? '';
  const historico = p.conversa.slice(-6);          // limit(6), literal de HEAD

  const vars = {
    userProfile,
    conversationSummary,
    healthContext: p.healthContext ?? '',
    regiao: p.regiao,
    blocoDeCrise: crise.blocoDeCrise,
    recursoDeApoio: crise.recursoDeApoio,
  };
  const { segs, systemPrompt } = segmentar(
    SRC_ANTES, vars, ['userProfile', 'conversationSummary', 'healthContext'],
  );
  return { segs, systemPrompt, historico, maxTokens: 400 };
}

/* ─────────────────────────────────────────────────────────────────────────────
 * DEPOIS — como a árvore monta, com o módulo REAL já compilado
 * ────────────────────────────────────────────────────────────────────────── */
const SRC_DEPOIS = fonteDaArvore();

function montarDepois(p, { semReconciliacao = false } = {}) {
  // A MUTAÇÃO: ignora a subcoleção, que é exatamente o que o servidor fazia
  // antes. Se o resultado não piorar aqui, a reconciliação não fazia nada.
  const rec = semReconciliacao
    ? ctx.reconciliarPerfil(p.mapa, undefined)
    : ctx.reconciliarPerfil(p.mapa, p.sub);

  const blocoDoUsuario = ctx.textoDoBlocoDoUsuario(ctx.montarBlocoDoUsuario({
    perfil: rec.perfil,
    resumo: p.resumo ?? '',
    praticas: p.praticas ?? [],
    messageCount: p.messageCount ?? 0,
    hoje: HOJE,
  }));
  const coletaProgressiva = ctx.blocoColetaProgressiva(rec.perfil, HOJE);
  const historico = ctx.orcarHistorico(p.conversa.slice(-ctx.HISTORICO_MAX_MENSAGENS));

  const vars = {
    coletaProgressiva,
    blocoDoUsuario,
    healthContext: p.healthContext ?? '',
    regiao: p.regiao,
    blocoDeCrise: crise.blocoDeCrise,
    recursoDeApoio: crise.recursoDeApoio,
  };
  const { segs, systemPrompt } = segmentar(
    SRC_DEPOIS, vars, ['blocoDoUsuario', 'healthContext'],
  );

  // O cabeçalho do bloco ("Isto não é ficha…") é INSTRUÇÃO minha, fixa, igual
  // para todo mundo. Contá-la como "fala do usuário" seria inflar o número com
  // texto que eu mesmo escrevi. Quebra em dois: cabeçalho estático, dados do
  // usuário. Sem isto o ganho medido vinha ~50 tokens maior de graça.
  const partidos = [];
  for (const s of segs) {
    if (s.chave === 'blocoDoUsuario' && s.texto.startsWith(ctx.CABECALHO_DO_BLOCO)) {
      partidos.push({ origem: 'estatico', chave: 'prompt', texto: ctx.CABECALHO_DO_BLOCO });
      partidos.push({ origem: 'usuario', chave: 'blocoDoUsuario', texto: s.texto.slice(ctx.CABECALHO_DO_BLOCO.length) });
    } else partidos.push(s);
  }
  if (partidos.map((s) => s.texto).join('') !== segs.map((s) => s.texto).join('')) {
    throw new Error('quebra do cabeçalho alterou o prompt');
  }

  return { segs: partidos, systemPrompt, historico, maxTokens: 600, backfill: rec.aBackfillar };
}

/* ─────────────────────────────────────────────────────────────────────────────
 * Contagem
 * ────────────────────────────────────────────────────────────────────────── */
function contar(montado, mensagemAtual) {
  const estatico = montado.segs.filter((s) => s.origem === 'estatico')
    .reduce((n, s) => n + t(s.texto), 0);
  const contexto = montado.segs.filter((s) => s.origem === 'usuario')
    .reduce((n, s) => n + t(s.texto), 0);
  const historico = montado.historico.reduce((n, m) => n + t(m.content), 0);
  const atual = t(mensagemAtual);
  const protocolo = POR_MENSAGEM * (1 + montado.historico.length + 1) + PRIMING;

  const total = estatico + contexto + historico + atual + protocolo;

  // Conferência independente: contar o payload inteiro de uma vez só. Se a soma
  // dos segmentos divergir da contagem monolítica em mais de 1%, a soma está
  // escondendo alguma coisa (fronteira de token, segmento perdido).
  const monolitico = t([
    montado.systemPrompt,
    ...montado.historico.map((m) => m.content),
    mensagemAtual,
  ].join('\n')) + protocolo;

  return {
    estatico, contexto, historico, atual, protocolo, total, monolitico,
    porPessoa: contexto + historico,
    pctComHistorico: (contexto + historico) / total * 100,
    pctSoContexto: contexto / total * 100,
    detalhe: montado.segs.filter((s) => s.origem === 'usuario')
      .map((s) => `${s.chave}=${t(s.texto)}`).join(' '),
  };
}

function payloadCru(montado, mensagemAtual) {
  return JSON.stringify({
    model: 'gpt-4o-mini',
    max_tokens: montado.maxTokens,
    temperature: 0.85,
    messages: [
      { role: 'system', content: montado.systemPrompt },
      ...montado.historico,
      { role: 'user', content: mensagemAtual },
    ],
  }, null, 2);
}

/* ─────────────────────────────────────────────────────────────────────────────
 * Execução
 * ────────────────────────────────────────────────────────────────────────── */
const linhas = [];
let falhas = 0;
const reprovar = (m) => { falhas++; console.log(`   ✗✗ ${m}`); };

console.log('\n══ MEDIÇÃO DO CANO DE CONTEXTO ═══════════════════════════════════════\n');
console.log(`tokenizador: o200k_base (gpt-4o-mini) · hoje fixado em ${HOJE.toISOString().slice(0, 10)}`);
console.log(`antes: ${commitDaLinhaDeBase().slice(0,7)} (pai do commit que criou contextoDoUsuario.ts) · depois: árvore\n`);

for (const p of PERSONAS) {
  const a = montarAntes(p);
  const d = montarDepois(p);
  const ca = contar(a, p.mensagem);
  const cd = contar(d, p.mensagem);

  writeFileSync(`${SAIDA}/${p.id}.antes.json`, payloadCru(a, p.mensagem));
  writeFileSync(`${SAIDA}/${p.id}.depois.json`, payloadCru(d, p.mensagem));

  console.log(`── ${p.titulo}`);
  console.log(`   ${p.nota}`);
  console.log(`   ANTES : total ${ca.total} · contexto ${ca.contexto} (${ca.pctSoContexto.toFixed(1)}%) + histórico ${ca.historico} = ${ca.porPessoa} (${ca.pctComHistorico.toFixed(1)}%)  [${ca.detalhe || 'nada'}]`);
  console.log(`   DEPOIS: total ${cd.total} · contexto ${cd.contexto} (${cd.pctSoContexto.toFixed(1)}%) + histórico ${cd.historico} = ${cd.porPessoa} (${cd.pctComHistorico.toFixed(1)}%)  [${cd.detalhe || 'nada'}]`);
  console.log(`   estático: ${ca.estatico} → ${cd.estatico}   backfill: ${Object.keys(d.backfill).join(',') || '—'}`);

  for (const [nome, c] of [['antes', ca], ['depois', cd]]) {
    const desvio = Math.abs(c.total - c.monolitico) / c.total;
    if (desvio > 0.01) {
      reprovar(`${p.id}/${nome}: soma dos segmentos (${c.total}) diverge do payload inteiro (${c.monolitico}) em ${(desvio * 100).toFixed(1)}%`);
    }
  }

  linhas.push({ persona: p.id, titulo: p.titulo, antes: ca, depois: cd });
  console.log('');
}

/* ── Canário: o detector está vivo? ─────────────────────────────────────────
 * O usuário novo não tem NADA no banco. Se o classificador acusar contexto
 * pessoal nele, ele está contando instrução estática como se fosse a pessoa —
 * e todo o resto da tabela é ficção. Do outro lado, uma persona com dado TEM
 * de acusar: um classificador que só sabe dizer "zero" também está cego.
 */
console.log('── CANÁRIO ───────────────────────────────────────────────────────────');
const novo = linhas.find((l) => l.persona === 'novo');
const cheio = linhas.find((l) => l.persona === 'web+android');

if (novo.antes.porPessoa !== 0) reprovar(`canário: usuário novo ANTES deu ${novo.antes.porPessoa} tokens de contexto; devia dar 0`);
else console.log('   ✓ usuário novo (antes) = 0 tokens de contexto — detector não inventa');

if (novo.depois.porPessoa !== 0) reprovar(`canário: usuário novo DEPOIS deu ${novo.depois.porPessoa}; devia dar 0 (não há o que saber)`);
else console.log('   ✓ usuário novo (depois) = 0 tokens de contexto — continua honesto');

if (cheio.antes.porPessoa <= 0) reprovar('controle positivo: persona com dado deu 0 no antes — detector cego');
else console.log(`   ✓ controle positivo: persona cheia acusa ${cheio.antes.porPessoa} tokens já no antes`);

// O "0,0% para usuário novo" que NÃO precisava ser zero: primeira mensagem, mas
// a data de nascimento já estava no banco desde o onboarding do Android.
const novoAndroid = linhas.find((l) => l.persona === 'novo-android');
if (novoAndroid.antes.porPessoa !== 0) reprovar('novo-android ANTES devia ser 0 (o servidor não lia a subcoleção)');
else if (novoAndroid.depois.porPessoa <= 0) reprovar('novo-android DEPOIS continuou 0 — a reconciliação não pegou na primeira mensagem');
else console.log(`   ✓ novo-android: 0 → ${novoAndroid.depois.porPessoa} tokens na PRIMEIRA mensagem`);

/* ── Mutação: desligar a reconciliação ──────────────────────────────────────
 * Apaga a leitura da subcoleção e confere que o número CAI. Se não cair, a
 * reconciliação não é o que está fazendo o trabalho e o relatório está
 * creditando a peça errada.
 */
{
  console.log('\n── MUTAÇÃO: reconciliação desligada (lê só o mapa, como HEAD) ─────────');
  for (const id of ['android', 'web+android']) {
    const p = PERSONAS.find((x) => x.id === id);
    const bom = contar(montarDepois(p), p.mensagem);
    const mutante = contar(montarDepois(p, { semReconciliacao: true }), p.mensagem);
    const caiu = mutante.porPessoa < bom.porPessoa;
    console.log(`   ${id}: com reconciliação ${bom.porPessoa} → sem ${mutante.porPessoa}  ${caiu ? '✓ vermelho como devia' : '✗✗ NÃO MUDOU'}`);
    if (!caiu) reprovar(`mutação em ${id} não mudou nada — a reconciliação não está sendo exercitada`);
  }
}

console.log('\n══ RESUMO ════════════════════════════════════════════════════════════');
console.log('                     total          contexto (sem hist.)      contexto + histórico');
console.log('persona            antes→depois     antes → depois       %      antes → depois       %');
for (const l of linhas) {
  console.log(
    `${l.persona.padEnd(18)} ${String(l.antes.total).padStart(4)}→${String(l.depois.total).padStart(4)}   ` +
    `${String(l.antes.contexto).padStart(4)} → ${String(l.depois.contexto).padStart(4)}  ` +
    `${l.antes.pctSoContexto.toFixed(1).padStart(4)}%→${l.depois.pctSoContexto.toFixed(1).padStart(5)}%   ` +
    `${String(l.antes.porPessoa).padStart(4)} → ${String(l.depois.porPessoa).padStart(4)}  ` +
    `${l.antes.pctComHistorico.toFixed(1).padStart(4)}%→${l.depois.pctComHistorico.toFixed(1).padStart(5)}%`,
  );
}

console.log(`\npayloads crus em: ${SAIDA}`);
console.log(falhas === 0
  ? '\n✓ nenhuma falha. Contagem autoverificada, canário vivo, mutação vermelha.\n'
  : `\n✗✗ ${falhas} FALHA(S) — o resultado acima NÃO vale.\n`);

process.exit(falhas === 0 ? 0 : 1);
