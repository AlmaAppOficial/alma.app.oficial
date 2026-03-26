import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import OpenAI from 'openai';

admin.initializeApp();

const openaiApiKey = defineSecret('OPENAI_API_KEY');

/** Max requests per user per sliding-window hour */
const RATE_LIMIT = 20;
const WINDOW_MS = 3_600_000; // 1 hour in ms

const ALLOWED_ORIGINS = [
  'https://felipeassislara170.github.io',
  'http://localhost:5173',
  'http://localhost:4173',
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

    // ── Payload validation ────────────────────────────────��───────────────
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

    // ── OpenAI ────────────────────────────────────────────────────────────
    const openai = new OpenAI({ apiKey: openaiApiKey.value() });

    try {
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        max_tokens: 500,
        messages: [
          {
            role: 'system',
            content:
              'Você é Alma, uma mentora emocional empática e acolhedora. ' +
              'Sempre responda em português do Brasil com calor humano, empatia e sabedoria. ' +
              'Ajude o usuário a refletir sobre seus sentimentos de forma gentil e encorajadora. ' +
              'Mantenha respostas concisas (máximo 3 parágrafos curtos).',
          },
          { role: 'user', content: message.trim() },
        ],
      });

      const reply =
        completion.choices[0]?.message?.content ??
        'Não consegui processar sua mensagem. Tente novamente.';

      console.info(
        `[chat] uid=${uid.slice(0, 8)}… tokens=${completion.usage?.total_tokens ?? '?'}`,
      );

      res.status(200).json({ response: reply });
    } catch (err) {
      console.error('[chat] OpenAI error:', err);
      res.status(500).json({ error: 'Serviço temporariamente indisponível. Tente novamente.' });
    }
  },
);