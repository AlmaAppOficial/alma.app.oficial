// analiseDeFoto.ts — análise de fotos por IA (corpo e comida)
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE ESTA FUNÇÃO EXISTE
//
// A implementação antiga chamava o Gemini DIRETO DO APLICATIVO, com a chave
// dentro do `GoogleService-Info.plist`. Três problemas independentes:
//   1. a chave vaza — basta descompactar o IPA (o projeto já rotacionou chaves
//      TTS por exposição; era o mesmo erro de novo);
//   2. sem controle — não dá para limitar taxa, auditar, trocar de modelo nem
//      desligar sem publicar versão nova na loja;
//   3. sem regime de consentimento.
//
// Aqui a chave NUNCA sai do servidor (Secret Manager, `defineSecret`), o mesmo
// caminho que o `chat` já usa.
//
// ── PROMESSA DE PRIVACIDADE QUE ESTE ARQUIVO PRECISA CUMPRIR ───────────────
// A copy do app diz, no ponto do consentimento:
//
//   "A foto é analisada e não fica guardada no Alma. O provedor de IA pode
//    mantê-la por até 30 dias apenas por segurança, e não a usa para treinar
//    modelos."
//
// Para a primeira frase ser verdade, ESTE ARQUIVO NÃO PODE:
//   • gravar a imagem no Cloud Storage;
//   • gravar a imagem (nem base64, nem recorte) no Firestore;
//   • escrever a imagem em disco (/tmp inclusive);
//   • logar a imagem.
// A imagem existe apenas como variável em memória durante a chamada e morre
// com ela. O recibo gravado em `users/{uid}/scans` guarda METADADO — tipo,
// quando, modelo, se deu certo — e nada mais.
//
// Quem mexer aqui: se precisar persistir imagem por qualquer motivo, a copy do
// app muda ANTES, não depois.
// ═══════════════════════════════════════════════════════════════════════════

import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import OpenAI from 'openai';

const openaiApiKey = defineSecret('OPENAI_API_KEY');

/**
 * MODELO — escolhido em 05/08/2026, decisão registrada.
 *
 * A conta que quase levou ao erro: `gpt-4o-mini` custa 16× menos por token de
 * TEXTO, mas conta imagem com um multiplicador ~33× maior. Na prática o custo
 * de VISÃO empata com o `gpt-4o` — às vezes fica acima. Escolher o mini "porque
 * é barato" seria escolher o pior dos dois sem economizar nada.
 *
 * Como custo empata, a escolha é por qualidade → `gpt-4o`.
 *
 * Trocar de modelo é mudar esta constante. Nada mais no app depende dela.
 */
const MODELO_VISAO = 'gpt-4o';

/** Teto por imagem depois do redimensionamento feito no aparelho. */
const MAX_BYTES_POR_FOTO = 4 * 1024 * 1024;
const MAX_FOTOS = 2;

/** Guarda anti-abuso: scan é caro, o chat não é. Contador próprio. */
const SCANS_POR_DIA = 30;

type TipoDeScan = 'corpo' | 'comida';

/** Motivos de recusa. Todos viram texto honesto na tela — nunca um número. */
type MotivoFalha =
  | 'foto_ilegivel'
  | 'foto_nao_e_do_tipo'
  | 'ia_indisponivel'
  | 'limite_diario'
  | 'resposta_invalida';

// ── Esquemas de resposta ────────────────────────────────────────────────────
// `json_schema` com `strict: true` faz o modelo devolver exatamente estes
// campos. Sem isso o parser vira adivinhação — e adivinhação foi o bug B8.

const ESQUEMA_CORPO = {
  name: 'analise_corporal',
  strict: true,
  schema: {
    type: 'object',
    additionalProperties: false,
    required: ['legivel', 'motivo', 'somatotipo', 'gorduraEstimada',
               'resumo', 'observacoes', 'focos'],
    properties: {
      // O modelo declara PRIMEIRO se dá para analisar. Se não der, os campos
      // numéricos vêm nulos e o app mostra a recusa — nunca um número.
      legivel: { type: 'boolean' },
      motivo: { type: ['string', 'null'] },
      somatotipo: { type: ['string', 'null'] },
      gorduraEstimada: { type: ['number', 'null'] },
      resumo: { type: ['string', 'null'] },
      observacoes: { type: 'array', items: { type: 'string' } },
      focos: { type: 'array', items: { type: 'string' } },
    },
  },
} as const;

const ESQUEMA_COMIDA = {
  name: 'analise_de_prato',
  strict: true,
  schema: {
    type: 'object',
    additionalProperties: false,
    required: ['legivel', 'motivo', 'nome', 'porcaoG',
               'kcalPor100', 'proteinaPor100', 'carboPor100', 'gorduraPor100'],
    properties: {
      legivel: { type: 'boolean' },
      motivo: { type: ['string', 'null'] },
      nome: { type: ['string', 'null'] },
      porcaoG: { type: ['number', 'null'] },
      kcalPor100: { type: ['number', 'null'] },
      proteinaPor100: { type: ['number', 'null'] },
      carboPor100: { type: ['number', 'null'] },
      gorduraPor100: { type: ['number', 'null'] },
    },
  },
} as const;

// ── Instruções ──────────────────────────────────────────────────────────────
// Regra 3.1/3.2 do CLAUDE.md: o Alma REGISTRA e EXIBE. Não diagnostica, não
// prescreve, não promete resultado clínico.

const INSTRUCAO_CORPO = `
Você analisa fotos corporais para um app de acompanhamento físico, em português do Brasil.

REGRAS INEGOCIÁVEIS:
- Você NÃO faz diagnóstico. Não cita doença, condição clínica, transtorno alimentar nem exame.
- Você NÃO prescreve dieta, exercício, suplemento nem dose.
- Você NÃO comenta o corpo como bom, ruim, bonito ou feio. Nada de julgamento estético.
- Tudo que você devolve é ESTIMATIVA descritiva, não medida.
- Escreva em PT-BR, com "você/seu". Tom calmo e respeitoso.

Se a foto não permitir uma estimativa honesta — muito escura, desfocada, enquadramento
que não mostra o corpo, roupa larga demais, ou não é foto de uma pessoa —
responda legivel=false e explique em "motivo", em uma frase gentil, o que atrapalhou
e o que a pessoa pode fazer diferente. NUNCA invente número quando não der para ver.

Quando der para analisar: descreva a composição corporal aparente de forma sóbria,
estime o percentual de gordura como FAIXA aproximada no campo numérico (valor central),
e liste 2 a 4 observações descritivas e 2 a 3 áreas em que a pessoa pode focar
o treino — sem prescrever séries, cargas ou dietas.
`.trim();

const INSTRUCAO_COMIDA = `
Você identifica alimentos em fotos de pratos para um app de registro alimentar,
em português do Brasil.

REGRAS INEGOCIÁVEIS:
- Você NÃO diagnostica, NÃO prescreve dieta e NÃO julga a comida como boa ou ruim,
  saudável ou não saudável. Você apenas identifica e estima.
- Tudo é ESTIMATIVA. Nunca apresente como medida exata.
- PT-BR.

Se a foto não permitir identificar a comida — escura, desfocada, ou não é comida —
responda legivel=false e diga em "motivo", em uma frase, o que atrapalhou.
NUNCA chute valores nutricionais de uma foto que você não conseguiu ler.

Quando der: nomeie o prato como uma pessoa nomearia, estime a porção visível em gramas
e os valores nutricionais POR 100 g.
`.trim();

// ── CORS ────────────────────────────────────────────────────────────────────
// O app chama por HTTPS direto (o projeto não linka o SDK de Functions), então
// não há origem de navegador legítima. Mantido restritivo de propósito.
function cors(res: { set: (k: string, v: string) => void }) {
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.set('Access-Control-Max-Age', '3600');
}

/** Aceita "data:image/jpeg;base64,XXX" ou o base64 puro. Devolve só o base64. */
export function extrairBase64(entrada: string): string | null {
  const t = entrada.trim();
  if (t.length === 0) return null;
  const m = /^data:image\/(jpeg|jpg|png|webp);base64,(.+)$/i.exec(t);
  const cru = m ? m[2] : t;
  // Base64 válido, sem espaços, tamanho plausível para uma foto.
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(cru)) return null;
  if (cru.length < 512) return null;
  return cru;
}

/** Bytes reais a partir do comprimento do base64 — sem materializar o buffer. */
export function bytesDoBase64(b64: string): number {
  const padding = b64.endsWith('==') ? 2 : b64.endsWith('=') ? 1 : 0;
  return Math.floor((b64.length * 3) / 4) - padding;
}

export const analisarFoto = onRequest(
  {
    region: 'southamerica-east1',
    secrets: [openaiApiKey],
    timeoutSeconds: 120,
    memory: '512MiB',
  },
  async (req, res) => {
    cors(res);

    if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
    if (req.method !== 'POST') {
      res.status(405).json({ ok: false, motivo: 'ia_indisponivel',
                             mensagem: 'Método não permitido.' });
      return;
    }

    // ── Autenticação: mesmo esquema do chat ────────────────────────────────
    const authHeader = (req.headers.authorization as string | undefined) ?? '';
    if (!authHeader.startsWith('Bearer ')) {
      res.status(401).json({ ok: false, motivo: 'ia_indisponivel',
                             mensagem: 'Não autorizado.' });
      return;
    }
    let uid: string;
    try {
      uid = (await admin.auth().verifyIdToken(authHeader.slice(7))).uid;
    } catch {
      res.status(401).json({ ok: false, motivo: 'ia_indisponivel',
                             mensagem: 'Sessão expirada. Entre de novo e tente.' });
      return;
    }

    // ── Entrada ────────────────────────────────────────────────────────────
    const body = req.body as {
      tipo?: unknown; fotos?: unknown; medidas?: unknown; consentimento?: unknown;
    };

    const tipo = body.tipo === 'corpo' || body.tipo === 'comida'
      ? (body.tipo as TipoDeScan) : null;
    if (!tipo) {
      res.status(400).json({ ok: false, motivo: 'ia_indisponivel',
                             mensagem: 'Tipo de análise inválido.' });
      return;
    }

    // O consentimento é dado na tela, a cada envio. O servidor RECUSA sem ele:
    // assim a promessa não depende só do cliente se comportar.
    if (body.consentimento !== true) {
      res.status(400).json({ ok: false, motivo: 'ia_indisponivel',
                             mensagem: 'Envio sem consentimento registrado.' });
      return;
    }

    const brutas = Array.isArray(body.fotos) ? body.fotos : [];
    if (brutas.length === 0 || brutas.length > MAX_FOTOS) {
      res.status(400).json({ ok: false, motivo: 'foto_ilegivel',
                             mensagem: 'Envie 1 ou 2 fotos.' });
      return;
    }

    const fotos: string[] = [];
    for (const b of brutas) {
      if (typeof b !== 'string') {
        res.status(400).json({ ok: false, motivo: 'foto_ilegivel',
                               mensagem: 'Formato de foto não reconhecido.' });
        return;
      }
      const b64 = extrairBase64(b);
      if (!b64) {
        res.status(400).json({ ok: false, motivo: 'foto_ilegivel',
                               mensagem: 'Não consegui ler essa imagem. Tente tirar de novo.' });
        return;
      }
      if (bytesDoBase64(b64) > MAX_BYTES_POR_FOTO) {
        res.status(413).json({ ok: false, motivo: 'foto_ilegivel',
                               mensagem: 'Foto muito grande. Tente de novo.' });
        return;
      }
      fotos.push(b64);
    }

    // ── Limite diário (scan é caro) ────────────────────────────────────────
    const db = admin.firestore();
    const hoje = new Date().toISOString().slice(0, 10);
    const contadorRef = db.doc(`rate_limits/${uid}`);
    try {
      await db.runTransaction(async (tx) => {
        const d = (await tx.get(contadorRef)).data() ?? {};
        const usados = d.scanDia === hoje ? ((d.scanCount as number) ?? 0) : 0;
        if (usados >= SCANS_POR_DIA) throw new Error('LIMITE');
        tx.set(contadorRef, { scanDia: hoje, scanCount: usados + 1 }, { merge: true });
      });
    } catch (e) {
      if ((e as Error).message === 'LIMITE') {
        res.status(429).json({
          ok: false, motivo: 'limite_diario',
          mensagem: 'Você já fez bastantes análises hoje. Amanhã tem mais.',
        });
        return;
      }
      console.warn('[analisarFoto] contador falhou (não fatal):', (e as Error).message);
    }

    // ── Chamada à IA ───────────────────────────────────────────────────────
    const medidas = tipo === 'corpo' && typeof body.medidas === 'object' && body.medidas
      ? body.medidas as Record<string, unknown> : null;

    const textoDoPedido = tipo === 'corpo'
      ? 'Analise estas fotos.' + (medidas
          ? ` Dados informados pela pessoa: ${JSON.stringify(medidas).slice(0, 400)}.`
          : '')
      : 'Identifique a comida desta foto.';

    let bruto: string;
    try {
      const openai = new OpenAI({ apiKey: openaiApiKey.value() });
      const resposta = await openai.chat.completions.create({
        model: MODELO_VISAO,
        max_tokens: 900,
        temperature: 0.2,          // estimativa quer estabilidade, não criatividade
        response_format: { type: 'json_schema',
                           json_schema: tipo === 'corpo' ? ESQUEMA_CORPO : ESQUEMA_COMIDA },
        messages: [
          { role: 'system', content: tipo === 'corpo' ? INSTRUCAO_CORPO : INSTRUCAO_COMIDA },
          {
            role: 'user',
            content: [
              { type: 'text', text: textoDoPedido },
              ...fotos.map((b64) => ({
                type: 'image_url' as const,
                image_url: { url: `data:image/jpeg;base64,${b64}`, detail: 'high' as const },
              })),
            ],
          },
        ],
      });
      bruto = resposta.choices[0]?.message?.content ?? '';
    } catch (e) {
      // Recusa do provedor, timeout, cota — tudo cai aqui e vira texto honesto.
      console.error('[analisarFoto] provedor falhou:', (e as Error).message);
      await recibo(db, uid, tipo, false, 'ia_indisponivel');
      res.status(502).json({
        ok: false, motivo: 'ia_indisponivel',
        mensagem: 'Não consegui analisar sua foto agora. Tente de novo em alguns minutos.',
      });
      return;
    }

    let dados: Record<string, unknown>;
    try {
      dados = JSON.parse(bruto);
    } catch {
      await recibo(db, uid, tipo, false, 'resposta_invalida');
      res.status(502).json({
        ok: false, motivo: 'resposta_invalida',
        mensagem: 'A análise voltou incompleta. Tente de novo.',
      });
      return;
    }

    // ── O ponto que gerou o bug B8: recusa NÃO pode virar número ───────────
    if (dados.legivel !== true) {
      await recibo(db, uid, tipo, false, 'foto_ilegivel');
      res.status(200).json({
        ok: false,
        motivo: 'foto_ilegivel',
        mensagem: typeof dados.motivo === 'string' && dados.motivo.trim().length > 0
          ? dados.motivo.trim()
          : 'Não consegui ler essa foto o suficiente para estimar. Tente com mais luz.',
      });
      return;
    }

    await recibo(db, uid, tipo, true, null);

    // As fotos (`fotos`, `brutas`, `body`) saem de escopo aqui e não foram
    // gravadas em lugar nenhum. É a promessa da tela, cumprida no código.
    res.status(200).json({ ok: true, tipo, modelo: MODELO_VISAO, resultado: dados });
  },
);

/**
 * Recibo do envio — METADADO, nunca a imagem.
 *
 * Existe para a pessoa poder ver no Perfil o que enviou e quando, que era a
 * recomendação do doc do gate. Guarda tipo, data, sucesso e motivo da falha.
 * Não guarda foto, não guarda medidas, não guarda o resultado.
 */
async function recibo(
  db: admin.firestore.Firestore,
  uid: string,
  tipo: TipoDeScan,
  ok: boolean,
  motivo: MotivoFalha | null,
) {
  try {
    await db.collection(`users/${uid}/scans`).add({
      tipo, ok, motivo: motivo ?? null,
      modelo: MODELO_VISAO,
      quando: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.warn('[analisarFoto] recibo falhou (não fatal):', (e as Error).message);
  }
}
