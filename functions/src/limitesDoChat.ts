/**
 * As guardas de custo do chat, num módulo próprio.
 *
 * [2026-08-18] Mesmo motivo que tirou o `ehAssinante` do `index.ts` em 06/08:
 * importar `index.ts` num teste dispara `admin.initializeApp()`, o registro de
 * todas as functions e a resolução de secrets. Regra que decide dinheiro e não
 * pode ser exercitada é papel pintado — o `CLAUDE.md` proíbe.
 *
 * Aqui a mesma função é importada pelo `index.ts` E por `testes_brechas.mjs`.
 */

/**
 * Assinante: guardas anti-abuso. Sobrescrevíveis por `config/limites`.
 *
 * [2026-08-18] `mensalMax` baixou de 3.000 para 2.500. Ver a conta de folga em
 * `MENSAL_MAX_ABSOLUTO`, logo abaixo.
 *
 * ⚠️ 2.500 É PREMISSA, NÃO MEDIÇÃO. O projeto não tem nenhum máximo de uso por
 * usuário observado: o único número real registrado é 33 requisições ao `chat`
 * em 2 dias (02/08), agregado de TODA a base, sem quebra por pessoa — e a base
 * tem um assinante. Para dar escala: 2.500/mês são ~83 mensagens por dia de uma
 * ÚNICA pessoa, cinco vezes o volume diário da base inteira, sustentado por 30
 * dias. É por isso que se acredita que ninguém real encosta; não porque alguém
 * mediu.
 *
 * O dado vai existir: a partir deste deploy, `mesCount` passa a ser gravado
 * para todo assinante em `rate_limits/{uid}`. Em ~30 dias dá para trocar esta
 * premissa por um máximo observado. Se o p99 real vier bem abaixo, dá para
 * apertar mais; se vier perto, este número estava errado e a conta muda.
 */
export const LIMITES_ASSINANTE_PADRAO = {
  rajadaMax: 60,
  rajadaJanelaMs: 300_000,      // 5 min
  diarioMax: 300,
  mensalMax: 2_500,
};

/**
 * Teto ABSOLUTO de mensagens/mês — o `config/limites` não pode passar daqui.
 *
 * ⚠️ ESTA CONTA JÁ ESTAVA ERRADA UMA VEZ. A primeira versão de 18/08 usava
 * 3.800, porque somava só os scans e ESQUECIA o orçamento do TTS — que foi
 * criado na mesma sessão, algumas horas antes. Refeita com todos os caminhos
 * pagos na mesa:
 *
 *   receita líquida por assinante ....... US$ 8,16   (R$ 42,42 ÷ 5,2005)
 *   − teto dos scans no pior caso ....... US$ 2,54   (5 comida/dia + 3 corpo/semana,
 *                                                     2 fotos e saída no máximo)
 *   − orçamento mensal do TTS ........... US$ 0,60   (40.000 caracteres)
 *   = sobra para o chat ................. US$ 5,02
 *   ÷ custo da mensagem mais cara ....... US$ 0,001525  (4.000 chars + histórico cheio)
 *   = 3.291 mensagens
 *
 * Fixado em 3.000 — abaixo do limite matemático, para o teto não ficar colado
 * na linha de prejuízo como ficou antes. Com o padrão em 2.500, o pior caso
 * fecha em US$ 7,06 (R$ 36,70) contra R$ 42,42 de receita: R$ 5,72 de folga,
 * contra R$ 1,64 que sobravam com o padrão em 3.000.
 *
 * Acima de 3.000 o teto do servidor volta a permitir um assinante que dá
 * PREJUÍZO — que é exatamente o que estas guardas existem para impedir. Se a
 * receita líquida, o câmbio ou o preço do modelo mudarem, refazer a conta AQUI
 * em vez de subir o número no Firestore. E somar TODOS os caminhos pagos:
 * chat + resumo de memória + scan + TTS.
 */
export const MENSAL_MAX_ABSOLUTO = 3_000;
export const DIARIO_MAX_ABSOLUTO = 1_000;
export const RAJADA_MAX_ABSOLUTO = 200;
export const JANELA_MS_ABSOLUTA = 3_600_000;   // no máximo 1 hora de janela

/**
 * Lê `config/limites` com FAIXA VALIDADA.
 *
 * Antes isto era um spread cru, dentro do `index.ts`:
 *     `{ ...LIMITES_ASSINANTE_PADRAO, ...(d.data() ?? {}) }`
 * Três problemas, todos silenciosos:
 *   1. um zero a mais digitado no console apagava o teto de custo;
 *   2. `mensalMax: "3000"` (string) ou `null` passavam e quebravam a comparação
 *      `doMes >= cfg.mensalMax` — que com string vira `false` para sempre, e o
 *      teto some sem erro nenhum no log;
 *   3. chaves desconhecidas entravam no objeto sem ninguém notar.
 *
 * Agora cada campo é lido individualmente, exigido número finito, e preso entre
 * 1 e o seu teto absoluto. O piso é 1 e não 0 de propósito: `mensalMax: 0`
 * trancaria TODO assinante fora do chat na hora, que é um jeito criativo de
 * derrubar o produto inteiro com uma digitação.
 *
 * Valor inválido ou fora de faixa NÃO derruba o serviço: cai no padrão daquele
 * campo e grita no log. Falhar para o lado seguro.
 */
export function limitesSeguros(bruto: unknown): typeof LIMITES_ASSINANTE_PADRAO {
  const d = (typeof bruto === 'object' && bruto !== null ? bruto : {}) as Record<string, unknown>;

  const campo = (nome: keyof typeof LIMITES_ASSINANTE_PADRAO, teto: number): number => {
    const padrao = LIMITES_ASSINANTE_PADRAO[nome];
    const v = d[nome];
    if (v === undefined) return padrao;
    if (typeof v !== 'number' || !Number.isFinite(v)) {
      console.warn(`[limites] config/limites.${nome} não é número finito; usando o padrão ${padrao}`);
      return padrao;
    }
    const preso = Math.min(Math.max(Math.floor(v), 1), teto);
    if (preso !== v) {
      console.warn(`[limites] config/limites.${nome}=${v} fora da faixa [1, ${teto}]; usando ${preso}`);
    }
    return preso;
  };

  return {
    rajadaMax:      campo('rajadaMax', RAJADA_MAX_ABSOLUTO),
    rajadaJanelaMs: campo('rajadaJanelaMs', JANELA_MS_ABSOLUTA),
    diarioMax:      campo('diarioMax', DIARIO_MAX_ABSOLUTO),
    mensalMax:      campo('mensalMax', MENSAL_MAX_ABSOLUTO),
  };
}
