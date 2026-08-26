/**
 * Extrai MECANICAMENTE o prompt "antes" da versão COMMITADA de
 * `functions/src/index.ts` (git show HEAD), para que a medição de baseline
 * não dependa de eu ter transcrito o prompt à mão.
 *
 * Por que HEAD e não a árvore: `git status --porcelain functions/` mostra
 * apenas arquivos `??` (não rastreados) — `functions/src/index.ts` está limpo,
 * então HEAD == árvore no momento em que este arquivo foi escrito. Medir de
 * HEAD garante que o "antes" continue reproduzível DEPOIS de eu editar.
 */
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const RAIZ = new URL('../..', import.meta.url).pathname;

export function fonteDeHead() {
  return execFileSync('git', ['show', 'HEAD:functions/src/index.ts'], {
    cwd: RAIZ,
    encoding: 'utf8',
    maxBuffer: 32 * 1024 * 1024,
  });
}

/** O `index.ts` como está na árvore — o "depois". */
export function fonteDaArvore() {
  return readFileSync(`${RAIZ}/functions/src/index.ts`, 'utf8');
}

/**
 * Avalia a literal `ALMA_SOUL_PROMPT` de uma fonte qualquer, ligando os nomes
 * que ela interpola. Serve para o "antes" (de HEAD) e para o "depois" (da
 * árvore) sem que eu transcreva prompt nenhum à mão nas duas pontas.
 */
export function montarSystemPrompt(src, vars) {
  const guardrails = extrairLiteral(src, 'HEALTH_CONTEXT_GUARDRAILS');
  const corpo = extrairLiteral(src, 'ALMA_SOUL_PROMPT');
  const todos = { HEALTH_CONTEXT_GUARDRAILS: guardrails, ...vars };
  const nomes = Object.keys(todos);
  const f = new Function(...nomes, 'return `' + corpo + '`;');
  return f(...nomes.map((n) => todos[n]));
}

/**
 * Varre uma template literal a partir do índice da crase de abertura,
 * respeitando aninhamento de `${ ... }` (que pode conter outras crases) e
 * escapes. Devolve o CORPO da literal (sem as crases externas).
 */
export function lerTemplateLiteral(src, idxCrase) {
  if (src[idxCrase] !== '`') throw new Error('não é crase em ' + idxCrase);
  let i = idxCrase + 1;
  let prof = 0;
  const ini = i;
  while (i < src.length) {
    const c = src[i];
    if (c === '\\') { i += 2; continue; }
    if (c === '$' && src[i + 1] === '{') { prof++; i += 2; continue; }
    if (c === '}' && prof > 0) { prof--; i++; continue; }
    if (c === '`' && prof === 0) return { corpo: src.slice(ini, i), fim: i };
    // crases internas a ${...}: consome como parte da expressão
    if (c === '`' && prof > 0) {
      const dentro = lerTemplateLiteral(src, i);
      i = dentro.fim + 1;
      continue;
    }
    i++;
  }
  throw new Error('template literal sem fechamento');
}

export function extrairLiteral(src, nome) {
  const marca = `const ${nome} = \``;
  const p = src.indexOf(marca);
  if (p < 0) throw new Error(`literal ${nome} não encontrada`);
  return lerTemplateLiteral(src, p + marca.length - 1).corpo;
}

/**
 * Extrai o mapa campo→rótulo do leitor de perfil de HEAD, a partir das linhas
 *   if (profile.campo)  parts.push(`Rótulo: ${profile.campo}`);
 * Nada de lista escrita à mão: se o `index.ts` de HEAD mudar, isto muda junto.
 */
export function extrairCamposDoPerfil(src) {
  const re = /if\s*\(profile\.(\w+)\)\s*parts\.push\(`([^:]+):\s*\$\{profile\.\w+\}`\)/g;
  const out = [];
  let m;
  while ((m = re.exec(src)) !== null) out.push({ campo: m[1], rotulo: m[2] });
  if (out.length === 0) throw new Error('nenhum campo de perfil extraído');
  return out;
}

/**
 * Monta o `userProfile` exatamente como HEAD monta.
 */
export function montarUserProfileAntes(src, profile) {
  if (!profile) return '';
  const campos = extrairCamposDoPerfil(src);
  const parts = [];
  for (const { campo, rotulo } of campos) {
    if (profile[campo]) parts.push(`${rotulo}: ${profile[campo]}`);
  }
  return parts.length > 0 ? `[Perfil do usuário]\n${parts.join('\n')}` : '';
}

/**
 * Reconstitui o ALMA_SOUL_PROMPT de HEAD avaliando a literal extraída com as
 * variáveis interpoladas ligadas. `new Function` sobre texto que veio do
 * próprio repositório — não há entrada externa aqui.
 */
export function montarSystemPromptAntes(src, { userProfile, conversationSummary, healthContext, regiao, blocoDeCrise, recursoDeApoio }) {
  const guardrails = extrairLiteral(src, 'HEALTH_CONTEXT_GUARDRAILS');
  const corpo = extrairLiteral(src, 'ALMA_SOUL_PROMPT');
  const f = new Function(
    'userProfile', 'conversationSummary', 'healthContext',
    'HEALTH_CONTEXT_GUARDRAILS', 'blocoDeCrise', 'recursoDeApoio', 'regiao',
    'return `' + corpo + '`;',
  );
  return f(userProfile, conversationSummary, healthContext, guardrails, blocoDeCrise, recursoDeApoio, regiao);
}
