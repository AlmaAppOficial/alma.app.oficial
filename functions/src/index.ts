import * as admin from 'firebase-admin'
import * as functions from 'firebase-functions'
import OpenAI from 'openai'

admin.initializeApp()

const db = admin.firestore()

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
})

// ── Constants ──────────────────────────────────────────────────────────────────
const MAX_MESSAGE_LENGTH = 2000
const RATE_LIMIT_MAX = 20     // max messages per window
const RATE_LIMIT_WINDOW_MS = 60 * 1000  // 1 minute window

// Allowed origins: Firebase Hosting and localhost for development
const ALLOWED_ORIGINS = [
  /^https:\/\/.*\.firebaseapp\.com$/,
  /^https:\/\/.*\.web\.app$/,
  /^http:\/\/localhost(:\d+)?$/,
  /^http:\/\/127\.0\.0\.1(:\d+)?$/,
]

function isAllowedOrigin(origin: string | undefined): boolean {
  if (!origin) return false
  return ALLOWED_ORIGINS.some((re) => re.test(origin))
}

/**
 * Simple per-uid rate limiting using Firestore.
 * Returns true if the request is within limits, false if rate-limited.
 */
async function checkRateLimit(uid: string): Promise<boolean> {
  const ref = db.collection('rateLimits').doc(uid)
  const now = Date.now()

  try {
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref)
      const data = snap.data() as { count: number; windowStart: number } | undefined

      if (!data || now - data.windowStart > RATE_LIMIT_WINDOW_MS) {
        // New window: reset counter
        tx.set(ref, { count: 1, windowStart: now })
        return true
      }

      if (data.count >= RATE_LIMIT_MAX) {
        return false
      }

      tx.update(ref, { count: data.count + 1 })
      return true
    })
    return result
  } catch (err) {
    // On Firestore error, allow the request (fail open) but log it
    console.error('Rate limit check failed:', err)
    return true
  }
}

/**
 * POST /api/chat
 * Requires: Authorization: Bearer <Firebase ID token>
 * Body: { message: string }  (max 2000 chars)
 * Returns: { reply: string }
 */
export const chat = functions
  .runWith({ secrets: ['OPENAI_API_KEY'] })
  .https.onRequest(async (req, res) => {
    // CORS
    const origin = req.headers.origin
    if (isAllowedOrigin(origin)) {
      res.set('Access-Control-Allow-Origin', origin!)
    }
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization')
    res.set('Vary', 'Origin')
    if (req.method === 'OPTIONS') {
      res.status(204).send('')
      return
    }

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' })
      return
    }

    // ── Auth ──────────────────────────────────────────────────────────────────
    const authHeader = req.headers.authorization ?? ''
    if (!authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Missing or invalid Authorization header' })
      return
    }

    const idToken = authHeader.slice(7)
    let uid: string
    try {
      const decoded = await admin.auth().verifyIdToken(idToken)
      uid = decoded.uid
    } catch {
      res.status(401).json({ error: 'Invalid or expired token' })
      return
    }

    // ── Payload validation ────────────────────────────────────────────────────
    const { message } = req.body as { message?: unknown }
    if (!message || typeof message !== 'string' || !message.trim()) {
      res.status(400).json({ error: 'message is required and must be a non-empty string' })
      return
    }
    if (message.length > MAX_MESSAGE_LENGTH) {
      res.status(400).json({
        error: `message exceeds maximum length of ${MAX_MESSAGE_LENGTH} characters`,
      })
      return
    }

    // ── Rate limiting ─────────────────────────────────────────────────────────
    const allowed = await checkRateLimit(uid)
    if (!allowed) {
      res.status(429).json({
        error: 'Muitas mensagens em pouco tempo. Aguarde um momento e tente novamente.',
      })
      return
    }

    // ── OpenAI ────────────────────────────────────────────────────────────────
    try {
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content:
              'Você é a Alma, uma assistente de bem-estar mental empática e acolhedora. ' +
              'Responda sempre em português do Brasil, de forma calorosa, sem julgamentos e de forma concisa. ' +
              'Você oferece apoio emocional, sugestões de meditação, técnicas de respiração e dicas de bem-estar. ' +
              'Nunca substitua um profissional de saúde mental — quando adequado, incentive o usuário a buscar ajuda profissional.',
          },
          { role: 'user', content: message.trim() },
        ],
        max_tokens: 512,
        temperature: 0.7,
      })

      const choice = completion.choices[0]
      let reply: string

      // Handle content filtering (legacy finish_reason) and modern refusal field
      if (
        choice?.finish_reason === 'content_filter' ||
        (choice?.message as { refusal?: string } | undefined)?.refusal
      ) {
        reply = 'Não consigo responder a essa mensagem. Por favor, tente reformular sua pergunta.'
      } else {
        reply =
          choice?.message?.content?.trim() ||
          'Desculpe, não consegui gerar uma resposta agora. Tente novamente.'
      }

      res.status(200).json({ reply })
    } catch (err) {
      console.error('OpenAI error:', err)
      res.status(502).json({ error: 'Não foi possível obter resposta da IA. Tente novamente.' })
    }
  })
