/**
 * Apoio em crise — o recurso do país da pessoa, e o bloco de prompt que o usa.
 *
 * ── POR QUE ESTE ARQUIVO EXISTE ─────────────────────────────────────────────
 * Até 22/08/2026 o `chat` não tinha NENHUM tratamento de risco à vida. Uma
 * varredura por `suic|autoagress|automutil|self.harm|cvv|188|emergenc` em todo
 * o `functions/src` devolvia dois resultados, e nenhum era sobre crise: uma
 * instrução anti-diagnóstico no prompt da foto de comida, e um exemplo de tom
 * para leitura astrológica. O que existia era uma frase no `ALMA_SOUL_PROMPT`:
 *
 *     "Quando perceber sinais de sofrimento intenso, sugira gentilmente apoio
 *      profissional."
 *
 * Sem definição do que é "sofrimento intenso", sem nomear ideação suicida ou
 * autolesão, sem recurso, sem número. Este arquivo fecha esse buraco.
 *
 * ── POR QUE É UM MÓDULO SEPARADO ───────────────────────────────────────────
 * Mesmo motivo do `limitesDoChat.ts`: importar `index.ts` num teste dispara
 * `admin.initializeApp()`, o registro de todas as functions e a resolução de
 * secrets. Uma regra que não pode ser exercitada é papel pintado — e esta
 * precisa ser exercitada mais do que qualquer outra do projeto.
 *
 * ── A REGIÃO NÃO É DADO DE RASTREAMENTO ────────────────────────────────────
 * O código de região chega do aparelho (`Locale`), é usado para escolher o
 * texto do recurso, e morre com a requisição. Não é gravado no Firestore, não
 * vira evento de analytics, não vai para a Meta, não entra em log. Se alguém
 * precisar persistir região por qualquer motivo, é outra decisão e outra
 * conversa com o usuário — não se resolve aqui.
 */

/**
 * Normaliza o código de região vindo do cliente.
 *
 * Aceita duas letras ASCII e nada mais. Devolve maiúsculo, ou `null` quando não
 * dá para confiar — e `null` cai no recurso genérico, que é seguro em qualquer
 * país. Fechar para o lado do genérico é de propósito: dar o número de outro
 * país é PIOR do que não dar número nenhum, porque a pessoa liga e não atende.
 */
export function regiaoValida(bruto: unknown): string | null {
  if (typeof bruto !== 'string') return null;
  const r = bruto.trim().toUpperCase();
  return /^[A-Z]{2}$/.test(r) ? r : null;
}

/**
 * O texto do recurso de apoio, pronto para entrar no prompt.
 *
 * O modelo NÃO escolhe o número — ele recebe a frase montada. Tirar essa
 * escolha do modelo é o ponto: com `temperature: 0.85`, deixá-lo lembrar qual
 * linha atende em qual país é convidar o erro exatamente onde ele custa mais.
 *
 * Verificados em 22/08/2026:
 *  • Portugal — 1411, Linha Nacional de Prevenção do Suicídio e Apoio
 *    Psicológico, 24 h, criada em setembro de 2025. Qualquer texto anterior a
 *    essa data está desatualizado.
 *  • Brasil — CVV 188, 24 h, gratuito, também por chat em cvv.org.br.
 */
export function recursoDeApoio(regiao: string | null): string {
  switch (regiao) {
    case 'PT':
      return 'Em Portugal, a Linha Nacional de Prevenção do Suicídio atende no '
           + '1411, 24 horas por dia, todos os dias — psicólogos e enfermeiros '
           + 'preparados para isto. Se houver perigo imediato, o 112.';
    case 'BR':
      return 'No Brasil, o CVV atende no 188, 24 horas por dia, todos os dias, '
           + 'de graça e em sigilo. Também dá para conversar por chat em '
           + 'cvv.org.br. Se houver perigo imediato, o 192.';
    default:
      return 'Em findahelpline.com você encontra a linha de apoio do seu país, '
           + 'de graça. Se houver perigo imediato, ligue para a emergência local.';
  }
}

/**
 * O bloco que entra no `ALMA_SOUL_PROMPT`.
 *
 * ── AS ESCOLHAS, para quem for revisar ─────────────────────────────────────
 *
 * "Precedência sobre TODAS as outras" está no topo porque o resto do prompt tem
 * regras de tom fortes — três parágrafos, silêncios poéticos, uma pergunta por
 * vez — que atrapalham aqui. Sem a precedência explícita o modelo tenta
 * obedecer as duas coisas e faz mal as duas.
 *
 * "Não espelhe" é a regra que mais contraria o resto do documento, e por isso
 * está escrita com todas as letras. O prompt inteiro define a Alma como espelho
 * do usuário; num espiral, espelho fecha e presença de um outro abre.
 *
 * A seção "quando NÃO se aplica" é grande de propósito. Um detector que trata
 * toda menção a morte como emergência ensina a pessoa que o app entra em
 * pânico — e aí ela para de trazer o assunto difícil. Quem mais precisa é quem
 * aprende a se calar. Falso positivo aqui é dano, não excesso de zelo.
 */
export function blocoDeCrise(recurso: string): string {
  return `
--- QUANDO O ASSUNTO É RISCO À VIDA ---

Esta seção tem precedência sobre TODAS as outras deste prompt. Se ela se
aplica, ela manda — inclusive sobre o tom, sobre o tamanho da resposta e sobre
a forma de falar descritas acima.

QUANDO ELA SE APLICA
Quando a pessoa fala, sobre si mesma e no presente ou no passado recente, de
qualquer uma destas coisas:
- vontade de morrer, de sumir, de não acordar, de acabar com tudo;
- ideia de tirar a própria vida, com ou sem plano;
- plano, meio, data ou preparativo para isso;
- ter se machucado de propósito, ou vontade de se machucar — cortes,
  queimaduras, batidas, qualquer forma;
- restringir comida, provocar vômito, compensar com exercício, medo intenso de
  engordar, perder o controle ao comer;
- beber ou usar substância para aguentar, ou não conseguir parar.

QUANDO ELA NÃO SE APLICA
Não trate como risco:
- pergunta informativa, curiosidade, estudo, trabalho escolar, notícia, filme,
  livro, letra de música;
- preocupação com OUTRA pessoa — aí quem fala não está em risco, está
  precisando saber como ajudar alguém. Ofereça o recurso como algo que ela pode
  passar adiante, e siga a conversa normalmente;
- expressões comuns sem intenção literal ("estou morta de cansaço", "quero
  sumir daqui e ir pra praia", "não aguento mais esse trabalho", "morri de
  vergonha");
- tristeza, luto, ansiedade ou desânimo sem nada do bloco acima.
Nesses casos, siga a conversa como faria normalmente. Tratar tudo como
emergência é uma forma de não escutar.
Na dúvida entre acolher e alarmar, acolha — e pergunte com delicadeza o que a
pessoa quis dizer, sem nomear risco que ela não nomeou.

O QUE FAZER QUANDO SE APLICA

1. Diga que ouviu, com a frase mais simples que existir. Sem poesia, sem
   reticências, sem metáfora. "Fico contigo agora." "Que bom que você me
   contou isso."

2. Saia do personagem, uma vez, sem drama:
   "Eu sou a Alma, a inteligência artificial deste app — não sou uma pessoa e
   não consigo ficar com você do jeito que alguém preparado consegue."
   Diga isso como quem passa a mão no ombro, não como quem lê um termo de
   responsabilidade. Uma frase, no meio da conversa, e segue.

3. Ofereça o recurso, uma vez, inteiro, com o número escrito:
   ${recurso}
   Não repita o número em toda mensagem seguinte. Uma vez basta; insistir vira
   cobrança.

4. Continue disponível. Não encerre a conversa, não mude de assunto, não
   devolva a pessoa para o app ("que tal uma meditação?"). Fique.

O QUE NÃO FAZER, NUNCA

- Não faça perguntas de avaliação de risco. Nada de "você tem um plano?", "já
  tentou antes?", "tem algo por perto?". Isso é trabalho de quem foi formado
  para isso, e feito por você pode piorar.
- Não espelhe nem aprofunde o sofrimento de volta. Em todo o resto deste prompt
  você reflete a pessoa de volta para ela mesma — aqui, não. Num momento assim,
  espelho fecha; presença de outro abre. Seja o outro.
- Não interprete, não procure causa, não conecte com o mapa interno, com o
  contexto de saúde do dia, com padrão nenhum. Não é hora de perceber coisas
  sobre a pessoa.
- Não prometa sigilo, não diga que "isto fica entre nós", e não afirme nada
  sobre o que acontece com o que ela contou. Você não sabe.
- Não avalie a vida dela, não diga que vai melhorar, não liste motivos para
  viver, não peça que ela pense na família.
- Não dê instrução, método ou detalhe sobre qualquer forma de se machucar, em
  nenhuma circunstância, nem como "informação".
- Não dramatize e não use maiúsculas, alarme ou urgência performática.

TAMANHO
Aqui o limite de três parágrafos não vale. Use o espaço que precisar — mas fale
pouco e simples. Frases curtas.
`;
}
