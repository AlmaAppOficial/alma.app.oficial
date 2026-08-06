/**
 * Máquina de estados do entitlement — peça 4.
 *
 * [2026-08-04] Fecha o furo de receita. As peças 1–3 já estão provadas em
 * produção: a regra `entitlements/{uid}` (cliente não escreve, 5 tentativas
 * reais devolveram 403) e o endpoint `appleNotifications` com verificação JWS
 * até a raiz Apple Root CA G3 (payload forjado → 401; notificação de teste real
 * da Apple → validada e persistida). O que faltava era ISTO: transformar os
 * eventos da Apple num "sim/não" sobre quem é assinante.
 *
 * ARQUITETURA — e por que a decisão é uma função pura
 *
 * `decidirEstado()` não conhece Firestore, não conhece rede e não conhece a
 * Apple. Recebe um evento já verificado e devolve o estado. Isso existe para
 * que a regra possa ser exercitada por asserção de verdade, com dezenas de
 * cenários, sem subir emulador e sem tocar em dado de ninguém — do mesmo jeito
 * que `FeminineHealthSecureStore.decidirHistórico` no app.
 * O acoplamento com o mundo fica em `aplicarEstado()`, que é burro de propósito.
 *
 * PRINCÍPIO DE SEGURANÇA: na dúvida, NÃO é assinante.
 * Evento desconhecido, data ausente, transação sem vínculo — tudo cai para
 * `active: false`. Errar para o lado de cobrar de quem já pagou é ruim; errar
 * para o lado de liberar de graça é o furo que estamos fechando. E o app já
 * trata "não sei" como não-assinante (`ehAssinante` devolve false no catch).
 *
 * O QUE ESTE ARQUIVO NÃO FAZ:
 *   • não decodifica JWS — isso é do `appleNotifications.ts`, que já valida;
 *   • não descobre o uid sozinho — depende do vínculo transação→uid, que só
 *     existe depois de o app enviar o `originalTransactionId` (ver `vincular`).
 */

/** Tipos de notificação da Apple que este módulo entende. */
export type TipoNotificacao =
  | 'SUBSCRIBED'
  | 'DID_RENEW'
  | 'DID_CHANGE_RENEWAL_STATUS'
  | 'DID_CHANGE_RENEWAL_PREF'
  | 'DID_FAIL_TO_RENEW'
  | 'EXPIRED'
  | 'GRACE_PERIOD_EXPIRED'
  | 'REFUND'
  | 'REVOKE'
  | 'OFFER_REDEEMED'
  | 'RENEWAL_EXTENDED'
  | 'PRICE_INCREASE'
  | 'REFUND_DECLINED'
  | 'CONSUMPTION_REQUEST'
  | 'TEST';

/**
 * Evento já verificado e decodificado. Os campos de data são milissegundos
 * desde a época — é como a Apple entrega (`expiresDate`, `revocationDate`).
 */
export interface EventoApple {
  tipo: string;
  subtipo?: string | null;
  originalTransactionId?: string | null;
  productId?: string | null;
  /** Fim do período pago corrente. */
  expiresDateMs?: number | null;
  /** Preenchido em reembolso/revogação. */
  revocationDateMs?: number | null;
  /** Fim do período de tolerância, quando a Apple concede um. */
  gracePeriodExpiresDateMs?: number | null;
  ambiente?: string | null;
  /**
   * Quando a Apple assinou este evento (`signedDate`).
   *
   * [2026-08-06] `decidirEstado` NÃO usa este campo — o estado depende do que
   * aconteceu, não de quando a mensagem foi emitida. Ele existe para a guarda
   * de ORDEM em `aplicarEvento`: a Apple reentrega, e pode reentregar um evento
   * VELHO depois de um novo. Sem esta data, um `DID_RENEW` atrasado sobrescreve
   * um `REFUND` recente e o reembolsado volta a ter acesso.
   */
  signedDateMs?: number | null;
}

export interface EstadoEntitlement {
  active: boolean;
  originalTransactionId: string | null;
  productId: string | null;
  /** Até quando vale. `null` quando não vale (ou quando não dá para saber). */
  expiresAtMs: number | null;
  /** Por que está nesse estado. Vai para o Firestore: sem isto, depurar é adivinhar. */
  motivo: string;
  ambiente: string | null;
  /** `false` quando o evento não é sobre assinatura e nada deve ser gravado. */
  deveGravar: boolean;
}

/** Eventos que existem, são legítimos, e não mudam o direito de acesso. */
const SEM_EFEITO: ReadonlySet<string> = new Set([
  'TEST',
  'CONSUMPTION_REQUEST',
  'REFUND_DECLINED',
  'PRICE_INCREASE',
]);

/**
 * Decide o estado do entitlement a partir de um evento verificado.
 *
 * @param evento  evento já validado criptograficamente
 * @param agoraMs relógio injetado — testes precisam de tempo determinístico
 */
export function decidirEstado(evento: EventoApple, agoraMs: number): EstadoEntitlement {
  const base = {
    originalTransactionId: evento.originalTransactionId ?? null,
    productId: evento.productId ?? null,
    ambiente: evento.ambiente ?? null,
  };
  const inativo = (motivo: string, deveGravar = true): EstadoEntitlement => ({
    ...base,
    active: false,
    expiresAtMs: null,
    motivo,
    deveGravar,
  });

  // Sem o vínculo não há a quem conceder nada.
  if (!evento.originalTransactionId) {
    return inativo('evento sem originalTransactionId', false);
  }

  if (SEM_EFEITO.has(evento.tipo)) {
    return inativo(`evento sem efeito sobre acesso: ${evento.tipo}`, false);
  }

  // Reembolso e revogação cortam na hora, mesmo dentro do período pago.
  // Quem foi reembolsado não continua com acesso porque a data ainda não chegou.
  if (evento.tipo === 'REFUND' || evento.tipo === 'REVOKE') {
    return inativo(
      `${evento.tipo.toLowerCase()} em ${formatar(evento.revocationDateMs)}`,
    );
  }

  if (evento.tipo === 'EXPIRED' || evento.tipo === 'GRACE_PERIOD_EXPIRED') {
    return inativo(`${evento.tipo.toLowerCase()}${sufixoSub(evento.subtipo)}`);
  }

  // Falha de cobrança: só continua valendo se a Apple abriu tolerância E ela
  // ainda não venceu. Sem tolerância, a assinatura caiu.
  if (evento.tipo === 'DID_FAIL_TO_RENEW') {
    const tolerancia = evento.gracePeriodExpiresDateMs ?? null;
    if (evento.subtipo === 'GRACE_PERIOD' && tolerancia && tolerancia > agoraMs) {
      return {
        ...base,
        active: true,
        expiresAtMs: tolerancia,
        motivo: `falha de cobrança, em tolerância até ${formatar(tolerancia)}`,
        deveGravar: true,
      };
    }
    return inativo('falha de cobrança sem tolerância vigente');
  }

  // Daqui para baixo são eventos de assinatura viva. Todos dependem da mesma
  // pergunta: a data de expiração ainda está no futuro?
  const ehEventoDeAcesso =
    evento.tipo === 'SUBSCRIBED' ||
    evento.tipo === 'DID_RENEW' ||
    evento.tipo === 'DID_CHANGE_RENEWAL_STATUS' ||
    evento.tipo === 'DID_CHANGE_RENEWAL_PREF' ||
    evento.tipo === 'OFFER_REDEEMED' ||
    evento.tipo === 'RENEWAL_EXTENDED';

  if (!ehEventoDeAcesso) {
    // Tipo que a Apple criou depois deste código. Não inventamos acesso.
    return inativo(`tipo desconhecido: ${evento.tipo}`, false);
  }

  const expira = evento.expiresDateMs ?? null;
  if (!expira) {
    return inativo(`${evento.tipo} sem expiresDate — não dá para afirmar acesso`);
  }
  if (expira <= agoraMs) {
    return inativo(`${evento.tipo} com expiresDate já passado (${formatar(expira)})`);
  }

  // Cancelamento com período pago em curso: continua assinante até a data.
  // Este é o caso que mais gente erra — desligar o acesso no clique do cancelar
  // é cobrar por um mês e entregar menos.
  const cancelou =
    evento.tipo === 'DID_CHANGE_RENEWAL_STATUS' && evento.subtipo === 'AUTO_RENEW_DISABLED';

  return {
    ...base,
    active: true,
    expiresAtMs: expira,
    motivo: cancelou
      ? `renovação desligada, acesso mantido até ${formatar(expira)}`
      : `${evento.tipo}${sufixoSub(evento.subtipo)} até ${formatar(expira)}`,
    deveGravar: true,
  };
}

function sufixoSub(s?: string | null): string {
  return s ? `/${s}` : '';
}

function formatar(ms?: number | null): string {
  return ms ? new Date(ms).toISOString() : 'data ausente';
}
