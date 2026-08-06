/**
 * App Store Server Notifications V2 — endpoint de recebimento.
 *
 * [2026-08-04] Existe para fechar o furo de receita: até aqui o servidor não
 * tinha NENHUMA forma confiável de saber quem é assinante. `users/{uid}` é
 * gravável pelo próprio cliente, então ler premium de lá seria deixar qualquer
 * pessoa se autoconceder assinatura. A verdade passa a vir da Apple.
 *
 * REGRA DESTE ARQUIVO: nada é aceito sem verificação criptográfica. O payload
 * chega como JWS assinado pela Apple; a `app-store-server-library` oficial
 * valida a cadeia até a raiz `Apple Root CA - G3` antes de qualquer decodagem.
 * Um payload forjado é REJEITADO com 401 e registrado.
 *
 * [2026-08-06] AGORA ESCREVE `entitlements/{uid}`. O cabeçalho antigo dizia que
 * isso era "a próxima etapa"; a etapa aconteceu. Três coisas mudaram aqui:
 *
 *   1. DECODIFICA A TRANSAÇÃO. `verifyAndDecodeNotification` devolve
 *      `data.signedTransactionInfo` como string JWS opaca — os campos que
 *      decidem acesso estão lá dentro. Sem `verifyAndDecodeTransaction`, o
 *      arquivo enxergava só `notificationType` e achava que tinha tudo.
 *
 *   2. GRAVA DESNORMALIZADO. Antes só o `payload` cru era persistido; o
 *      `reprocessarPendentes` consultava `originalTransactionId` e lia `evento`,
 *      campos que ninguém escrevia. A fila de reprocessamento era um cano sem
 *      saída, e calada. Agora os dois campos existem.
 *
 *   3. DEDUPE ATÔMICO. O `.get()` seguido de `.set()` tinha janela: duas
 *      reentregas simultâneas passavam as duas. Virou `create()`, que falha
 *      quando o documento já existe.
 */
import { onRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { verificarNotificacao, verificarTransacao, verificarRenovacao, AssinaturaInvalida } from './appleVerificador';
import { eventoDeNotificacao, TransacaoDecodificada, RenovacaoDecodificada } from './appleEvento';
import { aplicarEvento } from './entitlementApply';
import { EventoApple } from './entitlementState';

export const appleNotifications = onRequest(
  { region: 'southamerica-east1', cors: false, maxInstances: 10 },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const signedPayload = (req.body as { signedPayload?: unknown })?.signedPayload;
    if (typeof signedPayload !== 'string' || signedPayload.length === 0) {
      console.warn('[apple-notif] corpo sem signedPayload');
      res.status(400).json({ error: 'signedPayload ausente' });
      return;
    }

    // ── verificação criptográfica ────────────────────────────────────────────
    let notificacao;
    let ambienteOk;
    try {
      const r = await verificarNotificacao(signedPayload);
      notificacao = r.valor;
      ambienteOk = r.ambiente;
    } catch (e) {
      // Não decodificamos nada de um payload que não passou na assinatura.
      const detalhe = e instanceof AssinaturaInvalida ? e.detalhes.join(' | ') : String(e);
      console.error('[apple-notif] ASSINATURA INVÁLIDA — rejeitado:', detalhe);
      res.status(401).json({ error: 'assinatura inválida' });
      return;
    }

    const tipo = String(notificacao.notificationType ?? '?');
    const subtipo = notificacao.subtype ? String(notificacao.subtype) : null;
    const uuid = String(notificacao.notificationUUID ?? `sem-uuid-${Date.now()}`);

    // ── decodificação das partes internas ────────────────────────────────────
    // Cada uma é um JWS por si só e passa pela mesma cadeia de verificação.
    // Falha aqui NÃO derruba a notificação: `TEST` e `CONSUMPTION_REQUEST`
    // chegam sem transação, e `decidirEstado` já sabe recusar evento incompleto.
    let transacao: TransacaoDecodificada | null = null;
    let renovacao: RenovacaoDecodificada | null = null;

    const jwsTransacao = notificacao.data?.signedTransactionInfo;
    if (typeof jwsTransacao === 'string' && jwsTransacao.length > 0) {
      try {
        transacao = (await verificarTransacao(jwsTransacao)).valor as TransacaoDecodificada;
      } catch (e) {
        console.error(`[apple-notif] ${uuid}: transação não verificada —`, (e as Error).message);
      }
    }

    const jwsRenovacao = notificacao.data?.signedRenewalInfo;
    if (typeof jwsRenovacao === 'string' && jwsRenovacao.length > 0) {
      try {
        renovacao = (await verificarRenovacao(jwsRenovacao)).valor as RenovacaoDecodificada;
      } catch (e) {
        console.error(`[apple-notif] ${uuid}: renovação não verificada —`, (e as Error).message);
      }
    }

    const evento: EventoApple = eventoDeNotificacao(notificacao, transacao, renovacao);

    console.info(
      `[apple-notif] ✅ verificada · ${tipo}${subtipo ? '/' + subtipo : ''} · ${ambienteOk} · ` +
        `tx=${evento.originalTransactionId ?? '—'} · ${uuid}`,
    );

    // ── persistência idempotente ─────────────────────────────────────────────
    const db = admin.firestore();
    const ref = db.collection('apple_notifications').doc(uuid);
    let jaProcessada = false;

    try {
      await ref.create({
        notificationType: tipo,
        subtype: subtipo,
        environment: String(ambienteOk),
        recebidaEm: admin.firestore.FieldValue.serverTimestamp(),
        // Desnormalizados no topo: são o que `reprocessarPendentes` consulta.
        originalTransactionId: evento.originalTransactionId,
        evento,
        // Payload verificado inteiro, para auditoria e para reprocessar histórico.
        payload: JSON.parse(JSON.stringify(notificacao)),
        processada: false,
      });
    } catch (e) {
      // ALREADY_EXISTS: reentrega da Apple. Se a tentativa anterior morreu antes
      // de aplicar, `processada` continua false e vale tentar de novo — é assim
      // que uma falha parcial se conserta sozinha na próxima reentrega.
      const snap = await ref.get();
      if (!snap.exists) {
        console.error(`[apple-notif] ${uuid}: falha ao gravar —`, (e as Error).message);
        res.status(500).json({ error: 'falha ao persistir' });
        return;
      }
      jaProcessada = snap.data()?.processada === true;
      if (jaProcessada) {
        console.info(`[apple-notif] ${uuid} já processada — 200 sem reprocessar`);
        res.status(200).json({ ok: true, duplicada: true });
        return;
      }
      console.info(`[apple-notif] ${uuid} reentregue sem ter sido aplicada — tentando de novo`);
    }

    // ── aplicação do entitlement ─────────────────────────────────────────────
    // Mudança de postura em relação ao comentário antigo ("responder 200 é mais
    // importante que persistir"): agora que a notificação MUDA o acesso de
    // alguém, deixar a Apple reentregar é melhor que engolir a falha. O dedupe
    // acima garante que a reentrega não duplique nada.
    try {
      const r = await aplicarEvento(db, evento);
      await ref.update({
        processada: !r.pendente,
        resultado: r.motivo,
        aplicadoEm: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.info(
        `[apple-notif] ${uuid}: ${r.aplicado ? 'APLICADO' : 'não aplicado'}` +
          `${r.pendente ? ' (aguardando vínculo)' : ''} — ${r.motivo}`,
      );
    } catch (e) {
      console.error(`[apple-notif] ${uuid}: falha ao aplicar —`, e);
      res.status(500).json({ error: 'falha ao aplicar' });
      return;
    }

    res.status(200).json({ ok: true });
  },
);
