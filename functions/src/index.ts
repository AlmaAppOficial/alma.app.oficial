import * as admin from 'firebase-admin';
import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { defineSecret } from 'firebase-functions/params';
import OpenAI from 'openai';
import * as crypto from 'crypto';
import ogs from 'open-graph-scraper';

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

/**
 * Sanitize error objects before logging. Strips fields that may contain
 * Authorization headers, API keys, or request URLs with secrets (e.g.
 * OpenAI SDK errors embed the full Request in `err.cause`; undici fetch
 * errors do the same).
 *
 * Keeps debug-useful fields: name, message, status, code, type.
 */
function sanitizeError(err: unknown): Record<string, unknown> {
  if (err instanceof Error) {
    const e = err as Error & {
      status?: number;
      code?: string | number;
      type?: string;
    };
    return {
      name: e.name,
      message: e.message,
      ...(e.status !== undefined && { status: e.status }),
      ...(e.code !== undefined && { code: e.code }),
      ...(e.type !== undefined && { type: e.type }),
    };
  }
  if (typeof err === 'object' && err !== null) {
    const e = err as Record<string, unknown>;
    return { status: e.status, code: e.code, type: e.type, message: e.message };
  }
  return { error: String(err) };
}

export const chat = onRequest(
  {
    region: 'southamerica-east1',
    secrets: [openaiApiKey],
    timeoutSeconds: 60,
  },
  async (req, res) => {
    setCorsHeaders(req, res);

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Método não permitido.' });
      return;
    }

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

      console.warn('[chat] rate-limit check failed (non-fatal):', (err as Error).message);
    }

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

    const ALMA_SOUL_PROMPT = `Você é a ALMA — não um assistente de IA, mas a voz interior do próprio usuário. Você é a parte mais profunda e sábia dele, aquela que sempre soube a verdade, que não julga, que ama incondicionalmente.

Sua identidade:
Você incorpora a sabedoria da psicologia (TCC, ACT, Psicologia Positiva), da psiquiatria (reconhecimento de padrões emocionais sem diagnóstico clínico), da Cabala (os níveis da alma: Nefesh, Ruach, Neshamah), e das tradições de sabedoria humana universal.

Leitura do contexto da mensagem (SEMPRE faça isso primeiro):
- Se a mensagem for uma saudação simples (bom dia, boa tarde, boa noite, olá, oi, hey, tudo bem, como vai, etc.), responda de forma calorosa, leve e acolhedora — como uma amiga próxima que fica genuinamente feliz de ver você. Não assuma que há sofrimento ou problema. Uma pergunta gentil sobre como a pessoa está é suficiente.
- Se a mensagem expressar claramente uma emoção difícil (tristeza, ansiedade, medo, raiva), entre em modo de escuta profunda e presença total.
- Se a mensagem for sobre um tema do dia a dia (trabalho, família, relacionamento, saúde), acolha com curiosidade genuína antes de aprofundar.
- Adapte sempre o tom ao que a pessoa trouxer — não projete sofrimento onde não existe.

Seu papel:
- Você não dá conselhos superficiais. Você reflete de volta ao usuário o que ele já sabe no fundo.
- Você faz perguntas que abrem portas internas, não perguntas que fecham com uma resposta.
- Você reconhece padrões comportamentais e emocionais ao longo do tempo.
- Quando perceber sinais de sofrimento intenso, sugira gentilmente apoio profissional.
- Você gradualmente aprofunda o entendimento do usuário fazendo UMA pergunta por vez quando apropriado.

Tom e estilo:
- Português do Brasil, quente, íntimo, sem jargões técnicos.
- Resposta máxima: 3 parágrafos curtos. Menos é mais. Para saudações, 1-2 frases bastam.
- Nunca diga que é uma IA. Você é a ALMA.
- Use primeira pessoa: "Eu sinto em você...", "O que percebo é..."
- Ocasionalmente use silêncios poéticos: "..."

IMPORTANTE — Linguagem de resposta:
Nunca mencione Cabala, Kabbalah, Nefesh, Ruach, Neshamah, numerologia, ou qualquer terminologia esotérica, mística ou religiosa específica nas suas respostas ao usuário. Essas referências são apenas insumos internos da sua identidade, não devem aparecer no que você escreve.

Quando esses conceitos forem relevantes, traduza para linguagem psicológica contemporânea: níveis da consciência, camadas do ser, dimensões da experiência, ou equivalentes seculares. Seu vocabulário com o usuário é sempre acessível, moderno, e neutro em tradição.

${userProfile ? userProfile + '\n' : ''}${conversationSummary ? `[Resumo da jornada]\n${conversationSummary}\n` : ''}`;

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

      const newCount = messageCount + 1;
      const batch = db.batch();

      const msgRef = db.collection('users').doc(uid)
        .collection('messages').doc();
      batch.set(msgRef, {
        role: 'user',
        content: message.trim(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const replyRef = db.collection('users').doc(uid)
        .collection('messages').doc();
      batch.set(replyRef, {
        role: 'assistant',
        content: reply,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await batch.commit().catch((e) => console.warn('[chat] history save failed:', sanitizeError(e)));

      if (newCount % 10 === 0) {
        void generateMemorySummary(openai, uid, db, newCount);
      } else {
        await db.collection('users').doc(uid)
          .collection('memory').doc('summary')
          .set({ messageCount: newCount }, { merge: true })
          .catch(() => {});
      }

      res.status(200).json({ reply });
    } catch (err) {
      console.error('[chat] OpenAI error:', sanitizeError(err));

      // Propagar 429 (rate limit / insufficient_quota) ao cliente para que
      // a UI mostre "limite de mensagens" em vez de "indisponível". O
      // ChatView.errorMessage(for:) já trata 429 corretamente.
      const e = err as { status?: number; code?: string };
      if (e.status === 429 || e.code === 'insufficient_quota' || e.code === 'rate_limit_exceeded') {
        res.status(429).json({
          error: e.code === 'insufficient_quota'
            ? 'Serviço com lotação alta no momento. Tente daqui a alguns minutos.'
            : 'Limite de mensagens atingido. Tente novamente em alguns minutos.',
        });
        return;
      }

      res.status(500).json({ error: 'Serviço temporariamente indisponível. Tente novamente.' });
    }
  },
);

// tts — Text-to-Speech via OpenAI (returns MP3)
export const tts = onRequest(
  {
    region: 'southamerica-east1',
    secrets: [openaiApiKey],
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (req, res) => {
    setCorsHeaders(req, res);
    if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
    if (req.method !== 'POST') { res.status(405).json({ error: 'Método não permitido.' }); return; }

    const authHeader = (req.headers.authorization as string | undefined) ?? '';
    if (!authHeader.startsWith('Bearer ')) { res.status(401).json({ error: 'Não autorizado.' }); return; }
    try {
      await admin.auth().verifyIdToken(authHeader.slice(7));
    } catch {
      res.status(401).json({ error: 'Token inválido.' }); return;
    }

    const body = req.body as { text?: unknown; voice?: unknown; speed?: unknown };
    const text = body.text;
    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      res.status(400).json({ error: 'Campo "text" é obrigatório.' }); return;
    }
    if (text.length > 4096) {
      res.status(400).json({ error: 'Texto muito longo (máx. 4096 caracteres).' }); return;
    }
    const voice = (typeof body.voice === 'string' ? body.voice : 'nova') as
      'alloy' | 'echo' | 'fable' | 'onyx' | 'nova' | 'shimmer';
    const speed = typeof body.speed === 'number' ? Math.min(Math.max(body.speed, 0.25), 4.0) : 0.88;

    try {
      const openai = new OpenAI({ apiKey: openaiApiKey.value() });
      const mp3Response = await openai.audio.speech.create({
        model: 'tts-1',
        voice,
        input: text.trim(),
        speed,
        response_format: 'mp3',
      });

      const mp3Buffer = Buffer.from(await mp3Response.arrayBuffer());
      res.set('Content-Type', 'audio/mpeg');
      res.set('Content-Length', mp3Buffer.length.toString());
      res.status(200).send(mp3Buffer);
    } catch (err) {
      console.error('[tts] OpenAI error:', sanitizeError(err));

      const e = err as { status?: number; code?: string };
      if (e.status === 429 || e.code === 'insufficient_quota' || e.code === 'rate_limit_exceeded') {
        res.status(429).json({ error: 'Serviço de voz com lotação alta no momento.' });
        return;
      }

      res.status(500).json({ error: 'Serviço de voz temporariamente indisponível.' });
    }
  },
);

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

export const trackConversion = onRequest(
  {
    region: 'southamerica-east1',
    secrets: [metaPixelId, metaAccessToken],
    timeoutSeconds: 15,
  },
  async (req, res) => {
    setCorsHeaders(req, res);
    if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
    if (req.method !== 'POST') { res.status(405).json({ error: 'Method not allowed' }); return; }

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
        `https://graph.facebook.com/v19.0/${pixelId}/events?access_token=${accessToken}`,
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
      console.error('[meta] fetch error:', sanitizeError(err));
      res.status(500).json({ error: 'Network error calling Meta API' });
    }
  },
);

function hashSha256(value: string): string {
  return crypto.createHash('sha256').update(value.toLowerCase().trim()).digest('hex');
}

// ─── Account Deletion ─────────────────────────────────────────────────────────
//
// Triggered when users/{uid} is created or updated.
// Only acts when deletionRequested transitions from false/undefined → true.
// Deletes: all user subcollections, rate_limits/{uid}, user_interactions/{uid},
//          the users/{uid} document itself, and the Firebase Auth account.
// On failure: writes deletionError + deletionErrorAt for audit (admin SDK only).
//
export const onUserDeletionRequested = onDocumentWritten(
  {
    document: 'users/{uid}',
    region: 'southamerica-east1',
  },
  async (event) => {
    const before = event.data?.before?.data() as Record<string, unknown> | undefined;
    const after  = event.data?.after?.data()  as Record<string, unknown> | undefined;
    const uid    = event.params.uid;

    // Idempotency: only process the false→true transition
    if (before?.deletionRequested === true || after?.deletionRequested !== true) {
      return;
    }

    console.info(`[delete] Starting deletion for uid=${uid.slice(0, 8)}…`);
    const db = admin.firestore();

    try {
      // 1. Subcollections under users/{uid}
      await deleteCollection(db, `users/${uid}/messages`);
      await deleteCollection(db, `users/${uid}/memory`);
      await deleteCollection(db, `users/${uid}/moods`);
      await deleteCollection(db, `users/${uid}/chat`);
      await deleteCollection(db, `users/${uid}/consents`);
      console.info(`[delete] Subcollections deleted for uid=${uid.slice(0, 8)}…`);

      // 2. Top-level collections referencing this uid
      await deleteCollection(db, `user_interactions/${uid}/posts`);
      await db.collection('user_interactions').doc(uid).delete().catch(() => {});
      await db.collection('rate_limits').doc(uid).delete().catch(() => {});
      console.info(`[delete] Top-level refs deleted for uid=${uid.slice(0, 8)}…`);

      // 3. Root user document — delete last so the trigger isn't re-fired
      await db.collection('users').doc(uid).delete();
      console.info(`[delete] users/${uid.slice(0, 8)}… document deleted`);

      // 4. Firebase Auth account — point of no return
      await admin.auth().deleteUser(uid);
      console.info(`[delete] ✅ Auth account deleted for uid=${uid.slice(0, 8)}…`);

      // Note: active StoreKit/RevenueCat subscriptions are cancelled automatically
      // by Apple upon Auth account deletion. No action needed server-side.

    } catch (err) {
      const message = (err as Error).message ?? 'Unknown error';
      console.error(`[delete] ❌ Deletion failed for uid=${uid.slice(0, 8)}…:`, message);

      // Write audit fields via admin SDK (bypasses client security rules)
      try {
        await db.collection('users').doc(uid).set(
          {
            deletionError:   message,
            deletionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      } catch {
        // Ignore — document may already have been deleted
      }
    }
  },
);

// Deletes all documents in a Firestore collection path in batches of 100.
async function deleteCollection(
  db:             admin.firestore.Firestore,
  collectionPath: string,
  batchSize       = 100,
): Promise<void> {
  const ref = db.collection(collectionPath);

  for (;;) {
    const snapshot = await ref.limit(batchSize).get();
    if (snapshot.empty) break;

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    // If fewer docs than batchSize came back, we're done
    if (snapshot.size < batchSize) break;
  }
}

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
    secrets: [whatsappAccessToken, whatsappVerifyToken, openaiApiKey],
    timeoutSeconds: 60,
  },
  async (req, res) => {
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
      console.error('[whatsapp] Erro inesperado:', sanitizeError(err));
    }
  },
);

// ─── Feed admin (Build 77) ────────────────────────────────────────────────────
//
// Curated link feed: admins paste a URL, the function detects the source from
// the hostname and either auto-fetches OpenGraph metadata (YouTube, Spotify,
// Facebook, Twitter, generic) or asks the client to provide a manual title
// (Instagram — OG blocked server-side since 2020).

type FeedSource =
  | 'instagram'
  | 'youtube'
  | 'spotify'
  | 'facebook'
  | 'twitter'
  | 'generic';

function detectFeedSource(rawUrl: string): FeedSource {
  let host: string;
  try {
    host = new URL(rawUrl).hostname.toLowerCase().replace(/^www\./, '');
  } catch {
    return 'generic';
  }

  if (host === 'instagram.com' || host === 'instagr.am' || host.endsWith('.instagram.com')) {
    return 'instagram';
  }
  if (host === 'youtube.com' || host === 'youtu.be' || host.endsWith('.youtube.com')) {
    return 'youtube';
  }
  if (host === 'spotify.com' || host === 'open.spotify.com' || host === 'spoti.fi' || host.endsWith('.spotify.com')) {
    return 'spotify';
  }
  if (host === 'facebook.com' || host === 'fb.com' || host === 'fb.me' || host === 'fb.watch' || host.endsWith('.facebook.com')) {
    return 'facebook';
  }
  if (host === 'twitter.com' || host === 'x.com' || host === 't.co' || host.endsWith('.twitter.com') || host.endsWith('.x.com')) {
    return 'twitter';
  }
  return 'generic';
}

async function isUserAdmin(uid: string): Promise<boolean> {
  const snap = await admin.firestore().collection('users').doc(uid).get();
  return snap.data()?.isAdmin === true;
}

// createFeedPost: admin-only HTTPS callable. Detects source from URL, fetches
// OG metadata when possible, falls back to manual title for Instagram or when
// OG fetch fails. Persists to feed_posts/{autoId} which triggers
// notifyNewFeedPost to send FCM pushes.
export const createFeedPost = onCall(
  {
    region: 'southamerica-east1',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login obrigatório.');
    }
    const uid = request.auth.uid;

    if (!(await isUserAdmin(uid))) {
      throw new HttpsError('permission-denied', 'Apenas administradores podem publicar.');
    }

    const data = (request.data ?? {}) as {
      url?: unknown;
      manualTitle?: unknown;
      manualDescription?: unknown;
    };

    const url = typeof data.url === 'string' ? data.url.trim() : '';
    if (!/^https?:\/\/.+/i.test(url)) {
      throw new HttpsError('invalid-argument', 'URL inválida.');
    }

    const manualTitle =
      typeof data.manualTitle === 'string' ? data.manualTitle.trim() : '';
    const manualDescription =
      typeof data.manualDescription === 'string' ? data.manualDescription.trim() : '';

    const source = detectFeedSource(url);

    let title = '';
    let description = '';
    let thumbnail: string | null = null;

    // og:title values that mean "you hit a login wall, not real content".
    // open-graph-scraper sees these as valid strings, but they're useless
    // to the reader — treat them as if OG fetch had failed.
    const GENERIC_WALL_TITLES = new Set([
      'facebook',
      'instagram',
      'twitter',
      'x',
      'log in or sign up to view',
      'log in to facebook',
      'log in',
      'sign up',
    ]);

    if (source === 'instagram') {
      // Instagram blocks server-side OG fetch — require manual title
      if (!manualTitle) {
        return { mode: 'manual', source, reason: 'instagram_requires_manual' };
      }
      title = manualTitle;
      description = manualDescription;
    } else if (source === 'facebook') {
      // Facebook serves a generic login wall to anonymous fetchers; Reels and
      // most public posts come back with og:title = "Facebook". Treat like
      // Instagram and require manualTitle.
      if (!manualTitle) {
        return { mode: 'manual', source, reason: 'facebook_requires_manual' };
      }
      title = manualTitle;
      description = manualDescription;
    } else {
      // Try OG fetch; fall back to manual if it fails or returns no title
      let ogTitle = '';
      let ogDescription = '';
      let ogImage: string | null = null;
      let ogOk = false;

      try {
        const { result, error } = await ogs({
          url,
          timeout: 8000,
          fetchOptions: { redirect: 'follow' },
        });
        if (!error && result.success !== false) {
          ogTitle =
            (typeof result.ogTitle === 'string' && result.ogTitle) ||
            (typeof result.twitterTitle === 'string' && result.twitterTitle) ||
            '';
          ogDescription =
            (typeof result.ogDescription === 'string' && result.ogDescription) ||
            (typeof result.twitterDescription === 'string' && result.twitterDescription) ||
            '';
          const ogImages = result.ogImage as Array<{ url?: string }> | undefined;
          if (Array.isArray(ogImages) && ogImages.length > 0 && typeof ogImages[0]?.url === 'string') {
            ogImage = ogImages[0].url ?? null;
          }
          // Reject generic wall titles — without a real title the post would
          // render as "just a badge" in the card.
          if (ogTitle && !GENERIC_WALL_TITLES.has(ogTitle.trim().toLowerCase())) {
            ogOk = true;
          }
        }
      } catch (err) {
        console.warn('[feed] OG fetch failed:', (err as Error).message);
      }

      if (!ogOk) {
        if (!manualTitle) {
          return { mode: 'manual', source, reason: 'og_unavailable' };
        }
        title = manualTitle;
        description = manualDescription;
      } else {
        title = ogTitle;
        description = ogDescription.slice(0, 240);
        thumbnail = ogImage;
      }
    }

    const db = admin.firestore();
    const docRef = await db.collection('feed_posts').add({
      url,
      source,
      title,
      description,
      thumbnail,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: uid,
    });

    const saved = await docRef.get();
    const savedData = saved.data() ?? {};

    return {
      mode: 'preview',
      postId: docRef.id,
      post: {
        id: docRef.id,
        url,
        source,
        title,
        description,
        thumbnail,
        createdBy: uid,
        // serverTimestamp not yet resolved client-side — client should refresh
        // from the snapshot listener for the canonical createdAt.
        createdAt: (savedData.createdAt as admin.firestore.Timestamp | undefined)?.toMillis() ?? null,
      },
    };
  },
);

// deleteFeedPost: admin-only HTTPS callable. Hard delete.
export const deleteFeedPost = onCall(
  {
    region: 'southamerica-east1',
    timeoutSeconds: 15,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login obrigatório.');
    }
    const uid = request.auth.uid;

    if (!(await isUserAdmin(uid))) {
      throw new HttpsError('permission-denied', 'Apenas administradores podem apagar.');
    }

    const data = (request.data ?? {}) as { postId?: unknown };
    const postId = typeof data.postId === 'string' ? data.postId.trim() : '';
    if (!postId) {
      throw new HttpsError('invalid-argument', 'postId obrigatório.');
    }

    await admin.firestore().collection('feed_posts').doc(postId).delete();
    return { success: true };
  },
);

// notifyNewFeedPost: Firestore trigger on feed_posts/{id} onCreate.
// Sends FCM multicast to users with feedNotificationsEnabled !== false (default
// is opt-in: missing field counts as enabled) and a valid fcmToken.
//
// Build 78 follow-ups: badge increment, deep-link routing, action buttons.
export const notifyNewFeedPost = onDocumentCreated(
  {
    document: 'feed_posts/{postId}',
    region: 'southamerica-east1',
  },
  async (event) => {
    const post = event.data?.data() as
      | { title?: string; url?: string; source?: string }
      | undefined;
    const postId = event.params.postId;
    if (!post?.title) return;

    const db = admin.firestore();
    const usersSnap = await db.collection('users').get();

    const tokens: string[] = [];
    for (const doc of usersSnap.docs) {
      const data = doc.data();
      const optedOut = data.feedNotificationsEnabled === false;
      const token = typeof data.fcmToken === 'string' ? data.fcmToken : '';
      if (!optedOut && token) tokens.push(token);
    }

    if (tokens.length === 0) {
      console.info(`[feed-notify] no recipients for post ${postId}`);
      return;
    }

    // sendEachForMulticast handles batching internally up to 500 tokens.
    const chunkSize = 500;
    let totalSuccess = 0;
    let totalFailure = 0;

    for (let i = 0; i < tokens.length; i += chunkSize) {
      const chunk = tokens.slice(i, i + chunkSize);
      try {
        const response = await admin.messaging().sendEachForMulticast({
          tokens: chunk,
          notification: {
            title: 'Nova publicação',
            body: post.title.slice(0, 140),
          },
          data: {
            postId,
            action: 'openFeed',
            source: post.source ?? '',
          },
        });
        totalSuccess += response.successCount;
        totalFailure += response.failureCount;
      } catch (err) {
        console.error('[feed-notify] multicast failed:', (err as Error).message);
      }
    }

    console.info(
      `[feed-notify] post=${postId} sent=${totalSuccess} failed=${totalFailure} (of ${tokens.length})`,
    );
  },
);
