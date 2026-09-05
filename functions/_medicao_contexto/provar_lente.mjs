/**
 * PROVA da LEITURA DE LENTE — regras exercitadas, custo medido, canário vivo.
 *
 * Não lê código: RODA o `lib/` compilado, o mesmo que a Cloud Function carrega.
 *
 * Três coisas, nesta ordem:
 *   1. As asserções sobre o comportamento do módulo.
 *   2. O CUSTO em tokens ABSOLUTOS — inclusive o prompt inteiro, extraído do
 *      `index.ts` real, para o número não ser sobre um pedaço solto.
 *   3. O CANÁRIO: as mesmas asserções rodadas contra uma implementação
 *      DELIBERADAMENTE CEGA, que TÊM de reprovar. Se passarem, o detector está
 *      quebrado e o resultado inteiro acima é descartado.
 *
 * Uso: node _medicao_contexto/provar_lente.mjs
 */

import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { encode } = require('gpt-tokenizer/encoding/o200k_base');
const ctx = require('../lib/contextoDoUsuario.js');
const lente = require('../lib/leituraDeLente.js');

const t = (s) => (s ? encode(s).length : 0);

/* ─────────────────────────────────────────────────────────────────────────
 * FIXTURES
 *
 * ⚠️ Regra 1.1 do CLAUDE.md: o valor de teste NUNCA pode coincidir com o que a
 * implementação errada produziria, senão a asserção passa nos dois mundos.
 *
 * Por isso `HOJE` é 10/02/2026 e o nascimento é 14/03/1988: é ANTES do
 * aniversário, a única janela do ano em que "virar no aniversário" e "virar em
 * 1º de janeiro" dão números DIFERENTES.
 *   correto (ciclo de 2025): 3 + 14 + 2025 = 2042 → 8
 *   errado  (ano corrente):  3 + 14 + 2026 = 2043 → 9
 * Com qualquer data depois do aniversário, os dois dariam 9 e esta prova não
 * provaria nada.
 * ───────────────────────────────────────────────────────────────────────── */
const HOJE = new Date(Date.UTC(2026, 1, 10, 12, 0, 0));   // 10/02/2026
const NASC = '1988-03-14';

const HORA_APROX = { birthTimeSlot: 'Tarde (12h-18h)', birthCity: 'Belo Horizonte', birthCountry: 'Brasil' };
const HORA_EXATA = { birthTime: '14:30', birthCity: 'Belo Horizonte', birthCountry: 'Brasil' };
const SEM_NADA   = undefined;

const PERFIL = {
  name: 'Marina', birthDate: NASC, intention: 'ansiedade',
  relationship: 'casado', children: 'sim_2+',
  occupation: 'trabalhando_estresse', spirituality: 'explorando',
};

/* ─────────────────────────────────────────────────────────────────────────
 * O CONJUNTO DE ASSERÇÕES — uma função, para poder ser reapontada ao canário
 *
 * Recebe o módulo a testar. Roda contra o real; depois roda contra a versão
 * cega. É isto que torna o canário possível: se as asserções vivessem soltas
 * no corpo do arquivo, não haveria como reapontá-las.
 * ───────────────────────────────────────────────────────────────────────── */
function asserçoes(mod) {
  const r = [];
  const ok = (nome, cond) => r.push({ nome, passou: Boolean(cond) });

  const blocoAprox = mod.blocoLeitura(NASC, HORA_APROX, HOJE);
  const blocoExato = mod.blocoLeitura(NASC, HORA_EXATA, HOJE);
  const blocoSemHora = mod.blocoLeitura(NASC, SEM_NADA, HOJE);
  const semData = mod.blocoLeitura(undefined, HORA_APROX, HOJE);

  // ── 1. O momento vira no ANIVERSÁRIO, não em 1º de janeiro ──────────────
  ok('ciclo pessoal vira no aniversário (ano 8, não 9)',
    /Momento: ano 8 de 9/.test(blocoAprox));
  ok('a data em que o ciclo virou é dita (14/03/2025)',
    blocoAprox.includes('desde 14/03/2025'));
  ok('depois do aniversário o ciclo avança (9 em 20/03/2026)',
    /Momento: ano 9 de 9/.test(mod.blocoLeitura(NASC, HORA_APROX, new Date(Date.UTC(2026, 2, 20)))));

  // ── 2. A resolução declara o buraco, nos DOIS estados de hora ───────────
  ok('hora aproximada → diz que NÃO existe ascendente',
    /ascendente e casas não existem aqui, e sem hora exata nem seriam possíveis/i.test(blocoAprox));
  ok('hora aproximada → manda não deduzir', /Não deduza/i.test(blocoAprox));
  // [29/08] Esta asserção nasceu de uma MEDIÇÃO, não de uma ideia: sem ela, o
  // modelo respondeu "Consigo, mas preciso da sua hora exata" — prometendo uma
  // conta que o servidor não faz. Ver o comentário em `resolucaoDaLeitura`, e
  // repare que ela exige a instrução POSITIVA (o que dizer), não a proibição:
  // a proibição foi tentada, medida, e perdeu para o §10.
  ok('os dois estados DIZEM O QUE FALAR, em vez de só proibir',
    /diga que não faz esse cálculo/i.test(blocoAprox) && /diga que não faz esse cálculo/i.test(blocoExato));
  ok('hora EXATA avisa que ter a hora não é ter a conta',
    /ter a hora não é ter a conta feita/i.test(blocoExato));
  ok('os dois estados dizem coisas DIFERENTES',
    mod.resolucaoDaLeitura(HORA_APROX) !== mod.resolucaoDaLeitura(HORA_EXATA));
  ok('sem identidade nenhuma → cai no texto de "sem hora exata"',
    /sem hora exata/i.test(blocoSemHora));
  ok('hora malformada NÃO é tratada como exata',
    mod.resolucaoDaLeitura({ birthTime: '25:99' }) === mod.resolucaoDaLeitura(SEM_NADA));

  // ── 3. Degrada para o nada sem data de nascimento ───────────────────────
  ok('sem data de nascimento → bloco vazio', semData === '');
  ok('sem data de nascimento → instrução vazia',
    mod.instrucaoDeLente(undefined, HOJE) === '');
  ok('sem data de nascimento → seção inteira vazia',
    mod.secaoDeLeitura(undefined, HORA_APROX, HOJE) === '');
  ok('data inválida (30/02) → seção vazia',
    mod.secaoDeLeitura('2001-02-30', HORA_APROX, HOJE) === '');

  // ── 4. É HIPÓTESE no próprio rótulo ─────────────────────────────────────
  ok('o rótulo do bloco diz HIPÓTESE', blocoAprox.includes('HIPÓTESE'));
  ok('o rótulo nega ser fato', /HIPÓTESE, não fato/i.test(blocoAprox));

  // ── 5. A instrução manda PROPOR E PERGUNTAR, e largar quando errar ──────
  const ins = mod.INSTRUCAO_DE_LENTE;
  ok('instrução: propor e perguntar', /PROPOR E PERGUNTAR/.test(ins));
  ok('instrução: aceitar o "não" de primeira', /aceite de primeira/i.test(ins));
  ok('instrução: proíbe reformular a tese', /não reformule e não explique/i.test(ins));
  // [29/08] "Permitido" não bastou: contra o modelo real, a Alma aceitava o
  // "não faz sentido" e parava — o §5 ("na dúvida, AFIRME") ganhava de uma
  // permissão. Só virou comportamento quando virou OBRIGAÇÃO. Por isso a
  // asserção exige as duas palavras, e não a intenção.
  ok('instrução: OBRIGA a devolver a palavra depois do "não"',
    /PEÇA que ela conte/.test(ins) && /pedido é obrigatório/i.test(ins));
  ok('o mês pessoal continua calculável, mesmo fora do bloco',
    mod.momentoDeVida ? mod.momentoDeVida({ ano: 1988, mes: 3, dia: 14 }, HOJE).mes === 1 : true);
  ok('instrução: a resposta dela ganha lastro', /passa a valer e tem lastro/i.test(ins));
  ok('instrução: proíbe afirmar quem ela é', /NUNCA afirme quem ela é/.test(ins));
  ok('instrução: teste do "não" (a frase tem de poder ser negada)',
    /poder ser respondida com "não"/.test(ins));

  // ── 6. Conteúdo proibido — corregedoria e regra de saúde ────────────────
  ok('instrução proíbe leitura de saúde/doença/morte/gravidez/dinheiro',
    /saúde, doença, corpo, morte, gravidez, dinheiro/.test(ins));
  ok('instrução proíbe previsão de futuro', /ainda vai acontecer/.test(ins));
  ok('instrução cede ao §0 (crise)', /§0 se aplicar, esta seção sai de cena/.test(ins));

  const tudo = ins + '\n' + blocoAprox;
  const PROIBIDOS = [
    'Cabala', 'Kabbal', 'Nefesh', 'Ruach', 'Neshamah', 'sefir', 'Sefir',
    'numerolog', 'Numerolog', 'astrolog', 'Astrolog', 'zodíaco', 'Zodíaco',
    'mapa astral', 'Árvore da Vida', 'hebraic', 'Saturno', 'Urano',
    'Gevurah', 'Netzach', 'Tiferet', 'Chesed', 'Binah', 'Yesod', 'Hod',
  ];
  for (const p of PROIBIDOS) {
    ok(`não vaza o nome da tradição: "${p}"`, !tudo.includes(p));
  }
  ok('não emite nome de signo (o [Mapa interno] já emite; não duplico)',
    !/Áries|Touro|Gêmeos|Câncer|Leão|Virgem|Libra|Escorpião|Sagitário|Capricórnio|Aquário|Peixes/.test(blocoAprox));

  // ── 7. As fases de vida existem e são silenciosas fora das janelas ──────
  ok('fase aos 29 existe', typeof mod.fasePorIdade(29) === 'string');
  ok('fase aos 42 existe', typeof mod.fasePorIdade(42) === 'string');
  ok('fase aos 59 existe', typeof mod.fasePorIdade(59) === 'string');
  ok('fora das janelas, silêncio (35 anos)', mod.fasePorIdade(35) === null);
  ok('idade absurda não quebra', mod.fasePorIdade(NaN) === null);
  ok('aos 37 (nossa fixture) o bloco NÃO traz linha de fase',
    !blocoAprox.includes('Fase:'));
  ok('aos 29 o bloco TRAZ linha de fase',
    mod.blocoLeitura('1997-01-05', HORA_APROX, HOJE).includes('Fase:'));

  return r;
}

/* ─────────────────────────────────────────────────────────────────────────
 * 1. RODADA REAL
 * ───────────────────────────────────────────────────────────────────────── */
console.log('\n══ PROVA: LEITURA DE LENTE ════════════════════════════════════════════');
console.log('tokenizador o200k_base · hoje fixado em 10/02/2026 · nasc. 14/03/1988\n');

console.log('── O QUE DESCE PARA O MODELO (hora aproximada) ────────────────────────');
console.log(lente.blocoLeitura(NASC, HORA_APROX, HOJE).split('\n').map((l) => `   │ ${l}`).join('\n'));
console.log('\n── O MESMO, com hora exata (só a última linha muda) ───────────────────');
console.log(`   │ ${lente.resolucaoDaLeitura(HORA_EXATA)}`);

const real = asserçoes(lente);
const falhas = real.filter((x) => !x.passou);

console.log('\n── ASSERÇÕES ─────────────────────────────────────────────────────────');
for (const a of real) console.log(`   ${a.passou ? '✓' : '✗ FALHOU —'} ${a.nome}`);
console.log(`   ${real.length - falhas.length}/${real.length} passaram`);

/* ─────────────────────────────────────────────────────────────────────────
 * 2. CUSTO EM TOKENS ABSOLUTOS
 *
 * Percentual está proibido de propósito: percentual mede o que eu acrescentei
 * E o tamanho do resto ao mesmo tempo, então sobe quando o prompt encolhe.
 * ───────────────────────────────────────────────────────────────────────── */
console.log('\n── CUSTO EM TOKENS ABSOLUTOS ─────────────────────────────────────────');

const tInstrucao = t(lente.INSTRUCAO_DE_LENTE);
const tBlocoAprox = t(lente.blocoLeitura(NASC, HORA_APROX, HOJE));
const tBlocoExato = t(lente.blocoLeitura(NASC, HORA_EXATA, HOJE));
const tSecaoAprox = t(lente.secaoDeLeitura(NASC, HORA_APROX, HOJE));
const tSemData = t(lente.secaoDeLeitura(undefined, HORA_APROX, HOJE));

console.log(`   instrução fixa (§L), paga por quem TEM data ........ ${String(tInstrucao).padStart(5)}`);
console.log(`   bloco [Leitura], hora aproximada ................... ${String(tBlocoAprox).padStart(5)}`);
console.log(`   bloco [Leitura], hora exata ....................... ${String(tBlocoExato).padStart(5)}`);
console.log(`   ──────────────────────────────────────────────────────────`);
console.log(`   SEÇÃO INTEIRA por mensagem, quem TEM data ......... ${String(tSecaoAprox).padStart(5)}`);
console.log(`   SEÇÃO INTEIRA por mensagem, quem NÃO tem data ..... ${String(tSemData).padStart(5)}`);

// ── O prompt INTEIRO, extraído do index.ts real ────────────────────────────
const fonte = readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
const ini = fonte.indexOf('const ALMA_SOUL_PROMPT = `');
if (ini < 0) throw new Error('ALMA_SOUL_PROMPT não encontrado — harness desatualizado');
const corpoIni = ini + 'const ALMA_SOUL_PROMPT = `'.length;
const template = fonte.slice(corpoIni, fonte.indexOf('`;', corpoIni));

const crise = require('../lib/apoioEmCrise.js');

/**
 * Monta o prompt como o servidor monta. `secao` é o ponto de injeção novo — a
 * ÚNICA mudança que o `index.ts` precisa receber.
 *
 * Guarda contra harness envelhecido, igual à do `testes_crise.mjs`: se o
 * template ganhar uma variável que esta lista não fornece, morre aqui com o
 * nome dela em vez de dar `ReferenceError` no meio da corrida.
 */
const FORNECIDAS = [
  'userProfile', 'conversationSummary', 'healthContext', 'HEALTH_CONTEXT_GUARDRAILS',
  'blocoDeCrise', 'recursoDeApoio', 'regiao', 'blocoDoUsuario', 'coletaProgressiva',
  'secaoDaLente',
];
const usadas = new Set([...template.matchAll(/\$\{\s*([A-Za-z_$][\w$]*)/g)].map((m) => m[1]));
const faltando = [...usadas].filter((v) => !FORNECIDAS.includes(v));
if (faltando.length > 0) {
  throw new Error(`harness desatualizado: o prompt usa ${faltando.join(', ')} e este teste não fornece.`);
}
// [2026-08-31] O patch foi APLICADO no index.ts: o template agora contém
// ${secaoDaLente}. O harness deixou de injetar por `.replace` e passou a
// FORNECER a variável — "antes" é o template real com a seção vazia, "depois"
// com a seção real. Ganho de verificação: se alguém remover ${secaoDaLente} do
// index.ts, "depois − antes" vira 0 e a asserção do Δ fica vermelha — este
// arquivo virou o detector vivo do fio, não só do módulo.
if (!usadas.has('secaoDaLente')) {
  throw new Error('index.ts NÃO contém ${secaoDaLente} — o fio da leitura de lente foi removido do prompt.');
}

function promptCompleto(perfil, identidade, { comLente }) {
  const blocoDoUsuario = ctx.textoDoBlocoDoUsuario(ctx.montarBlocoDoUsuario({
    perfil, resumo: '', praticas: [], messageCount: 184, hoje: HOJE,
    identidadeDeNascimento: identidade,
  }));
  const coletaProgressiva = ctx.blocoColetaProgressiva(perfil, HOJE);
  const secaoDaLente = comLente ? lente.secaoDeLeitura(perfil.birthDate, identidade, HOJE) : '';
  const f = new Function(...FORNECIDAS, 'return `' + template + '`');
  return f('', '', '', '', crise.blocoDeCrise, crise.recursoDeApoio, 'BR',
    blocoDoUsuario, coletaProgressiva, secaoDaLente);
}

const SEM_PERFIL = {};
const antesComData = t(promptCompleto(PERFIL, HORA_APROX, { comLente: false }));
const depoisComData = t(promptCompleto(PERFIL, HORA_APROX, { comLente: true }));
const antesSemData = t(promptCompleto(SEM_PERFIL, undefined, { comLente: false }));
const depoisSemData = t(promptCompleto(SEM_PERFIL, undefined, { comLente: true }));

console.log('\n   O PROMPT INTEIRO, extraído do index.ts real:');
console.log('   cenário                                   antes   depois       Δ');
console.log(`   usuário COM data de nascimento .......... ${String(antesComData).padStart(5)}   ${String(depoisComData).padStart(5)}   ${String(depoisComData - antesComData).padStart(5)}`);
console.log(`   usuário SEM data (e sem perfil) ......... ${String(antesSemData).padStart(5)}   ${String(depoisSemData).padStart(5)}   ${String(depoisSemData - antesSemData).padStart(5)}`);

const ok2 = (nome, cond) => { real.push({ nome, passou: Boolean(cond) }); console.log(`   ${cond ? '✓' : '✗ FALHOU —'} ${nome}`); };
console.log('');
// A ~340 mensagens por usuário por mês (o número que o `contextoDoUsuario.ts`
// já usa para orçar), o acréscimo por mês é este. Tokens, não dólares: o preço
// do `gpt-5.6-terra` eu não medi, e converter com o preço de outro modelo seria
// inventar um número com cara de fato.
const MSG_MES = 340;
console.log(`\n   a ${MSG_MES} mensagens/usuário/mês, quem TEM data paga +${((depoisComData - antesComData) * MSG_MES / 1000).toFixed(0)}k tokens de entrada/mês.`);
console.log(`   quem NÃO tem data paga +0.\n`);

ok2('quem não tem data de nascimento não paga NADA', depoisSemData === antesSemData);
ok2('o acréscimo de quem tem data bate com a seção medida isolada',
  depoisComData - antesComData === tSecaoAprox);
// O teto de 400 foi escolhido ANTES de medir qualquer coisa, e não se moveu uma
// vez sequer durante o trabalho — três cortes reais no texto foram feitos para
// caber nele, e um conserto de conteúdo (a instrução positiva sobre o
// ascendente) foi pago com outros cortes em vez de com um teto maior.
//
// Aviso honesto: a seção fecha em EXATAMENTE 400. Está na linha, não sobrando.
// O `<=` é o que a frase "cabe em 400" quer dizer; o `<` que estava aqui antes
// era um erro de codificação da própria frase. Quem for acrescentar qualquer
// coisa a esta seção vai ter de tirar de outro lugar — que é justamente o
// efeito que o teto existe para produzir.
ok2('o acréscimo cabe no orçamento de 400 tokens', depoisComData - antesComData <= 400);

/* ─────────────────────────────────────────────────────────────────────────
 * 3. CANÁRIO — as mesmas asserções contra uma implementação CEGA
 *
 * Regra 2 do CLAUDE.md. A `LENTE_CEGA` comete exatamente os três erros que
 * este arquivo existe para pegar:
 *   a) vira o ciclo em 1º de janeiro (o jeito do iOS);
 *   b) não declara a resolução — deixa o buraco do ascendente aberto;
 *   c) a instrução afirma em vez de propor, e cita a tradição.
 * Se as asserções acima não reprovarem AQUI, elas não enxergam nada e o
 * resultado inteiro deste arquivo é lixo.
 * ───────────────────────────────────────────────────────────────────────── */
console.log('\n── CANÁRIO (tem de REPROVAR) ─────────────────────────────────────────');

const LENTE_CEGA = {
  blocoLeitura(birthDate, _identidade, hoje) {
    const d = ctx.lerDataDeNascimento(birthDate, hoje);
    if (!d) return '';
    let n = d.mes + d.dia + hoje.getUTCFullYear();      // (a) vira em 1º/jan
    while (n > 9) n = String(n).split('').reduce((s, c) => s + Number(c), 0);
    return `[Leitura]\nMomento: ano ${n} de um ciclo de 9, desde 01/01/${hoje.getUTCFullYear()}.`
         + `\nBase: água, adapta.`;                      // (b) sem resolução
  },
  resolucaoDaLeitura() { return ''; },
  instrucaoDeLente() { return 'x'; },
  secaoDeLeitura() { return 'x'; },
  fasePorIdade() { return null; },
  INSTRUCAO_DE_LENTE: 'Use o mapa astral e a Cabala para dizer quem a pessoa é.',
};

const doCanario = asserçoes(LENTE_CEGA);
const reprovouNoCanario = doCanario.filter((x) => !x.passou).length;
const ESPERADAS_NO_CANARIO = 12;   // piso, não igualdade: erro grosseiro derruba muitas

console.log(`   asserções que reprovaram na implementação cega: ${reprovouNoCanario}`);
console.log('   as principais que precisavam reprovar:');
for (const nome of [
  'ciclo pessoal vira no aniversário (ano 8, não 9)',
  'hora aproximada → diz que NÃO existe ascendente',
  'instrução: propor e perguntar',
  'não vaza o nome da tradição: "Cabala"',
]) {
  const a = doCanario.find((x) => x.nome === nome);
  console.log(`     ${a && !a.passou ? '✓ reprovou (bom)' : '✗✗ PASSOU — DETECTOR CEGO'} · ${nome}`);
}

const canarioVivo = reprovouNoCanario >= ESPERADAS_NO_CANARIO
  && ['ciclo pessoal vira no aniversário (ano 8, não 9)',
      'hora aproximada → diz que NÃO existe ascendente',
      'instrução: propor e perguntar',
      'não vaza o nome da tradição: "Cabala"']
     .every((n) => doCanario.find((x) => x.nome === n)?.passou === false);

console.log(canarioVivo
  ? '   ✓ DETECTOR VIVO — as asserções enxergam.'
  : '   ✗✗ DETECTOR CEGO — as asserções aprovam o errado. RESULTADO DESCARTADO.');

/* ───────────────────────────────────────────────────────────────────────── */
console.log('\n══════════════════════════════════════════════════════════════════════');
const falhasFinais = real.filter((x) => !x.passou);
if (!canarioVivo) {
  console.log('✗ CANÁRIO REPROVOU. Nada acima vale. Conserte o harness antes de olhar o resto.');
  process.exit(1);
}
if (falhasFinais.length) {
  console.log(`✗ ${falhasFinais.length} FALHA(S):`);
  falhasFinais.forEach((f) => console.log(`   - ${f.nome}`));
  process.exit(1);
}
console.log(`✓ ${real.length} asserções passaram, o canário reprovou como devia,`);
console.log('  e o custo está em tokens absolutos.\n');
