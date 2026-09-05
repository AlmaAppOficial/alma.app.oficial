/**
 * ─────────────────────────────────────────────────────────────────────────────
 * LEITURA DE LENTE — a análise inicial que a Alma PROPÕE, nunca afirma.
 *
 * ── O QUE ISTO É, E O QUE NÃO É ─────────────────────────────────────────────
 * O Assis pediu que a Alma tivesse, já no começo da conversa, uma noção do
 * MOMENTO de vida e do temperamento aproximado da pessoa. E escolheu a postura:
 * LENTE, NÃO FATO.
 *
 * A diferença não é de estilo, é de arquitetura. Uma leitura tratada como fato
 * precisa estar certa — e não está, porque é derivada de uma data. Uma leitura
 * tratada como lente só precisa ser INTERESSANTE O BASTANTE PARA A PESSOA
 * RESPONDER. O que a Alma guarda é a RESPOSTA dela, que tem lastro (§2 do
 * ALMA_SOUL_PROMPT); a previsão em si é descartável e nunca vira memória.
 *
 * Ou seja: isto é MOTOR DE COLETA disfarçado de leitura. Quando acerta, a
 * pessoa se sente vista. Quando erra, ela corrige — e a correção vale mais que
 * o acerto teria valido, porque veio dela. Não existe caso em que errar custe
 * caro, DESDE QUE a Alma nunca afirme. Todo o desenho abaixo serve a essa
 * condição.
 *
 * ── POR QUE NÃO HÁ ASCENDENTE NEM CASAS AQUI ───────────────────────────────
 * Porque não dá para calcular com o que existe, e fingir que dá é o único erro
 * que essa postura não perdoa. Ver `resolucaoDaLeitura` — a função existe
 * justamente para DECLARAR a ausência dentro do prompt, em vez de deixar o
 * modelo preencher o buraco sozinho.
 *
 * ── ZERO DEPENDÊNCIA NOVA, ZERO REDE, ZERO RELÓGIO GLOBAL ──────────────────
 * Mesma disciplina do `contextoDoUsuario.ts` e do `apoioEmCrise.ts`: módulo
 * puro, tudo entra por parâmetro (inclusive `hoje`), nada toca Firestore. É o
 * que permite exercitar cada regra por mutação.
 *
 * ── CORREGEDORIA ───────────────────────────────────────────────────────────
 * As tradições que alimentam as tabelas abaixo (astrologia, Cabala,
 * numerologia) NÃO aparecem em lugar nenhum da saída: nem nome de tradição, nem
 * nome de signo além do que o `[Mapa interno]` já emitia, nem sefirá, nem letra
 * hebraica. As tabelas guardam a tradição; o prompt recebe só a CONCLUSÃO, em
 * português comum. Isso é mais barato em tokens E fecha a superfície de
 * vazamento — o modelo não pode citar o que não recebeu.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import {
  DataDeNascimento,
  lerDataDeNascimento,
  signoSolar,
  caminhoDeVida,
  idadeEmAnos,
  formatarDataBR,
} from './contextoDoUsuario';

/* ═══════════════════════════════════════════════════════════════════════════
 * 1. O MOMENTO — ciclo pessoal de 9 anos
 *
 * Numerologia pitagórica: `mês de nascimento + dia de nascimento + ano
 * corrente`, reduzido. É o mesmo método que o `GuidanceEngine.swift` do iOS já
 * usa há tempo — com UMA diferença deliberada, documentada aqui porque ela é
 * visível:
 *
 *   ⚠️ O iOS vira o ano pessoal em 1º de JANEIRO (`personalYear` usa só o ano
 *   corrente). Aqui ele vira no ANIVERSÁRIO, que é a convenção mais comum e a
 *   única que faz o número significar "o ciclo que ESTA pessoa está vivendo".
 *
 *   Consequência: entre 1º de janeiro e o aniversário, servidor e app calculam
 *   números DIFERENTES. Ninguém vê o número (o card da Home mostra texto
 *   derivado), mas a leitura da Alma e o card podem discordar de tom nesses
 *   meses. Isso é DECISÃO DE PRODUTO, não bug — e está aberta para o Assis
 *   resolver. Não mexi no iOS: outra frente está fechando versão nele.
 * ═══════════════════════════════════════════════════════════════════════════ */

/** Qualidade de cada ano do ciclo. Frases curtas, específicas, sem promessa. */
const ANO_PESSOAL: Record<number, string> = {
  1: 'começo — plantar, decidir, sair do lugar',
  2: 'espera e vínculo — as coisas cozinham em fogo baixo',
  3: 'expressão e gente — aparecer custa e atrai',
  4: 'construção sem brilho — esforço que ninguém vê',
  5: 'ruptura e movimento — o que estava fixo se solta',
  6: 'casa e responsabilidade — cuidar de alguém pesa',
  7: 'recolhimento — revisão por dentro, menos gente',
  8: 'resultado e responsabilidade — o que foi feito cobra',
  9: 'fim de ciclo — soltar o que não vai junto',
};

/**
 * O mês pessoal, em 1–2 palavras. CALCULADO, mas HOJE NÃO EMITIDO — ver abaixo.
 *
 * ⚠️ TROCA DELIBERADA, e é reversível numa linha (2026-08-29).
 * A seção inteira tem teto de 400 tokens e fechou exatamente em 400. Quando a
 * conversa de prova B mostrou que a Alma aceitava o "não faz sentido" mas NÃO
 * devolvia a palavra para a pessoa, o conserto (tornar o pedido obrigatório em
 * vez de permitido) custou ~7 tokens que não existiam.
 *
 * Paguei com esta linha, e não com outra, porque das cinco ela é a única cujo
 * sinal se repete: o mês pessoal é derivado do ano pessoal + mês corrente, ou
 * seja, quase não traz informação nova. Recuperar-se de um erro é o coração da
 * postura "lente, não fato"; a inclinação do mês é enfeite.
 *
 * Para trazer de volta, é só reinserir a linha em `blocoLeitura` — e aí o teto
 * de 400 estoura, e alguma outra coisa tem de sair. Decisão do Assis.
 */
export const MES_PESSOAL: Record<number, string> = {
  1: 'começar', 2: 'esperar', 3: 'aparecer', 4: 'construir', 5: 'mexer',
  6: 'cuidar', 7: 'recolher', 8: 'cobrar o resultado', 9: 'encerrar',
};

export interface Momento {
  /** 1 a 9. */
  ano: number;
  /** 1 a 9. */
  mes: number;
  /** Data em que o ciclo virou (o último aniversário), em `DD/MM/AAAA`. */
  virouEm: string;
}

function reduzir(n: number): number {
  let x = n;
  while (x > 9) {
    let s = 0;
    for (const c of String(x)) s += Number(c);
    x = s;
  }
  return x;
}

/**
 * Ano e mês pessoais, virando no ANIVERSÁRIO (não em 1º de janeiro).
 *
 * O detalhe que a versão ingênua erra: antes do aniversário, o ciclo ainda é o
 * do ano anterior. Sem isso, todo mundo troca de ano pessoal em 1º de janeiro,
 * o que é exatamente o que o iOS faz e o que esta função existe para não fazer.
 */
export function momentoDeVida(d: DataDeNascimento, hoje: Date): Momento {
  const anoHoje = hoje.getUTCFullYear();
  const mesHoje = hoje.getUTCMonth() + 1;
  const diaHoje = hoje.getUTCDate();

  const jaFezAniversario =
    mesHoje > d.mes || (mesHoje === d.mes && diaHoje >= d.dia);
  const anoDoCiclo = jaFezAniversario ? anoHoje : anoHoje - 1;

  const ano = reduzir(d.mes + d.dia + anoDoCiclo);
  const mes = reduzir(ano + mesHoje);

  return {
    ano,
    mes,
    virouEm: formatarDataBR(
      `${anoDoCiclo}-${String(d.mes).padStart(2, '0')}-${String(d.dia).padStart(2, '0')}`,
    ),
  };
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 2. FASE DE VIDA — as três janelas que a IDADE sozinha resolve
 *
 * Retorno de Saturno (~29,5 anos de órbita) e oposição de Urano (~42) são os
 * dois trânsitos que qualquer astrólogo usaria para dizer "em que momento da
 * vida essa pessoa está" — e são os únicos que NÃO precisam de efeméride,
 * porque dependem só de quantos anos a pessoa tem. Órbita é constante; a data
 * de nascimento basta.
 *
 * Três janelas, e silêncio fora delas. Emitir uma linha para toda idade seria
 * pagar tokens para dizer "nada de especial", que é o que o modelo já assume.
 * ═══════════════════════════════════════════════════════════════════════════ */

const FASES: Array<{ de: number; ate: number; texto: string }> = [
  {
    de: 28, ate: 31,
    texto: 'fim do primeiro ciclo longo — o que ela montou aos 20 está sendo '
         + 'cobrado, e boa parte não vai passar',
  },
  {
    de: 40, ate: 44,
    texto: 'meio do caminho — a conta entre a vida escolhida e a vida herdada '
         + 'costuma vencer aqui',
  },
  {
    de: 57, ate: 61,
    texto: 'segunda virada longa — o que sustentou os últimos trinta anos deixa '
         + 'de sustentar sozinho',
  },
];

export function fasePorIdade(idade: number): string | null {
  if (!Number.isFinite(idade)) return null;
  for (const f of FASES) if (idade >= f.de && idade <= f.ate) return f.texto;
  return null;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 3. TEMPERAMENTO DE BASE — elemento, modalidade e a ponte cabalística
 *
 * ── QUAL RECORTE DE CABALA, E POR QUÊ ──────────────────────────────────────
 * "Cabalístico astrológico" são duas tradições que se encaixam em UM ponto
 * específico, e é só esse ponto que uso: a correspondência entre os planetas
 * regentes dos signos e as sefirot da Árvore da Vida (Marte–Gevurah,
 * Vênus–Netzach, Mercúrio–Hod, Lua–Yesod, Sol–Tiferet, Júpiter–Chesed,
 * Saturno–Binah). É a ponte clássica — raiz no Sefer Yetzirah, sistematizada
 * na tradição hermética — e é a ÚNICA que liga as duas coisas sem inventar.
 *
 * O que eu deliberadamente NÃO uso, e por quê:
 *  • Gematria de nome próprio — depende da grafia hebraica de um nome
 *    brasileiro. É chute com aparência de cálculo.
 *  • Os 72 nomes / anjos por grau — exige grau solar exato, que exige hora e
 *    efeméride. Mesmo buraco do ascendente.
 *  • Nefesh / Ruach / Neshamah — já está no preâmbulo do ALMA_SOUL_PROMPT como
 *    lente de escuta, e é onde deve ficar: é um modelo de INTERIORIDADE, não
 *    algo que se derive de uma data. Derivar seria fabricar.
 *
 * O que entra no prompt é só a CONCLUSÃO em português. Nenhum nome de sefirá,
 * planeta ou letra atravessa esta função.
 * ═══════════════════════════════════════════════════════════════════════════ */

const MODALIDADE: Record<string, string> = {
  'Áries': 'começa', 'Câncer': 'começa', 'Libra': 'começa', 'Capricórnio': 'começa',
  'Touro': 'sustenta', 'Leão': 'sustenta', 'Escorpião': 'sustenta', 'Aquário': 'sustenta',
  'Gêmeos': 'adapta', 'Virgem': 'adapta', 'Sagitário': 'adapta', 'Peixes': 'adapta',
};

/** Signo → qualidade da sefirá do seu planeta regente. Nome nenhum sai daqui. */
const CORRENTE: Record<string, string> = {
  'Áries':       'força que corta e depois olha o estrago',
  'Escorpião':   'rigor que queima o excesso, inclusive o próprio',
  'Touro':       'desejo que dura e se recusa a ser apressado',
  'Libra':       'equilíbrio que sustenta o outro antes de si',
  'Gêmeos':      'nomear e dividir em palavras o que sente',
  'Virgem':      'separar o que serve do que não serve, sem parar',
  'Câncer':      'guardar — memória e vínculo pesam mais que razão',
  'Leão':        'centro que harmoniza e precisa ser visto para existir',
  'Sagitário':   'expansão generosa que não sabe onde é a borda',
  'Peixes':      'dissolver a borda e dar sem medir quanto sobrou',
  'Capricórnio': 'dar forma, cobrar tempo, e chamar isso de dever',
  'Aquário':     'estrutura que se recusa — forma pelo coletivo, contra o próprio',
};

/* ═══════════════════════════════════════════════════════════════════════════
 * 4. TRAÇO DE FUNDO — caminho de vida
 *
 * O `caminhoDeVida` já existe e já é calculado em produção; o que faltava era
 * ele SIGNIFICAR alguma coisa dentro do prompt. Antes ia como número cru
 * ("Caminho de vida: 7") e o modelo inventava o sentido — que é o pior dos
 * mundos: dado exato com interpretação alucinada.
 *
 * Cada frase é um traço COM CUSTO, nunca um elogio. "Cuida de todo mundo e
 * cobra caro por dentro" é uma tese da qual a pessoa consegue discordar;
 * "é uma pessoa cuidadosa" não é tese, é bajulação, e serve para qualquer um.
 * ═══════════════════════════════════════════════════════════════════════════ */

const TRACO: Record<number, string> = {
  1:  'vai na frente e trava na hora de pedir ajuda',
  2:  'lê o outro antes de si e some no meio do caminho',
  3:  'comunica bem e dispersa; começar é fácil, terminar não',
  4:  'segura tudo sozinha e chama delegar de risco',
  5:  'precisa de saída e foge do que prende antes de saber se prendia',
  6:  'cuida de todo mundo e cobra caro por dentro, sem dizer',
  7:  'pensa antes de sentir e precisa de silêncio para funcionar',
  8:  'quer resultado e confunde o próprio valor com o que entrega',
  9:  'carrega o coletivo e esquece de onde a própria vida ficou',
  11: 'sente mais do que o corpo aguenta e desconfia da própria intuição',
  22: 'quer construir grande e trava no tamanho do que imaginou',
  33: 'se doa até o fim e chama isso de amor',
};

/* ═══════════════════════════════════════════════════════════════════════════
 * 5. RESOLUÇÃO — declarar o que NÃO dá para saber
 *
 * Esta é a função mais importante do arquivo, e a mais fácil de achar
 * dispensável.
 *
 * Ascendente e casas exigem hora exata E coordenadas E fuso histórico. O
 * onboarding pergunta o PERÍODO DO DIA. Então, na esmagadora maioria dos casos,
 * não existe ascendente — e um modelo de linguagem que recebe "nasceu à tarde
 * em Belo Horizonte" produz um ascendente com a maior tranquilidade, porque
 * produzir texto plausível é literalmente o que ele faz.
 *
 * Um buraco não declarado é preenchido. Um buraco declarado, não. São ~30
 * tokens para comprar a diferença entre "não sei te dizer sem a hora exata" e
 * uma afirmação inventada sobre a personalidade de alguém.
 *
 * Note que a linha existe NOS DOIS casos, inclusive quando a hora É exata: ter
 * a hora não faz o servidor calcular nada, e é justamente aí que o modelo mais
 * acharia que pode.
 *
 * ⚠️ [29/08, medido em DUAS rodadas] Esta linha precisou de dois consertos, e
 * os dois só apareceram porque a conversa foi RODADA. Leitura de código teria
 * aprovado as duas versões erradas.
 *
 *  1ª versão — "se ela perguntar, diga que precisaria da hora exata".
 *     O modelo respondeu: "Consigo, mas preciso da sua hora exata e da cidade
 *     onde você nasceu." Uma PROMESSA de cálculo que o servidor nunca cumpre.
 *     A pessoa daria a hora e não receberia nada.
 *
 *  2ª versão — acrescentei "não prometa calcular". Não bastou: o modelo
 *     respondeu "Consigo, mas para calcular com precisão preciso da sua hora
 *     exata". Proibição negativa não vence uma instrução POSITIVA que está em
 *     outro lugar do prompt — o §10 manda pedir a hora exata quando fizer
 *     diferença, e o modelo compôs as duas coisas.
 *
 *  3ª versão (esta) — em vez de proibir, DIZ O QUE FALAR: "diga que não faz
 *     esse cálculo". Instrução positiva compete de igual para igual com a do
 *     §10. Pedir a hora continua permitido; o que morre é a promessa.
 * ═══════════════════════════════════════════════════════════════════════════ */

/** Reconhece "hora exata" com a MESMA regra do `blocoIdentidadeDeNascimento`. */
function temHoraExata(identidade: unknown): boolean {
  if (typeof identidade !== 'object' || identidade === null) return false;
  const h = (identidade as { birthTime?: unknown }).birthTime;
  return typeof h === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(h.trim());
}

export function resolucaoDaLeitura(identidade: unknown): string {
  return temHoraExata(identidade)
    ? 'Resolução: ascendente e casas não existem aqui — ter a hora não é ter a '
      + 'conta feita. Não deduza; se ela perguntar, diga que não faz esse cálculo.'
    : 'Resolução: ascendente e casas não existem aqui, e sem hora exata nem '
      + 'seriam possíveis. Não deduza; se ela perguntar, diga que não faz esse '
      + 'cálculo.';
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 6. O BLOCO DE DADOS
 * ═══════════════════════════════════════════════════════════════════════════ */

/**
 * O bloco `[Leitura]`. String vazia quando não há data de nascimento — e aí a
 * instrução também não é emitida, e o prompt inteiro fica do tamanho de antes.
 */
export function blocoLeitura(birthDate: unknown, identidade: unknown, hoje: Date): string {
  const d = lerDataDeNascimento(birthDate, hoje);
  if (!d) return '';

  const m = momentoDeVida(d, hoje);
  const signo = signoSolar(d);
  const fase = fasePorIdade(idadeEmAnos(d, hoje));
  const traco = TRACO[caminhoDeVida(d)];

  const linhas = [
    `Momento: ano ${m.ano} de 9 (desde ${m.virouEm}) — ${ANO_PESSOAL[m.ano]}.`,
    // A linha do mês pessoal saiu daqui para pagar o conserto da recuperação
    // depois do "não faz sentido". Ver `MES_PESSOAL` — o cálculo continua vivo.
    ...(fase ? [`Fase: ${fase}.`] : []),
    `Base: ${signo.elemento}, ${MODALIDADE[signo.nome]} — ${CORRENTE[signo.nome]}.`,
    ...(traco ? [`Traço: ${traco}.`] : []),
    resolucaoDaLeitura(identidade),
  ];

  return `[Leitura — HIPÓTESE, não fato]\n${linhas.join('\n')}`;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 7. A INSTRUÇÃO
 *
 * Condicional pelo mesmo motivo que a `blocoColetaProgressiva`: quem não tem
 * data de nascimento não paga um token por uma regra sobre um bloco que não
 * existe. E cada mensagem paga o prompt inteiro, inclusive de quem não assina.
 *
 * Escrita como PROCEDIMENTO, não como princípio. "Seja humilde" não é
 * executável; "proponha uma coisa só, no meio da resposta, e se ela disser que
 * não bate, largue a tese e peça que ela conte" é.
 *
 * Cada uma das frases de obrigação abaixo está aí porque a frase mais fraca
 * FALHOU contra o modelo real em 29/08 — não porque soava melhor. Ver
 * `resolucaoDaLeitura` (promessa de cálculo) e a M8 de `mutacoes_lente.sh`
 * (permissão que não virava comportamento).
 * ═══════════════════════════════════════════════════════════════════════════ */

export const INSTRUCAO_DE_LENTE = `--- L. A LEITURA É PROPOSTA, NUNCA VEREDITO ---

[Leitura] descreve um período e um temperamento prováveis — você não sabe se
batem; ela sabe.

Use de um jeito só: PROPOR E PERGUNTAR, uma vez por conversa, com as suas
palavras e sem dizer de onde veio (§8).
  "Tem uma leitura que associa esse período a <X>. Faz sentido pra você?"
Proponha uma coisa só, a mais concreta, no MEIO da resposta — nunca na última
frase (§5, checagem 1).

Se ela disser que não bate: aceite de primeira, não reformule e não explique.
PEÇA que ela conte — "não faz sentido? me conta como é, então" — e siga pelo que
ela contar. Esse pedido é obrigatório e pode ser a última frase. Teimar custa a
conversa.

O que ela responder passa a valer e tem lastro (§2).

NUNCA afirme quem ela é a partir daqui ("você é assim", "seu momento é X").
A frase tem de poder ser respondida com "não".
NUNCA leia saúde, doença, corpo, morte, gravidez, dinheiro, sorte, nem nada que
ainda vai acontecer — nem em pergunta.
Se o §0 se aplicar, esta seção sai de cena.`;

/**
 * A instrução, só quando há data de nascimento (senão `''`).
 *
 * Duas metades separadas de propósito, como o `CABECALHO_DO_BLOCO` faz: a
 * instrução é texto meu, fixo; o bloco é dado da pessoa. Somar os dois num
 * número só esconde qual dos dois cresceu.
 */
export function instrucaoDeLente(birthDate: unknown, hoje: Date): string {
  return lerDataDeNascimento(birthDate, hoje) ? INSTRUCAO_DE_LENTE : '';
}

/**
 * O que o `index.ts` injeta: instrução + bloco, ou string vazia.
 *
 * Devolve já com as quebras de linha que o template espera, para o ponto de
 * injeção ser uma variável só — quanto menor o patch no `index.ts`, menor a
 * chance de ele brigar com o trabalho de outra frente que já está lá.
 */
export function secaoDeLeitura(birthDate: unknown, identidade: unknown, hoje: Date): string {
  const bloco = blocoLeitura(birthDate, identidade, hoje);
  if (!bloco) return '';
  return `${INSTRUCAO_DE_LENTE}\n\n${bloco}\n`;
}
