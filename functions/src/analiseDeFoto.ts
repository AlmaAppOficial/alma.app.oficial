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
  | 'resposta_invalida'
  | 'resposta_incompleta';

/**
 * VALORES QUE O APP SABE LER — e por que eles vivem aqui, no servidor.
 *
 * [2026-08-12] O app 2.0.1 (build 95) está na loja e o cliente dele é IMUTÁVEL
 * até a próxima revisão da Apple. Ele exige que `somatotipo` bata EXATAMENTE com
 * um destes três (`Somatotype.init(rawValue:)`, case-sensitive). Qualquer outra
 * coisa — inclusive `null` — derruba a análise inteira na tela da pessoa.
 *
 * Por isso a lista canônica passa a ser responsabilidade do SERVIDOR: é o único
 * lado que consegue consertar quem já instalou. Mexer aqui é mexer no contrato
 * com um app que não dá para atualizar hoje — leia `AIBodyScan.swift:18-20`
 * antes de tocar.
 */
const SOMATOTIPOS = ['Ectomorfo', 'Mesomorfo', 'Endomorfo'] as const;
type Somatotipo = (typeof SOMATOTIPOS)[number];

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
      // [2026-08-12] ERA `type: ['string','null']`, texto livre. Foi a causa do
      // incidente: o esquema PERMITIA `null` e a instrução NUNCA pedia o campo,
      // então o modelo devolvia `null` de forma determinística — três tentativas
      // seguidas, três falhas idênticas. `enum` aqui não é decoração: com
      // `strict: true` a API restringe a decodificação, e o modelo fica sem
      // como emitir outra coisa. Anulável de novo = incidente de novo.
      //
      // Nota sobre `legivel: false`: o campo continua obrigatório, então o
      // modelo preenche algum valor mesmo quando não deu para ler a foto. É
      // inofensivo — o caminho de recusa devolve `ok:false` e NUNCA envia o
      // resultado ao app (ver o curto-circuito de `legivel !== true` abaixo).
      somatotipo: { type: 'string', enum: SOMATOTIPOS },
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

Quando der para analisar, preencha TODOS os campos abaixo:

- "resumo": descreva a composição corporal aparente de forma sóbria, em 2 a 3 frases.
- "gorduraEstimada": o percentual de gordura como estimativa aproximada (valor central da faixa).
- "somatotipo": EXATAMENTE uma destas três palavras — "Ectomorfo", "Mesomorfo" ou "Endomorfo".
  Este é um rótulo de estrutura corporal predominante, não um diagnóstico. Somatotipo é um
  espectro e quase ninguém é um tipo puro: escolha o PREDOMINANTE do que você observa.
  Não escreva combinações ("meso-endomorfo"), não escreva em minúsculas, não deixe em branco.
  Dúvida entre dois tipos NÃO é motivo para recusar a análise: escolha o mais próximo e siga.
  legivel=false é sobre a FOTO não dar para analisar — nunca sobre incerteza neste rótulo.
- "observacoes": 2 a 4 observações descritivas.
- "focos": 2 a 3 áreas em que a pessoa pode focar o treino — sem prescrever séries, cargas ou dietas.
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

/**
 * Descobre o formato REAL da imagem pelos bytes, não pelo que alguém disse.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * [2026-08-12] Até hoje esta função montava `data:image/jpeg;base64,` para
 * TODA foto, sem olhar um byte. O app 2.0.1 manda a foto da galeria no formato
 * original, e no iPhone isso costuma ser HEIC — ou seja, o rótulo mentia.
 *
 * Não foi a causa do incidente de 12/08 (o provedor leu a imagem e devolveu
 * gordura, então ele aceitou o que chegou), mas rótulo que mente é dívida que
 * cobra juros: no dia em que o provedor passar a confiar no rótulo em vez de
 * farejar os bytes, o recurso quebra sem ninguém entender por quê.
 *
 * Os formatos que a OpenAI aceita são PNG, JPEG, WEBP e GIF não-animado. HEIC
 * não está na lista.
 * ═══════════════════════════════════════════════════════════════════════════
 */
export function detectarFormato(b64: string): 'jpeg' | 'png' | 'webp' | 'gif' | 'heic' | null {
  let cab: Buffer;
  try {
    cab = Buffer.from(b64.slice(0, 64), 'base64');   // ~48 bytes bastam
  } catch { return null; }
  if (cab.length < 12) return null;

  if (cab[0] === 0xFF && cab[1] === 0xD8 && cab[2] === 0xFF) return 'jpeg';
  if (cab.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4E, 0x47,
                                             0x0D, 0x0A, 0x1A, 0x0A]))) return 'png';
  if (cab.subarray(0, 4).toString('ascii') === 'RIFF' &&
      cab.subarray(8, 12).toString('ascii') === 'WEBP') return 'webp';
  if (cab.subarray(0, 3).toString('ascii') === 'GIF') return 'gif';
  // HEIC/HEIF: caixa `ftyp` no offset 4, marca no offset 8.
  if (cab.subarray(4, 8).toString('ascii') === 'ftyp') {
    const marca = cab.subarray(8, 12).toString('ascii');
    if (['heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1'].includes(marca)) return 'heic';
  }
  return null;
}

/**
 * Traz o somatotipo para a grafia que o app sabe ler, ou devolve `null`.
 *
 * CINTO E SUSPENSÓRIO, de propósito. O `enum` do esquema já deveria tornar esta
 * função inalcançável — ela existe para o dia em que não tornar: troca de modelo,
 * degradação do modo estrito, alguém afrouxando o esquema sem ler o comentário.
 * Custa microssegundos e evita repetir o incidente de 12/08.
 *
 * O que ela aceita: caixa diferente ("mesomorfo"), espaço sobrando, acento
 * ("endomórfico"), e composto — onde vale o PRIMEIRO tipo citado.
 *
 * Aviso honesto sobre o composto: "primeiro vence" é uma REGRA ARBITRÁRIA que
 * escolhemos, não a convenção do campo — em somatotipia clássica o dominante
 * costuma ser o SEGUNDO termo ("endo-mesomorfo" = mesomorfo com traços endo).
 * Fica assim de propósito: com o `enum` fechado no esquema, composto não deve
 * mais chegar aqui, e uma regra simples e previsível vale mais que uma regra
 * sofisticada e rara. Se um dia composto voltar a ser comum, esta é a linha a
 * revisitar — e o normalizador do Swift precisa mudar junto.
 *
 * O que ela NÃO faz: inventar. Sem nada reconhecível, devolve `null` e quem
 * chama decide — nunca chuta um tipo, porque chutar é exatamente o B8.
 */
export function normalizarSomatotipo(bruto: unknown): Somatotipo | null {
  if (typeof bruto !== 'string') return null;
  const limpo = bruto
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')  // tira acento (marcas combinantes)
    .toLowerCase();
  // Primeiro radical que aparecer no texto vence — cobre "meso-endomorfo",
  // "tipo mesomórfico", "Mesomorfo (predominante)".
  let melhor: { tipo: Somatotipo; posicao: number } | null = null;
  for (const tipo of SOMATOTIPOS) {
    const radical = tipo.slice(0, 4).toLowerCase();   // ecto | meso | endo
    const posicao = limpo.indexOf(radical);
    if (posicao >= 0 && (melhor === null || posicao < melhor.posicao)) {
      melhor = { tipo, posicao };
    }
  }
  return melhor?.tipo ?? null;
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

    const fotos: Array<{ b64: string; mime: string }> = [];
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
      // ── Rótulo MIME pelos BYTES, não por suposição ─────────────────────────
      // HEIC segue passando com rótulo `jpeg`, e isso é uma escolha registrada,
      // não descuido: o app 2.0.1 na loja manda a foto da galeria crua, esse
      // caminho comprovadamente funciona hoje (a chamada de 12/08 voltou com
      // gordura estimada), e recusar aqui quebraria em produção um recurso que
      // está de pé. A 2.0.2 reencoda tudo para JPEG no aparelho
      // (`AnaliseDeFotoService.jpegParaEnvio`) e essa exceção morre sozinha.
      // Enquanto isso, o log conta quantas ainda chegam assim.
      const formato = detectarFormato(b64);
      if (formato === 'heic' || formato === null) {
        console.warn('[analisarFoto] foto sem formato aceito pelo provedor', {
          tipo: body.tipo, formato: formato ?? 'desconhecido',
        });
      }
      const mime = formato && formato !== 'heic' ? formato : 'jpeg';
      fotos.push({ b64, mime });
    }

    // ── Limite diário (scan é caro) ────────────────────────────────────────
    const db = admin.firestore();
    const hoje = new Date().toISOString().slice(0, 10);
    const contadorRef = db.doc(`rate_limits/${uid}`);
    // Só se DEBITOU de fato é que existe algo a devolver depois. Sem esta
    // bandeira, uma falha do contador (que é tolerada, não fatal) seguida de uma
    // falha da IA faria `devolverScan` decrementar um crédito que nunca foi
    // cobrado — roubando o scan de um sucesso anterior do mesmo dia.
    let cobrado = false;
    try {
      await db.runTransaction(async (tx) => {
        const d = (await tx.get(contadorRef)).data() ?? {};
        const usados = d.scanDia === hoje ? ((d.scanCount as number) ?? 0) : 0;
        if (usados >= SCANS_POR_DIA) throw new Error('LIMITE');
        tx.set(contadorRef, { scanDia: hoje, scanCount: usados + 1 }, { merge: true });
      });
      cobrado = true;
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
              ...fotos.map((f) => ({
                type: 'image_url' as const,
                image_url: { url: `data:image/${f.mime};base64,${f.b64}`,
                             detail: 'high' as const },
              })),
            ],
          },
        ],
      });
      bruto = resposta.choices[0]?.message?.content ?? '';
    } catch (e) {
      // Recusa do provedor, timeout, cota — tudo cai aqui e vira texto honesto.
      console.error('[analisarFoto] provedor falhou:', (e as Error).message);
      if (cobrado) await devolverScan(db, uid, hoje);
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
      console.error('[analisarFoto] resposta não é JSON', { tipo, bytes: bruto.length });
      if (cobrado) await devolverScan(db, uid, hoje);
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

    // ═══════════════════════════════════════════════════════════════════════
    // [2026-08-12] O SERVIDOR PASSA A HONRAR O CONTRATO QUE O APP ESPERA.
    //
    // Incidente: o app 2.0.1 exige `somatotipo` numa das três grafias exatas e
    // `resumo` não-vazio. Quando não vinham, ele descartava a análise INTEIRA —
    // gordura, observações e focos junto — e mostrava "voltou incompleta".
    // O `enum` do esquema acima resolve na origem; isto aqui é a rede embaixo,
    // e é o que transforma a falha silenciosa em número que dá para contar.
    //
    // A regra que não muda: nada é INVENTADO. Se o rótulo não vier legível, ele
    // vai embora e o app mostra a análise sem ele — o que exige o app novo. Para
    // o app 2.0.1, que não sabe fazer isso, a única saída honesta continua sendo
    // a recusa; a diferença é que agora ela é rara, medida e nomeada.
    // ═══════════════════════════════════════════════════════════════════════
    const faltando: string[] = [];

    // SÓ PARA CORPO. `somatotipo` e `resumo` não existem no esquema de comida —
    // validá-los ali reprovaria toda foto de prato, que foi o que esta função
    // quase passou a fazer na primeira versão deste conserto.
    if (tipo === 'corpo') {
      // ── O que SUSTENTA a leitura: sem resumo não houve análise ───────────
      const resumo = typeof dados.resumo === 'string' ? dados.resumo.trim() : '';
      if (resumo.length === 0) {
        console.error('[analisarFoto] resposta sem resumo', {
          tipo, temGordura: typeof dados.gorduraEstimada === 'number',
        });
        if (cobrado) await devolverScan(db, uid, hoje);
        await recibo(db, uid, tipo, false, 'resposta_incompleta', ['resumo']);
        res.status(502).json({
          ok: false, motivo: 'resposta_incompleta',
          mensagem: 'A análise voltou incompleta. Tente de novo.',
        });
        return;
      }
      dados.resumo = resumo;

      // ── O que só DESCREVE a leitura: o rótulo não derruba nada ───────────
      // Esta é a lição central do incidente. Recusar aqui manteria o defeito de
      // pé com outro CEP: a análise existe — gordura, resumo, observações e
      // focos — e jogá-la fora por causa de uma palavra é o erro que custou
      // quatro tentativas ao Assis em 12/08.
      //
      // Então o rótulo ausente ATRAVESSA como `null`:
      //   • app 96+ omite a linha e mostra a análise (ver `ScanResultView`);
      //   • app 2.0.1 recusa, exatamente como já recusava hoje — nunca pior.
      // O recibo carimba `camposFaltando` para isso virar número em vez de
      // sumir, que era a cegueira de origem.
      const somatotipo = normalizarSomatotipo(dados.somatotipo);
      if (somatotipo === null) {
        faltando.push('somatotipo');
        // Nada de texto livre no log: quando o valor NÃO é um dos três rótulos,
        // ele é frase do modelo derivada da foto do corpo. Tipo e tamanho bastam
        // para diagnosticar e não carregam conteúdo sobre a pessoa.
        console.error('[analisarFoto] rótulo ausente ou irreconhecível', {
          tipo,
          somatotipoTipo: typeof dados.somatotipo,
          somatotipoTamanho: typeof dados.somatotipo === 'string'
            ? dados.somatotipo.length : 0,
        });
      } else if (dados.somatotipo !== somatotipo) {
        console.warn('[analisarFoto] somatotipo normalizado para a grafia canônica',
                     { tipo, para: somatotipo });
      }
      // Devolve a grafia canônica (ou `null`), nunca a que o modelo escreveu.
      dados.somatotipo = somatotipo;
    }

    await recibo(db, uid, tipo, true, null, faltando.length > 0 ? faltando : undefined);

    // As fotos (`fotos`, `brutas`, `body`) saem de escopo aqui e não foram
    // gravadas em lugar nenhum. É a promessa da tela, cumprida no código.
    res.status(200).json({ ok: true, tipo, modelo: MODELO_VISAO, resultado: dados });
  },
);

/**
 * Devolve o scan que foi debitado antes da chamada.
 *
 * O contador incrementa ANTES de falar com a IA, de propósito: é o que impede
 * alguém de disparar 500 chamadas caras em paralelo. O efeito colateral apareceu
 * em 12/08 — quatro tentativas frustradas queimaram quatro dos 30 scans do dia
 * do Assis, e ele não recebeu análise nenhuma em troca.
 *
 * Cobrar por trabalho não entregue é errado, então a falha que NÃO é culpa da
 * pessoa devolve o crédito. Falha que é decisão legítima da IA (`foto_ilegivel`)
 * continua contando: ali houve chamada, houve custo, e houve resposta útil.
 */
async function devolverScan(
  db: admin.firestore.Firestore, uid: string, dia: string,
) {
  try {
    await db.runTransaction(async (tx) => {
      const ref = db.doc(`rate_limits/${uid}`);
      const d = (await tx.get(ref)).data() ?? {};
      if (d.scanDia !== dia) return;                 // já virou o dia: nada a devolver
      const usados = (d.scanCount as number) ?? 0;
      if (usados <= 0) return;
      tx.set(ref, { scanDia: dia, scanCount: usados - 1 }, { merge: true });
    });
  } catch (e) {
    console.warn('[analisarFoto] devolução do scan falhou (não fatal):',
                 (e as Error).message);
  }
}

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
  camposFaltando?: string[],
) {
  try {
    await db.collection(`users/${uid}/scans`).add({
      tipo, ok, motivo: motivo ?? null,
      // [2026-08-12] NOMES de campo, para a pergunta "com que frequência isso
      // acontece, e por qual campo" ter resposta. Em 12/08 não tinha: a falha
      // morava no cliente, DEPOIS do 200, e o recibo a registrava como sucesso.
      camposFaltando: camposFaltando ?? null,
      modelo: MODELO_VISAO,
      quando: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.warn('[analisarFoto] recibo falhou (não fatal):', (e as Error).message);
  }
}
