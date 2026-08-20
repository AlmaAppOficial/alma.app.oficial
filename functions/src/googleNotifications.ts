/**
 * Real-time Developer Notifications (RTDN) da Google — endpoint de recebimento.
 *
 * [2026-08-13] Espelho de `appleNotifications.ts`. Fecha o furo que o próprio
 * `billing.ts` já declarava como dívida aceita desde 06/08:
 *
 *   "Esta função só roda quando o APP a chama. Reembolso, cancelamento e
 *    expiração acontecem no servidor da Google e nunca chegam aqui."
 *
 * COMO A AUTENTICAÇÃO FUNCIONA AQUI — e por que não há assinatura para conferir
 *
 * Este é um gatilho de Pub/Sub, não um endpoint HTTP aberto. A mensagem chega
 * pelo Eventarc, e só a Google publica no tópico: quem não tiver permissão de
 * publicar não consegue nem bater na porta. Não existe URL pública para
 * descobrir. É o contrário exato do webhook de WhatsApp removido nesta mesma
 * sessão, que era `onRequest` sem verificação nenhuma.
 *
 * Isso NÃO significa confiar no conteúdo: a notificação diz apenas que algo
 * mudou. Todo fato que concede acesso é confirmado com a Google em
 * `consultarAssinatura` antes de virar entitlement.
 *
 * ⚠️ O QUE ESTA FUNÇÃO NÃO FAZ, E É PROPOSITAL: não trata o silêncio da Google
 * como "não é assinante". Se a consulta falhar, nada é gravado, a notificação
 * fica pendente e a função LANÇA — para o Pub/Sub reentregar com backoff. O
 * caminho de corte (reembolso/revogação) não depende da consulta e funciona com
 * a API da Google fora do ar.
 */
import { onMessagePublished } from 'firebase-functions/v2/pubsub';
import * as admin from 'firebase-admin';
import { decodificarEnvelope, eventoDeNotificacao } from './googleEvento';
import { aplicarEventoGoogle } from './googleApply';
import { consultarAssinatura } from './googleApi';
import { EventoGoogle, TIPO_REEMBOLSO } from './googleEstado';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const COLECAO_NOTIFS = 'google_notifications';

/**
 * Nome do tópico do Pub/Sub. TEM de ser igual ao configurado no Play Console
 * (Monetização → Configuração de monetização → Notificações do desenvolvedor
 * em tempo real). Se divergir, nada chega e nada acusa — por isso o nome está
 * aqui, num só lugar, e repetido no roteiro entregue ao Assis.
 *
 * NÃO é exportado de propósito: `index.ts` faz `export * from` deste arquivo, e
 * tudo que passa por lá aparece na superfície que o Firebase varre em busca de
 * funções. Uma string solta não vira função, mas manter a superfície de deploy
 * contendo APENAS funções é o que faz `firebase deploy --dry-run` ser legível.
 */
const TOPICO_RTDN = 'alma-play-rtdn';

/**
 * Completa o evento com os fatos que só a API tem.
 *
 * Reembolso e revogação NÃO passam por aqui: a Google diz na documentação que o
 * `voidedPurchaseNotification` já basta para ajuste de entitlement, e fazer o
 * corte depender de uma chamada de rede seria pôr o caminho mais importante do
 * sistema à mercê do caminho mais frágil.
 */
async function enriquecerComApi(evento: EventoGoogle): Promise<EventoGoogle> {
  if (evento.tipo === TIPO_REEMBOLSO || evento.tipo === 'SUBSCRIPTION_REVOKED') return evento;
  if (!evento.purchaseToken) return evento;

  try {
    const fatos = await consultarAssinatura(evento.purchaseToken);
    return {
      ...evento,
      estadoApi: fatos.estado,
      expiraEmMs: fatos.expiraEmMs,
      productId: fatos.productId,
    };
  } catch (err) {
    // Sem `estadoApi`, `decidirEstadoGoogle` devolve `apiIndisponivel` e NADA é
    // gravado. Este log é o que diferencia "a Google não respondeu" de "a pessoa
    // não é assinante" — dois estados que, sem ele, viram a mesma linha.
    console.error(
      `[google-notif] consulta à Google falhou para ${evento.purchaseToken.slice(0, 12)}…:`,
      err instanceof Error ? err.message : String(err),
    );
    return evento;
  }
}

export const googleNotifications = onMessagePublished(
  {
    topic: TOPICO_RTDN,
    region: 'southamerica-east1',
    /**
     * `retry: true` é OBRIGATÓRIO para o `throw` do fim desta função significar
     * alguma coisa.
     *
     * A primeira versão desta linha era `retry: false` com um comentário
     * dizendo "o reenvio é do Pub/Sub, controlado pelo throw abaixo". Estava
     * exatamente ao contrário, e a revisão de 13/08 pegou:
     * `firebase-functions/lib/v2/options.d.ts:155` define `retry` como
     * *"Whether failed executions should be delivered again"*, e o default já é
     * `false` (`providers/pubsub.js:166`). Ou seja: declarar `false` MANTINHA a
     * reentrega desligada, o `throw` só escrevia no log, e o evento morria ali.
     * Não havia risco de loop infinito — havia o problema oposto, que é perder
     * o evento.
     *
     * Com `true`, só há um caminho que lança: consulta à Google indisponível.
     * Todo o resto (tipo desconhecido, sem vínculo, duplicada) retorna normal e
     * dá ack. É o formato certo para ligar reentrega sem criar tempestade.
     */
    retry: true,
  },
  async (event) => {
    const db = admin.firestore();

    const messageId = event.data.message.messageId;
    const dados = event.data.message.data;
    if (!messageId || !dados) {
      console.warn('[google-notif] mensagem sem messageId ou sem data — descartada.');
      return;
    }

    const envelope = decodificarEnvelope(dados);
    if (!envelope) {
      console.warn(`[google-notif] ${messageId}: data não é JSON válido — descartada.`);
      return;
    }

    const evento = eventoDeNotificacao(envelope);
    if (!evento) {
      console.info(
        `[google-notif] ${messageId}: notificação sem relação com assinatura ` +
          `(${Object.keys(envelope).join(',')}) — ignorada.`,
      );
      return;
    }

    // ── DEDUPE ATÔMICO ─────────────────────────────────────────────────────
    // `create()` e não `get()`+`set()`: o segundo tem janela, e duas reentregas
    // simultâneas passariam as duas. Mesma correção que o lado Apple recebeu.
    //
    // ATENÇÃO ao que "duplicada" significa aqui: é PROCESSADA, não VISTA. Se a
    // primeira tentativa falhou por indisponibilidade da Google, o documento
    // existe com `processada: false` e a reentrega TEM de seguir adiante. Tratar
    // "já vi" como "já resolvi" transformaria uma falha temporária em perda
    // permanente do evento — e um reembolso perdido não volta.
    const ref = db.collection(COLECAO_NOTIFS).doc(messageId);
    try {
      await ref.create({
        messageId,
        tipo: evento.tipo,
        purchaseToken: evento.purchaseToken,
        evento,
        packageName: envelope.packageName ?? null,
        recebidaEm: admin.firestore.FieldValue.serverTimestamp(),
        processada: false,
      });
    } catch {
      const snap = await ref.get();
      if (snap.exists && snap.data()?.processada === true) {
        console.info(`[google-notif] ${messageId} já processada — nada a fazer.`);
        return;
      }
      console.info(`[google-notif] ${messageId} reentregue e ainda não processada — seguindo.`);
    }

    const completo = await enriquecerComApi(evento);
    // Reescreve o evento enriquecido: sem isto, `reprocessarPendentesGoogle`
    // releria a versão sem `estadoApi` e concluiria "API indisponível" para
    // sempre, mesmo com a Google de pé.
    await ref.update({ evento: completo });

    const r = await aplicarEventoGoogle(db, completo);

    await ref.update({
      processada: !r.pendente,
      resultado: r.motivo,
      aplicadoEm: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (r.estado.apiIndisponivel) {
      // LANÇA para o Pub/Sub reentregar com backoff. É o único caminho em que
      // insistir resolve: a Google volta, a consulta responde, e o evento é
      // aplicado. Sem o throw, um 503 momentâneo viraria um evento perdido.
      throw new Error(
        `[google-notif] ${messageId}: consulta à Google indisponível — reentregar. ${r.motivo}`,
      );
    }

    console.info(
      `[google-notif] ${messageId} ${evento.tipo}: ${r.aplicado ? 'aplicado' : 'não aplicado'} — ${r.motivo}`,
    );
  },
);
