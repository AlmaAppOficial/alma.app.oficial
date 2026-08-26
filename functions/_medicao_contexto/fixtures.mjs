/**
 * Três pessoas de mentira, com dados do formato exato que o banco tem hoje.
 *
 * Os slugs de `mapa` são os `value` das opções de
 * `src/components/OnboardingFlow.tsx:23-103` — não rótulos. Era assim que
 * chegavam ao prompt antes: crus.
 *
 * `sub` é `users/{uid}/profile/data`, que só o Android escreve
 * (`UserProfileStore.kt:141`), e cujo único campo hoje é `birthDate`.
 */

const AGORA = Date.UTC(2026, 7, 26, 12, 0, 0);   // 26/08/2026 12:00 UTC
export const HOJE = new Date(AGORA);
const DIA = 86_400_000;

const RESUMO = [
  'Marina procura a Alma quando a ansiedade aperta, quase sempre à noite.',
  'Fala muito do trabalho — uma chefia nova que ela descreve como imprevisível —',
  'e da culpa de não estar presente com os dois filhos. Nas últimas semanas',
  'apareceu um tema novo: vontade de sair do emprego, misturada com medo de',
  'não dar conta financeiramente. Costuma chegar cansada e sair mais leve.',
].join(' ');

const CONVERSA = [
  ['user', 'oi, tudo bem? hoje foi um dia difícil'],
  ['assistant', 'Oi. Estou aqui. Me conta o que pesou hoje — sem pressa.'],
  ['user', 'reunião com minha chefe de novo. saí de lá me sentindo pequena, como se nada que eu faço bastasse'],
  ['assistant', 'Sentir-se pequena depois de uma conversa dessas diz mais sobre o tamanho que te deram naquela sala do que sobre o seu. O que ela disse que ficou ecoando?'],
  ['user', 'ela falou que eu preciso "ter mais iniciativa". mas eu faço tudo, sério'],
  ['assistant', 'Faz sentido a raiva. Quando alguém pede mais de quem já está no limite, o pedido não chega como direção — chega como acusação.'],
  ['user', 'é exatamente isso. e aí eu chego em casa e não tenho nada pra dar pros meninos'],
  ['assistant', 'Você chega vazia porque foi esvaziada, não porque não tem. São coisas diferentes, e a segunda é a que dói mais sem ser verdade.'],
  ['user', 'às vezes penso em pedir demissão. mas aí bate o pânico do dinheiro'],
  ['assistant', 'Os dois medos são reais e não se anulam. Você não precisa escolher hoje qual deles está certo.'],
  ['user', 'você acha que eu tô exagerando?'],
  ['assistant', 'Não. Acho que você está cansada de um jeito que ninguém em volta nomeou ainda.'],
  ['user', 'obrigada. preciso muito ouvir isso'],
  ['assistant', 'Fico contigo. O que te ajudaria agora — desabafar mais, ou parar um pouco?'],
  ['user', 'acho que parar. mas não consigo desligar a cabeça'],
  ['assistant', 'Então vamos devagar. Antes de desligar, o que ainda está aceso aí?'],
].map(([role, content]) => ({ role, content }));

const SAUDE = [
  'Sono: 5h20 esta noite (média da semana: 6h10)',
  'Movimento: 2.140 passos · 0 min de exercício',
  'Prática: 6 dias seguidos até ontem; hoje ainda não',
  'Humor: semana pesada',
].join('\n');

const PRATICAS = [
  1, 2, 3, 4, 5, 6, 9, 11, 14, 18, 21, 27,
].map((d) => ({ timestamp: AGORA - d * DIA, durationSec: 480 }));

export const PERSONAS = [
  {
    id: 'novo',
    titulo: 'Usuário novo — primeira mensagem, nada preenchido',
    nota: 'Nada no banco. Nem perfil, nem resumo, nem histórico. Sem consentimento de saúde ainda. 0% aqui é a resposta CERTA — não há o que saber.',
    mapa: undefined,
    sub: undefined,
    resumo: '',
    conversa: [],
    praticas: [],
    messageCount: 0,
    healthContext: '',
    regiao: 'BR',
    mensagem: 'oi',
  },
  {
    id: 'novo-android',
    titulo: 'Usuário novo — Android, informou a data no onboarding',
    nota: 'PRIMEIRA mensagem, mas o app JÁ SABE a data de nascimento: a tela do Android gravou em `users/{uid}/profile/data`. É o "0,0% para usuário novo" que não precisava ser zero.',
    mapa: undefined,
    sub: { birthDate: '1988-03-14' },
    resumo: '',
    conversa: [],
    praticas: [],
    messageCount: 0,
    healthContext: '',
    regiao: 'BR',
    mensagem: 'oi',
  },
  {
    id: 'android',
    titulo: 'Android — 3 meses de uso',
    nota: 'Informou a data de nascimento na tela do app (vai para a SUBCOLEÇÃO). Nenhum cliente nativo escreve o mapa `profile`, então ele está vazio.',
    mapa: undefined,
    sub: { birthDate: '1988-03-14' },
    resumo: RESUMO,
    conversa: CONVERSA,
    praticas: PRATICAS,
    messageCount: 184,
    healthContext: SAUDE,
    regiao: 'BR',
    mensagem: 'não durmo direito faz uma semana e hoje não aguento mais',
  },
  {
    id: 'web',
    titulo: 'Web/Capacitor — passou pelo onboarding completo',
    nota: 'Único caminho que preenche o MAPA `profile`. Sem data de nascimento (o onboarding web não pergunta).',
    mapa: {
      intention: 'ansiedade',
      mainChallenge: 'Sinto que estou falhando em tudo ao mesmo tempo — no trabalho e em casa.',
      relationship: 'casado',
      children: 'sim_2+',
      occupation: 'trabalhando_estresse',
      spirituality: 'explorando',
      name: 'Marina',
      onboardedAt: '2026-05-30T10:00:00.000Z',
    },
    sub: undefined,
    resumo: RESUMO,
    conversa: CONVERSA,
    praticas: [],
    messageCount: 184,
    healthContext: SAUDE,
    regiao: 'BR',
    mensagem: 'não durmo direito faz uma semana e hoje não aguento mais',
  },
  {
    id: 'web+android',
    titulo: 'Web + Android — os dois endereços preenchidos',
    nota: 'Fez o onboarding web e depois informou a data de nascimento no Android. É a pessoa que mais perde com a leitura de um endereço só.',
    mapa: {
      intention: 'ansiedade',
      mainChallenge: 'Sinto que estou falhando em tudo ao mesmo tempo — no trabalho e em casa.',
      relationship: 'casado',
      children: 'sim_2+',
      occupation: 'trabalhando_estresse',
      spirituality: 'explorando',
      name: 'Marina',
      onboardedAt: '2026-05-30T10:00:00.000Z',
    },
    sub: { birthDate: '1988-03-14' },
    resumo: RESUMO,
    conversa: CONVERSA,
    praticas: PRATICAS,
    messageCount: 184,
    healthContext: SAUDE,
    regiao: 'BR',
    mensagem: 'não durmo direito faz uma semana e hoje não aguento mais',
  },
];
