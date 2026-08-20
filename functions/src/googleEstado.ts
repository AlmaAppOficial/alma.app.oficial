/**
 * Máquina de estados do entitlement do GOOGLE — espelho de `entitlementState.ts`.
 *
 * [2026-08-13] Fecha o furo simétrico ao que a Apple já teve fechado em 04–06/08.
 * O buraco medido no Android era este: `validateAndroidPurchase` só roda quando
 * o APP chama. Reembolso, chargeback, cancelamento e expiração acontecem no
 * servidor da Google e nunca chegavam a lugar nenhum. Quem assinava e pedia
 * reembolso continuava com `isPremium: true` no custom claim — que é o ÚNICO
 * gate do cliente Android (`AccessRepository.currentAccess`) — para sempre.
 *
 * POR QUE ESTE ARQUIVO É UMA FUNÇÃO PURA (mesma razão do lado Apple)
 *
 * `decidirEstadoGoogle()` não conhece Firestore, não conhece rede e não conhece
 * a Google. Recebe um evento já colhido e devolve o estado. Existe para que a
 * regra seja exercitável por asserção, com dezenas de cenários, sem emulador e
 * sem tocar em dado de ninguém. O acoplamento com o mundo mora em
 * `googleApply.ts`, burro de propósito.
 *
 * PRINCÍPIO DE SEGURANÇA, HERDADO: na dúvida, NÃO é assinante.
 *
 * ⚠️ A DIFERENÇA DE CONTRATO ENTRE APPLE E GOOGLE — a parte que engana
 *
 * A Apple manda o estado inteiro assinado dentro do JWS: dá para decidir só com
 * a notificação. A Google NÃO. A própria documentação avisa, em caixa alta na
 * página de referência do RTDN:
 *
 *   "These notifications tell you only that the purchase state changed. They do
 *    not give you complete information about the purchase."
 *
 * O RTDN carrega apenas `notificationType` + `purchaseToken`. Data de expiração,
 * produto e estado real vêm de uma consulta a `purchases.subscriptionsv2.get`.
 * Por isso `EventoGoogle` tem dois grupos de campos: o que veio na notificação e
 * o que veio da consulta (`estadoApi`, `expiraEmMs`, `productId`).
 *
 * A CONSEQUÊNCIA DISSO ESTÁ NA REGRA `apiIndisponivel`, mais abaixo, e ela é a
 * parte menos óbvia deste arquivo: se a consulta à Google falhar, este módulo
 * NÃO grava "inativo". Uma indisponibilidade da API da Google não pode derrubar
 * o acesso de quem pagou. Sem essa guarda, um 503 do lado deles viraria corte de
 * acesso em massa do nosso lado — o erro exatamente oposto ao que viemos
 * consertar, e muito pior, porque atinge quem está em dia.
 *
 * A EXCEÇÃO À EXCEÇÃO: reembolso e revogação cortam SEM consulta nenhuma. A
 * documentação da Google diz explicitamente que, para ajuste de entitlement, o
 * `voidedPurchaseNotification` basta por si:
 *
 *   "If you only need to locate the right purchase and order for entitlement
 *    adjustments, the information provided in the VoidedPurchaseNotification is
 *    sufficient."
 *
 * Ou seja: o corte funciona mesmo com a API fora do ar. É o caminho que precisa
 * ser o mais robusto de todos, e é.
 *
 * Fonte da tabela de tipos (lida em 13/08/2026, página atualizada em 06/08/2026):
 * https://developer.android.com/google/play/billing/rtdn-reference
 */

/**
 * Tipos de `subscriptionNotification.notificationType`, com o número que a
 * Google manda no fio. Os nomes são os da documentação — não invente sinônimos,
 * porque estes rótulos vão para o Firestore e para o log.
 */
export const TIPOS_ASSINATURA: Readonly<Record<number, string>> = {
  1: 'SUBSCRIPTION_RECOVERED',
  2: 'SUBSCRIPTION_RENEWED',
  3: 'SUBSCRIPTION_CANCELED',
  4: 'SUBSCRIPTION_PURCHASED',
  5: 'SUBSCRIPTION_ON_HOLD',
  6: 'SUBSCRIPTION_IN_GRACE_PERIOD',
  7: 'SUBSCRIPTION_RESTARTED',
  8: 'SUBSCRIPTION_PRICE_CHANGE_CONFIRMED',
  9: 'SUBSCRIPTION_DEFERRED',
  10: 'SUBSCRIPTION_PAUSED',
  11: 'SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED',
  12: 'SUBSCRIPTION_REVOKED',
  13: 'SUBSCRIPTION_EXPIRED',
  17: 'SUBSCRIPTION_ITEMS_CHANGED',
  18: 'SUBSCRIPTION_CANCELLATION_SCHEDULED',
  19: 'SUBSCRIPTION_PRICE_CHANGE_UPDATED',
  20: 'SUBSCRIPTION_PENDING_PURCHASE_CANCELED',
  22: 'SUBSCRIPTION_PRICE_STEP_UP_CONSENT_UPDATED',
};

/** Rótulo usado para o `voidedPurchaseNotification` (reembolso/chargeback). */
export const TIPO_REEMBOLSO = 'VOIDED_PURCHASE';
/** Rótulo do `testNotification` — o botão de teste do Play Console. */
export const TIPO_TESTE = 'TEST';
/**
 * Rótulo do evento que NÃO vem da Google: é o app dizendo "acabei de comprar".
 * Existe como tipo próprio, em vez de reaproveitar `SUBSCRIPTION_PURCHASED`,
 * porque no Firestore e no log a diferença entre "a Google avisou" e "o app
 * pediu" é a primeira coisa que se quer saber quando algo não bate.
 */
export const TIPO_VALIDACAO_APP = 'VALIDACAO_DO_APP';

export interface EventoGoogle {
  /** Rótulo do tipo (ver `TIPOS_ASSINATURA`, `TIPO_REEMBOLSO`, `TIPO_TESTE`). */
  tipo: string;
  /** Identidade da compra do lado da Google. É a chave do vínculo com o uid. */
  purchaseToken?: string | null;

  // ── vem da consulta a purchases.subscriptionsv2.get ──────────────────────
  /** `subscriptionState` da API. `null` quando a consulta não foi feita/falhou. */
  estadoApi?: string | null;
  /** Maior `expiryTime` entre os line items, em ms. */
  expiraEmMs?: number | null;
  productId?: string | null;

  // ── vem do voidedPurchaseNotification ────────────────────────────────────
  /** 1 = assinatura, 2 = produto avulso. */
  productType?: number | null;
  /** 1 = reembolso total, 2 = parcial por quantidade (não se aplica a assinatura). */
  refundType?: number | null;

  /**
   * `eventTimeMillis` do envelope. É o relógio da GUARDA DE ORDEM em
   * `googleApply.aplicarEventoGoogle` — não entra na decisão de estado, pelo
   * mesmo motivo que o `signedDateMs` da Apple não entra: o estado depende do
   * que aconteceu, não de quando a mensagem foi emitida.
   */
  eventoMs?: number | null;
}

export interface EstadoGoogle {
  active: boolean;
  purchaseToken: string | null;
  productId: string | null;
  expiresAtMs: number | null;
  /** Por que está nesse estado. Vai para o Firestore: sem isto, depurar é adivinhar. */
  motivo: string;
  /** `false` quando nada deve ser gravado. */
  deveGravar: boolean;
  /**
   * `true` quando o corte vale mesmo fora de ordem (reembolso e revogação).
   * Perder um corte custa dinheiro do dono e é irreversível na prática;
   * aplicar um corte a mais custa um suporte.
   */
  cortePrioritario: boolean;
  /**
   * `true` quando o evento não pôde ser decidido porque a consulta à Google não
   * respondeu. Quem chama deve deixar a notificação PENDENTE e tentar de novo —
   * nunca tratar como "não é assinante".
   */
  apiIndisponivel: boolean;
}

/** Eventos que existem, são legítimos, e não mexem no direito de acesso. */
const SEM_EFEITO: ReadonlySet<string> = new Set([
  TIPO_TESTE,
  'SUBSCRIPTION_PRICE_CHANGE_CONFIRMED',
  'SUBSCRIPTION_PRICE_CHANGE_UPDATED',
  'SUBSCRIPTION_PRICE_STEP_UP_CONSENT_UPDATED',
  'SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED',
  'SUBSCRIPTION_ITEMS_CHANGED',
  // Cancelamento AGENDADO para o fim do período de compromisso. Nada muda hoje;
  // quando chegar a hora, vem um EXPIRED de verdade.
  'SUBSCRIPTION_CANCELLATION_SCHEDULED',
]);

/**
 * Perdeu o acesso agora. `ON_HOLD` e `PAUSED` entram aqui de propósito: em
 * ambos a Google suspende o serviço, e continuar liberando seria entregar de
 * graça. `PENDING_PURCHASE_CANCELED` é a compra pendente que nunca se
 * concretizou — não havia o que conceder.
 */
const PERDEU_ACESSO: ReadonlySet<string> = new Set([
  'SUBSCRIPTION_EXPIRED',
  'SUBSCRIPTION_ON_HOLD',
  'SUBSCRIPTION_PAUSED',
  'SUBSCRIPTION_PENDING_PURCHASE_CANCELED',
]);

/**
 * Eventos de assinatura viva. Todos dependem da mesma pergunta, e a resposta
 * NÃO está na notificação: a data de expiração ainda está no futuro?
 *
 * `SUBSCRIPTION_CANCELED` está nesta lista e é o caso que mais gente erra.
 * Cancelar desliga a renovação; o período já pago continua valendo. Cortar no
 * clique do "cancelar" é cobrar um mês e entregar menos — mesma decisão que o
 * lado Apple tomou para `AUTO_RENEW_DISABLED`.
 */
const EVENTOS_DE_ACESSO: ReadonlySet<string> = new Set([
  'SUBSCRIPTION_PURCHASED',
  'SUBSCRIPTION_RENEWED',
  'SUBSCRIPTION_RECOVERED',
  'SUBSCRIPTION_RESTARTED',
  'SUBSCRIPTION_IN_GRACE_PERIOD',
  'SUBSCRIPTION_CANCELED',
  'SUBSCRIPTION_DEFERRED',
  TIPO_VALIDACAO_APP,
]);

/**
 * Estados de `subscriptionState` que a API devolve e que dão acesso.
 * Espelha a lista que `billing.ts` já usava — a diferença é que aqui ela é
 * consultada por uma função pura e testável, em vez de estar solta no meio de
 * um handler.
 */
const ESTADOS_API_COM_ACESSO: ReadonlySet<string> = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
  'SUBSCRIPTION_STATE_CANCELED', // renovação desligada; vale até expirar
]);

/**
 * Decide o estado do entitlement a partir de um evento da Google.
 *
 * @param evento  notificação + fatos colhidos da API
 * @param agoraMs relógio injetado — testes precisam de tempo determinístico
 */
export function decidirEstadoGoogle(evento: EventoGoogle, agoraMs: number): EstadoGoogle {
  const base = {
    purchaseToken: evento.purchaseToken ?? null,
    productId: evento.productId ?? null,
  };
  const inativo = (
    motivo: string,
    opcoes: { deveGravar?: boolean; cortePrioritario?: boolean; apiIndisponivel?: boolean } = {},
  ): EstadoGoogle => ({
    ...base,
    active: false,
    expiresAtMs: null,
    motivo,
    deveGravar: opcoes.deveGravar ?? true,
    cortePrioritario: opcoes.cortePrioritario ?? false,
    apiIndisponivel: opcoes.apiIndisponivel ?? false,
  });

  // Sem o token não há a quem conceder nem de quem tirar.
  if (!evento.purchaseToken) {
    return inativo('evento sem purchaseToken', { deveGravar: false });
  }

  if (SEM_EFEITO.has(evento.tipo)) {
    return inativo(`evento sem efeito sobre acesso: ${evento.tipo}`, { deveGravar: false });
  }

  // ── CORTE PRIORITÁRIO ────────────────────────────────────────────────────
  // Reembolso, chargeback e revogação cortam na hora, mesmo dentro do período
  // pago, mesmo fora de ordem, mesmo com a API da Google fora do ar.
  if (evento.tipo === TIPO_REEMBOLSO) {
    // refundType 2 é estorno parcial por QUANTIDADE, que só existe em compra
    // avulsa multi-quantidade. Assinatura não tem quantidade, então na prática
    // não chega aqui; se chegar, não é um corte total e não derruba o acesso.
    if (evento.refundType === 2) {
      return inativo('estorno parcial por quantidade — não derruba assinatura', {
        deveGravar: false,
      });
    }
    return inativo('compra estornada (reembolso/chargeback)', { cortePrioritario: true });
  }

  if (evento.tipo === 'SUBSCRIPTION_REVOKED') {
    return inativo('assinatura revogada antes do fim do período', { cortePrioritario: true });
  }

  if (PERDEU_ACESSO.has(evento.tipo)) {
    return inativo(evento.tipo.replace('SUBSCRIPTION_', '').toLowerCase().replace(/_/g, ' '));
  }

  if (!EVENTOS_DE_ACESSO.has(evento.tipo)) {
    // Tipo que a Google criou depois deste código. Não inventamos acesso — e
    // também não tiramos o de ninguém por não conhecer o rótulo.
    return inativo(`tipo desconhecido: ${evento.tipo}`, { deveGravar: false });
  }

  // ── Daqui para baixo, quem manda é a API, não a notificação ──────────────
  //
  // Esta é a guarda que impede uma indisponibilidade da Google de virar corte de
  // acesso do nosso lado. Sem `estadoApi` não sabemos nada: não gravamos.
  if (!evento.estadoApi) {
    return inativo(`${evento.tipo} sem estado da API — consulta não respondeu`, {
      deveGravar: false,
      apiIndisponivel: true,
    });
  }

  if (!ESTADOS_API_COM_ACESSO.has(evento.estadoApi)) {
    return inativo(`API diz ${evento.estadoApi}`);
  }

  const expira = evento.expiraEmMs ?? null;
  if (!expira) {
    return inativo(`${evento.tipo} sem expiryTime — não dá para afirmar acesso`);
  }
  if (expira <= agoraMs) {
    return inativo(`${evento.tipo} com expiryTime já passado (${formatar(expira)})`);
  }

  const cancelou = evento.estadoApi === 'SUBSCRIPTION_STATE_CANCELED';

  return {
    ...base,
    active: true,
    expiresAtMs: expira,
    motivo: cancelou
      ? `renovação desligada, acesso mantido até ${formatar(expira)}`
      : `${evento.tipo} até ${formatar(expira)}`,
    deveGravar: true,
    cortePrioritario: false,
    apiIndisponivel: false,
  };
}

/**
 * O QUE FAZER COM O CUSTOM CLAIM `isPremium` — a regra que faltava.
 *
 * Isto é uma função pura de propósito: é a única parte do corte de acesso que
 * dá para provar sem emulador, e é a que decide se o cadeado do Android volta.
 * O gate do cliente Android lê SÓ o claim (`AccessRepository:52-60`), então
 * nenhum conserto no Firestore, sozinho, tranca a porta de novo.
 *
 * A GUARDA DA APPLE: quando o documento de entitlement veio da Apple, um evento
 * da Google não rebaixa o claim. `entitlements/{uid}` é um documento só, dividido
 * pelas duas lojas (desenho que já era assim antes desta sessão), e o claim vale
 * para os dois apps. Deixar um evento da Google derrubar o claim de um assinante
 * da Apple seria trocar um furo de receita por um cliente pagante trancado do
 * lado de fora — que o `alertaEntitlement.ts` já classifica como a pior falha
 * possível do produto.
 */
export type AcaoNoClaim = 'subir' | 'rebaixar' | 'nao_mexer';

export function decidirClaim(ativo: boolean, origemAnterior: string | null): AcaoNoClaim {
  if (ativo) return 'subir';
  if (origemAnterior === 'apple') return 'nao_mexer';
  return 'rebaixar';
}

/**
 * A PORTA DOS FUNDOS DO REEMBOLSO — e por que ela precisa ser fechada à mão.
 *
 * Estornar uma compra não necessariamente CANCELA a assinatura do lado da
 * Google: o reembolso só revoga quando é emitido com a opção "revoke". Existe,
 * portanto, um estado real em que a pessoa foi reembolsada e
 * `purchases.subscriptionsv2.get` continua respondendo
 * `SUBSCRIPTION_STATE_ACTIVE`.
 *
 * Nesse estado, o corte funciona — e some no minuto seguinte: o app chama
 * `validateAndroidPurchase` na abertura, a API diz "ativa", e o acesso volta.
 * O dinheiro já foi devolvido. Seria um corte que dura até a próxima vez que a
 * pessoa abre o app, ou seja, nenhum.
 *
 * Por isso o estorno fica MARCADO no documento de entitlement e, enquanto o
 * `purchaseToken` for o mesmo, nenhuma reconcessão passa. Uma compra NOVA (token
 * diferente) limpa a marca: quem foi reembolsado e assinou de novo é assinante
 * de novo.
 */
export function reconcessaoBloqueada(
  vaiFicarAtivo: boolean,
  estornadoAntes: boolean,
  mesmoToken: boolean,
): boolean {
  return vaiFicarAtivo && estornadoAntes && mesmoToken;
}

/**
 * A GUARDA DA APPLE, agora valendo para o DOCUMENTO e não só para o claim.
 *
 * [2026-08-13, achado na revisão independente] A primeira versão desta sessão
 * protegia só metade: `decidirClaim` devolvia `'nao_mexer'` para assinante da
 * Apple, mas a transação já tinha gravado `active: false, origem: 'google'` no
 * mesmo `entitlements/{uid}` — e é DESSE campo que `ehAssinante` lê para o
 * `chat`. Resultado: o assinante da Apple mantinha o cadeado aberto no app e
 * perdia o acesso no servidor. Meia guarda protege pela metade e engana por
 * inteiro, porque o docblock jurava que o caso estava coberto.
 *
 * Um evento da Google não derruba um entitlement ATIVO da Apple. O caminho
 * inverso (a Apple conceder por cima do Google) não é problema: conceder é
 * sempre seguro, e é o corte cruzado que tira o que alguém pagou.
 */
export function escritaBloqueadaPorApple(
  origemAnterior: string | null,
  ativoAnterior: boolean,
  vaiFicarAtivo: boolean,
): boolean {
  return origemAnterior === 'apple' && ativoAnterior && !vaiFicarAtivo;
}

function formatar(ms?: number | null): string {
  return ms ? new Date(ms).toISOString() : 'data ausente';
}
