#!/usr/bin/env node
// ═══════════════════════════════════════════════════════════════════════════
// regras_sincronizar.mjs — fonte única para firestore.rules
//
// Existiam QUATRO cópias divergentes de firestore.rules no disco, e a do
// Android abria com "ARQUIVO CANÔNICO ÚNICO... mantenha os DOIS idênticos".
// O comentário não impediu a divergência porque comentário não é mecanismo.
//
// Aqui a cópia do Android passa a ser GERADA a partir da canônica, com um
// cabeçalho que diz para não editar, e a verificação está pendurada no
// `predeploy` do firebase.json — se divergirem, o DEPLOY ABORTA. Ninguém
// precisa lembrar de rodar nada: o caminho de publicação é que falha.
//
// Uso:
//   node _scripts/regras_sincronizar.mjs --check    # sai != 0 se divergir
//   node _scripts/regras_sincronizar.mjs --write    # regenera a cópia
//
// A comparação é sobre o CORPO das regras (tudo a partir de `rules_version`),
// não sobre o cabeçalho — o cabeçalho da cópia é, por construção, diferente.
// ═══════════════════════════════════════════════════════════════════════════

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const AQUI = dirname(fileURLToPath(import.meta.url));
const RAIZ = resolve(AQUI, '..');

const CANONICA = resolve(RAIZ, 'firestore.rules');

// A cópia vive noutro repositório, ao lado deste. Caminho relativo de propósito:
// funciona no Mac do Assis e em sandbox, sem caminho absoluto embutido.
const COPIA = resolve(RAIZ, '..', 'alma-android', 'firestore.rules');

const CABECALHO_COPIA = `// ═══════════════════════════════════════════════════════════════════════════
// ⚠️  ARQUIVO GERADO — NÃO EDITE ESTE ARQUIVO.
//
// Cópia de leitura das regras do projeto alma-app-7dae6, mantida aqui só para
// quem trabalha no repositório Android conseguir ler as regras sem trocar de
// pasta. NÃO é a fonte, e NÃO é publicável: este repositório nem tem
// firebase.json.
//
// FONTE:    alma.app.oficial-main/firestore.rules
// GERADOR:  alma.app.oficial-main/_scripts/regras_sincronizar.mjs
//
// Para mudar uma regra: edite a FONTE e rode, em alma.app.oficial-main/
//     node _scripts/regras_sincronizar.mjs --write
//
// Se editar aqui à mão, o \`predeploy\` do firebase.json aborta o próximo
// deploy de regras até que as duas voltem a bater.
// ═══════════════════════════════════════════════════════════════════════════
`;

/** Corpo = das regras propriamente ditas em diante. Ignora cabeçalho e CRLF. */
function corpo(texto) {
  const i = texto.indexOf('rules_version');
  if (i === -1) return null;
  return texto.slice(i).replace(/\r\n/g, '\n').trimEnd() + '\n';
}

function hash(s) {
  return createHash('sha256').update(s, 'utf8').digest('hex').slice(0, 12);
}

function morrer(msg) {
  console.error(msg);
  process.exit(1);
}

const modo = process.argv[2];
if (modo !== '--check' && modo !== '--write') {
  morrer('uso: regras_sincronizar.mjs --check | --write');
}

if (!existsSync(CANONICA)) {
  morrer(`✗ fonte não encontrada: ${CANONICA}`);
}

const textoCanonico = readFileSync(CANONICA, 'utf8');
const corpoCanonico = corpo(textoCanonico);

if (corpoCanonico === null) {
  morrer(`✗ ${CANONICA} não contém "rules_version" — arquivo corrompido?`);
}

// Guarda-costas barato contra o erro mais caro possível: publicar uma regra que
// libera tudo. Não substitui os testes de emulador, mas custa zero e pega o
// acidente óbvio antes de ele chegar à produção.
const PERIGOS = [
  [/match\s*\/\{[A-Za-z_]+=\*\*\}\s*\{[^}]*allow\s+(read\s*,\s*)?write\s*:\s*if\s+true/s,
   'curinga recursivo com escrita liberada'],
  [/allow\s+read\s*,\s*write\s*:\s*if\s+true\s*;/,
   'allow read, write: if true'],
];
for (const [re, nome] of PERIGOS) {
  if (re.test(corpoCanonico)) {
    morrer(`✗ REGRA PERIGOSA na fonte: ${nome}\n  Recuse-se a publicar isto.`);
  }
}

const saidaEsperada = CABECALHO_COPIA + corpoCanonico;

if (modo === '--write') {
  writeFileSync(COPIA, saidaEsperada, 'utf8');
  console.log(`✓ cópia regenerada: ${COPIA}`);
  console.log(`  corpo sha256[0:12] = ${hash(corpoCanonico)}`);
  process.exit(0);
}

// ── --check ────────────────────────────────────────────────────────────────
if (!existsSync(COPIA)) {
  morrer(
    `✗ DIVERGÊNCIA: a cópia do Android não existe.\n` +
    `  esperada em: ${COPIA}\n` +
    `  conserto:    node _scripts/regras_sincronizar.mjs --write`,
  );
}

const corpoCopia = corpo(readFileSync(COPIA, 'utf8'));

if (corpoCopia !== corpoCanonico) {
  const linhasA = corpoCanonico.split('\n');
  const linhasB = (corpoCopia ?? '').split('\n');
  let primeira = -1;
  for (let i = 0; i < Math.max(linhasA.length, linhasB.length); i++) {
    if (linhasA[i] !== linhasB[i]) { primeira = i; break; }
  }
  morrer(
    `\n✗✗ DIVERGÊNCIA ENTRE AS REGRAS — DEPLOY ABORTADO ✗✗\n\n` +
    `  fonte : ${CANONICA}\n` +
    `          sha256[0:12] = ${hash(corpoCanonico)}  (${linhasA.length} linhas)\n` +
    `  cópia : ${COPIA}\n` +
    `          sha256[0:12] = ${hash(corpoCopia ?? '')}  (${linhasB.length} linhas)\n\n` +
    `  primeira linha diferente: ${primeira + 1}\n` +
    `    fonte: ${JSON.stringify(linhasA[primeira] ?? '<fim do arquivo>')}\n` +
    `    cópia: ${JSON.stringify(linhasB[primeira] ?? '<fim do arquivo>')}\n\n` +
    `  A cópia do Android é GERADA. Se a mudança é legítima, edite a FONTE e rode:\n` +
    `    node _scripts/regras_sincronizar.mjs --write\n`,
  );
}

console.log(`✓ regras sincronizadas — corpo sha256[0:12] = ${hash(corpoCanonico)}`);
