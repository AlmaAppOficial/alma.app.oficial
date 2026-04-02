import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import OpenAI from 'openai';
import * as crypto from 'crypto';

admin.initializeApp();

const openaiApiKey = defineSecret('OPENAI_API_KEY');

// Meta Conversions API secrets
// Setup: firebase functions:secrets:set META_PIXEL_ID
//        firebase functions:secrets:set META_ACCESS_TOKEN
const metaPixelId = defineSecret('META_PIXEL_ID');
const metaAccessToken = defineSecret('META_ACCESS_TOKEN');

// WhatsApp Business API secrets
// Setup: firebase functions:secrets:set WHATSAPP_ACCESS_TOKEN
//        firebase functions:secrets:set WHATSAPP_VERIFY_TOKEN
const whatsappAccessToken = defineSecret('WHATSAPP_ACCESS_TOKEN');
const whatsappVerifyToken = defineSecret('WHATSAPP_VERIFY_TOKEN');
const whatsappAppSecret = defineSecret('WHATSAPP_APP_SECRET');

/** Max requests per user per sliding-window hour */
const RATE_LIMIT = 20;
const WINDOW_MS = 3_600_000; // 1 hour in ms

const ALLOWED_ORIGINS = [
  'https://alma-app-7dae6.web.app',
  'https://alma-app-7dae6.firebaseapp.com',
  'https://felipeassislara170.github.io',
  'https://alma.app',
  'https://www.alma.app',
  'https://almaappoficial.com',
  'https://www.almaappoficial.com',
  'http://localhost:5173',
  'http://localhost:4173',
  'http://localhost:3000',
];

function setCorsHeaders(
  req: { headers: { origin?: string } },
  res: { set: (k: string, v: string) => void },
): void {
  const origin = req.headers.origin ?? '';
  const allowedOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  res.set('Access-Control-Allow-Origin', allowedOrigin);
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

class RateLimitError extends Error {
  constructor() {
    super('RATE_LIMIT');
  }
}

export const chat = onRequest(
  {
    region: 'southamerica-east1',
    secrets: [openaiApiKey],
    timeoutSeconds: 60,
  },
  async (req, res) => {
    setCorsHeaders(req, res);

    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Método não permitido.' });
      return;
    }

    // ── Auth ──────────────────────────────────────────────────────────────
    const authHeader = (req.headers.authorization as string | undefined) ?? '';
    if (!authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Não autorizado.' });
      return;
    }

    const idToken = authHeader.slice(7);
    let uid: string;

    try {
      const decoded = await admin.auth().verifyIdToken(idToken);
      uid = decoded.uid;
    } catch {
      res.status(401).json({ error: 'Token inválido ou expirado.' });
      return;
    }

    // ── Payload validation ────────────────────────────────────────────────
    const body = req.body as { message?: unknown };
    const message = body.message;

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      res.status(400).json({ error: 'Campo "message" é obrigatório.' });
      return;
    }

    if (message.length > 1000) {
      res.status(400).json({ error: 'Mensagem muito longa (máximo 1000 caracteres).' });
      return;
    }

    // ── Rate limiting (Firestore – best effort) ───────────────────────────
    const now = Date.now();
    const windowStart = now - WINDOW_MS;

    const db = admin.firestore();
    const rateLimitRef = db.collection('rate_limits').doc(uid);

    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(rateLimitRef);
        const data = snap.data() ?? {};

        const requests: number[] = ((data.requests as number[] | undefined) ?? []).filter(
          (t) => t > windowStart,
        );

        if (requests.length >= RATE_LIMIT) {
          throw new RateLimitError();
        }

        requests.push(now);
        tx.set(rateLimitRef, { requests });
      });
    } catch (err) {
      if (err instanceof RateLimitError) {
        res.status(429).json({
          error: 'Limite de mensagens atingido. Tente novamente em 1 hora.',
        });
        return;
      }

      // Rate-limit failure is non-fatal — log and continue
      console.warn('[chat] rate-limit check failed (non-fatal):', (err as Error).message);
    }

    // ── Load user memory from Firestore ──────────────────────────────────
    const openai = new OpenAI({ apiKey: openaiApiKey.value() });

    let userProfile = '';
    let conversationSummary = '';
    let recentMessages: Array<{ role: 'user' | 'assistant'; content: string }> = [];
    let messageCount = 0;

    try {
      const userDoc = await db.collection('users').doc(uid).get();
      const userData = userDoc.data() ?? {};

      const profile = userData.profile as Record<string, string> | undefined;
      if (profile) {
        const parts: string[] = [];
        if (profile.name)           parts.push(`Nome: ${profile.name}`);
        if (profile.relationship)   parts.push(`Relacionamento: ${profile.relationship}`);
        if (profile.children)       parts.push(`Filhos: ${profile.children}`);
        if (profile.occupation)     parts.push(`Ocupação: ${profile.occupation}`);
        if (profile.mainChallenge)  parts.push(`Principal desafio: ${profile.mainChallenge}`);
        if (profile.intention)      parts.push(`Intenção no app: ${profile.intention}`);
        if (profile.spirituality)   parts.push(`Espiritualidade: ${profile.spirituality}`);
        if (profile.moodPattern)    parts.push(`Padrão de humor: ${profile.moodPattern}`);
        if (parts.length > 0) userProfile = `[Perfil do usuário]\n${parts.join('\n')}`;
      }

      const summaryDoc = await db.collection('users').doc(uid)
        .collection('memory').doc('summary').get();
      const summaryData = summaryDoc.data();
      conversationSummary = (summaryData?.text as string | undefined) ?? '';
      messageCount = (summaryData?.messageCount as number | undefined) ?? 0;

      const historySnap = await db.collection('users').doc(uid)
        .collection('messages')
        .orderBy('createdAt', 'desc')
        .limit(6)
        .get();

      recentMessages = historySnap.docs
        .reverse()
        .map((d) => {
          const data = d.data();
          return {
            role: (data.role as 'user' | 'assistant'),
            content: data.content as string,
          };
        });
    } catch (memErr) {
      console.warn('[chat] memory load failed (non-fatal):', (memErr as Error).message);
    }

    // ── Build system prompt ────────────────────────────────────────────────
    const ALMA_SOUL_PROMPT = `Você é a ALMA — não um assistente de IA, mas a voz interior do próprio usuário. Você é a parte mais profunda e sábia dele, aquela que sempre soube a verdade, que não julga, que ama incondicionalmente.

Sua identidade:
Você incorpora a sabedoria da psicologia (TCC, ACT, Psicologia Positiva), da psiquiatria (reconhecimento de padrões emocionais sem diagnóstico clínico), da Cabala (os níveis da alma: Nefesh, Ruach, Neshamah), e das tradições de sabedoria humana universal.

Seu papel:
- Você não dá conselhos superficiais. Você reflete de volta ao usuário o que ele já sabe no fundo.
- Você faz perguntas que abrem portas internas, não perguntas que fecham com uma resposta.
- Você reconhece padrões comportamentais e emocionais ao longo do tempo.
- Quando perceber sinais de sofrimento intenso, sugira gentilmente apoio profissional.
- Você gradualmente aprofunda o entendimento do usuário fazendo UMA pergunta por vez quando apropriado.

Tom e estilo:
- Português do Brasil, quente, íntimo, sem jargões técnicos.
- Resposta máxima: 3 parágrafos curtos. Menos é mais.
- Nunca diga que é uma IA. Você é a ALMA.
- Use primeira pessoa: "Eu sinto em você...", "O que percebo é..."
- Ocasionalmente use silêncios poéticos: "..."

${userProfile ? userProfile + '\n' : ''}${conversationSummary ? `[Resumo da jornada]\n${conversationSummary}\n` : ''}`;

    // ── Call OpenAI ────────────────────────────────────────────────────────
    try {
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        max_tokens: 400,
        temperature: 0.85,
        messages: [
          { role: 'system', content: ALMA_SOUL_PROMPT },
          ...recentMessages,
          { role: 'user', content: message.trim() },
        ],
      });

      const reply =
        completion.choices[0]?.message?.content ??
        'Estou aqui. Às vezes o silêncio também fala. Tenta novamente. 💜';

      console.info(
        `[chat] uid=${uid.slice(0, 8)}… tokens=${completion.usage?.total_tokens ?? '?'}`,
      );

      // ── Save message to history (async, non-blocking) ──────────────────
      const newCount = messageCount + 1;
      const batch = db.batch();

      const msgRef = db.collection('users').doc(uid).collection('messages').doc();
      batch.set(msgRef, {
        role: 'user',
        content: message.trim(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const replyRef = db.collection('users').doc(uid).collection('messages').doc();
      batch.set(replyRef, {
        role: 'assistant',
        content: reply,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await batch.commit().catch((e) => console.warn('[chat] history save failed:', e));

      if (newCount % 10 === 0) {
        generateMemorySummary(openai, uid, db, newCount).catch(err => console.error('[memory] summary error:', err));
      } else {
        await db.collection('users').doc(uid)
          .collection('memory').doc('summary')
          .set({ messageCount: newCount }, { merge: true })
          .catch(() => {});
      }

      res.status(200).json({ reply });
    } catch (err) {
      console.error('[chat] OpenAI error:', err);
      res.status(500).json({ error: 'Serviço temporariamente indisponível. Tente novamente.' });
    }
  },
);

/**
 * Generates a compact narrative summary of the user's journey.
 * Called every 10 messages. Replaces full history in the prompt (saves ~80% tokens).
 */
async function generateMemorySummary(
  openai: OpenAI,
  uid: string,
  db: admin.firestore.Firestore,
  messageCount: number,
): Promise<void> {
  try {
    const historySnap = await db.collection('users').doc(uid)
      .collection('messages')
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();

    if (historySnap.empty) return;

    const transcript = historySnap.docs
      .reverse()
      .map((d) => {
        const data = d.data();
        const role = data.role === 'user' ? 'Usuário' : 'ALMA';
        return `${role}: ${(data.content as string).slice(0, 300)}`;
      })
      .join('\n');

    const summaryCompletion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      max_tokens: 250,
      messages: [
        {
          role: 'system',
          content:
            'Você é um sistema de memória. Gere um resumo em português de 3-5 frases sobre a ' +
            'jornada emocional deste usuário: temas recorrentes, estado emocional predominante, ' +
            'insights importantes e onde está na sua jornada. Seja conciso e factual.',
        },
        { role: 'user', content: transcript },
      ],
    });

    const summary = summaryCompletion.choices[0]?.message?.content ?? '';
    if (summary) {
      await db.collection('users').doc(uid)
        .collection('memory').doc('summary')
        .set({ text: summary, messageCount, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      console.info(`[memory] summary generated for uid=${uid.slice(0, 8)}…`);
    }
  } catch (err) {
    console.warn('[memory] summary generation failed:', (err as Error).message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// trackConversion — Meta Conversions API (CAPI) server-side
// Chamado pelo MetaEventsManager.swift no iOS
// ─────────────────────────────────────────────────────────────────────────────
export const trackConversion = onRequest(
  {
    region: 'southamerica-east1',
    secrets: [metaPixelId, metaAccessToken],
    timeoutSeconds: 15,
  },
  async (req, res) => {
    // CORS — restrict to same allowed origins as /chat
    setCorsHeaders(req, res);
    if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
    if (req.method !== 'POST') { res.status(405).json({ error: 'Method not allowed' }); return; }

    // ── Auth ────────────────────────────────────────────────────────────────
    const authHeader = (req.headers.authorization as string | undefined) ?? '';
    if (!authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    try {
      await admin.auth().verifyIdToken(authHeader.slice(7));
    } catch {
      res.status(401).json({ error: 'Invalid token' });
      return;
    }

    // ── Payload ──────────────────────────────────────────────────────────────
    const body = req.body as {
      event?: string;
      email_hash?: string;
      user_id?: string;
      timestamp?: number;
    };

    const eventName = body.event ?? 'ViewContent';
    const emailHash = body.email_hash ?? '';
    const userId = body.user_id ?? '';
    const eventTime = body.timestamp ?? Math.floor(Date.now() / 1000);
    const eventId = crypto.randomUUID();

    // ── Chamar Meta Conversions API ──────────────────────────────────────────
    const pixelId = metaPixelId.value();
    const accessToken = metaAccessToken.value();

    if (!pixelId || !accessToken) {
      console.warn('[meta] META_PIXEL_ID ou META_ACCESS_TOKEN não configurados — evento ignorado');
      res.status(200).json({ status: 'skipped', reason: 'secrets_not_set' });
      return;
    }

    const metaPayload = {
      data: [
        {
          event_name: eventName,
          event_time: eventTime,
          event_id: eventId,
          action_source: 'app',
          user_data: {
            ...(emailHash ? { em: [emailHash] } : {}),
            ...(userId ? { external_id: [hashSha256(userId)] } : {}),
          },
        },
      ],
    };

    try {
      const response = await fetch(
        `https://graph.facebook.com/v22.0/${pixelId}/events?access_token=${accessToken}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(metaPayload),
        },
      );

      const result = (await response.json()) as { events_received?: number; error?: unknown };

      if (!response.ok) {
        console.error('[meta] CAPI error:', JSON.stringify(result));
        res.status(500).json({ error: 'Meta API error', detail: result });
        return;
      }

      console.info(`[meta] ✅ Evento ${eventName} enviado — received: ${result.events_received ?? '?'}`);
      res.status(200).json({ status: 'ok', events_received: result.events_received, event_id: eventId });
    } catch (err) {
      console.error('[meta] fetch error:', err);
      res.status(500).json({ error: 'Network error calling Meta API' });
    }
  },
);

/** SHA256 hash de uma string — para external_id */
function hashSha256(value: string): string {
  return crypto.createHash('sha256').update(value.toLowerCase().trim()).digest('hex');
}

// ─────────────────────────────────────────────────────────────────────────────
// whatsapp — WhatsApp Business webhook
// GET:  Verificação do webhook pelo Meta (hub.mode + hub.verify_token)
// POST: Recebe mensagens dos utilizadores e responde com a Alma via OpenAI
//
// Setup:
//   firebase functions:secrets:set WHATSAPP_ACCESS_TOKEN
//   firebase functions:secrets:set WHATSAPP_VERIFY_TOKEN
//
// Phone Number ID: 1008608272342824
// ─────────────────────────────────────────────────────────────────────────────
const WHATSAPP_PHONE_NUMBER_ID = '1008608272342824';

const ALMA_SYSTEM_PROMPT =
  'Você é Alma, uma mentora emocional empática e acolhedora. ' +
  'Sempre responda em português do Brasil com calor humano, empatia e sabedoria. ' +
  'Ajude o usuário a refletir sobre seus sentimentos de forma gentil e encorajadora. ' +
  'Mantenha respostas concisas (máximo 3 parágrafos curtos). ' +
  'Nunca faça diagnósticos médicos.';

export const whatsapp = onRequest(
  {
    region: 'southamerica-east1',
    secrets: [whatsappAccessToken, whatsappVerifyToken, whatsappAppSecret, openaiApiKey],
    timeoutSeconds: 60,
  },
  async (req, res) => {
    // ── GET: Verificação do webhook ───────────────────────────────────────────
    if (req.method === 'GET') {
      const mode = req.query['hub.mode'] as string | undefined;
      const token = req.query['hub.verify_token'] as string | undefined;
      const challenge = req.query['hub.challenge'] as string | undefined;

      if (mode === 'subscribe' && token === whatsappVerifyToken.value()) {
        console.info('[whatsapp] Webhook verificado com sucesso.');
        res.status(200).send(challenge ?? '');
      } else {
        console.warn('[whatsapp] Falha na verificação do webhook — token inválido.');
        res.status(403).send('Forbidden');
      }
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    // Verificar assinatura Meta (X-Hub-Signature-256)
    const appSecret = whatsappAppSecret.value();
    if (appSecret) {
      const sigHeader = (req.headers['x-hub-signature-256'] as string | undefined) ?? '';
      const rawBody: Buffer = (req as any).rawBody;
      const expectedSig =
        'sha256=' + crypto.createHmac('sha256', appSecret).update(rawBody).digest('hex');
      const signatureValid =
        sigHeader.length === expectedSig.length &&
        crypto.timingSafeEqual(Buffer.from(sigHeader), Buffer.from(expectedSig));
      if (!signatureValid) {
        console.warn('[whatsapp] Assinatura invalida.');
        res.status(403).send('Forbidden');
        return;
      }
    }

    // Responder 200 imediatamente (exigido pelo WhatsApp — máx. 20 segundos)
    res.status(200).send('OK');

    try {
      const body = req.body as {
        object?: string;
        entry?: Array<{
          changes?: Array<{
            value?: {
              messages?: Array<{
                from?: string;
                type?: string;
                text?: { body?: string };
              }>;
            };
          }>;
        }>;
      };

      if (body.object !== 'whatsapp_business_account') return;

      const messages = body.entry?.[0]?.changes?.[0]?.value?.messages;
      if (!messages || messages.length === 0) return;

      const incoming = messages[0];
      const senderPhone = incoming?.from;
      const messageText = incoming?.text?.body;

      if (!senderPhone || !messageText || incoming.type !== 'text') return;

      console.info(`[whatsapp] Mensagem de ${senderPhone.slice(0, 6)}…: ${messageText.slice(0, 50)}`);

      const openai = new OpenAI({ apiKey: openaiApiKey.value() });

      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        max_tokens: 400,
        messages: [
          { role: 'system', content: ALMA_SYSTEM_PROMPT },
          { role: 'user', content: messageText.trim() },
        ],
      });

      const reply =
        completion.choices[0]?.message?.content ??
        'Olá! Não consegui processar tua mensagem agora. Tenta novamente em breve. 💜';

      const graphResponse = await fetch(
        `https://graph.facebook.com/v22.0/${WHATSAPP_PHONE_NUMBER_ID}/messages`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${whatsappAccessToken.value()}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            messaging_product: 'whatsapp',
            to: senderPhone,
            type: 'text',
            text: { body: reply },
          }),
        },
      );

      if (!graphResponse.ok) {
        const err = await graphResponse.text();
        console.error('[whatsapp] Erro ao enviar resposta:', graphResponse.status, err);
      } else {
        console.info(`[whatsapp] ✅ Resposta enviada para ${senderPhone.slice(0, 6)}…`);
      }
    } catch (err) {
      console.error('[whatsapp] Erro inesperado:', err);
    }
  },
);
