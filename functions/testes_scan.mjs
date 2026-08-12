/**
 * As funções puras do scan por foto, exercitadas contra o JS QUE VAI PARA
 * PRODUÇÃO (`lib/`), não contra uma reimplementação.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * POR QUE ESTE ARQUIVO EXISTE — incidente de 12/08/2026
 *
 * O scan corporal quebrou em produção com "A análise da foto voltou incompleta".
 * Causa: o esquema permitia `somatotipo: null` e a instrução nunca pedia o
 * campo, então o modelo devolvia `null` SEMPRE — três tentativas do Assis, três
 * falhas idênticas — e o app descartava a análise inteira (gordura, resumo,
 * observações, focos) por causa de uma palavra que faltava.
 *
 * Nada no projeto exercitava essas funções. O `provar_scan_ponta_a_ponta.sh`
 * chama a função de verdade, o que é ótimo e caro: gasta cota, precisa de foto
 * real e não roda no CI. Estas asserções são o outro lado — rápidas, sem rede,
 * sem cota — e prendem exatamente o que quebrou.
 *
 * Como rodar:
 *   cd functions && npm run build && node testes_scan.mjs
 *
 * CANÁRIO: o último bloco planta dois casos que TÊM de reprovar. Se passarem,
 * este arquivo está cego e o resultado inteiro é descartado — em voz alta.
 * Guarda anti-cegueira, no padrão do A26d.
 * ═══════════════════════════════════════════════════════════════════════════
 */
import {
  normalizarSomatotipo, detectarFormato, extrairBase64, bytesDoBase64,
} from './lib/analiseDeFoto.js';

let ok = 0;
const falhas = [];

function eq(id, obtido, esperado, desc) {
  if (obtido === esperado) { ok++; console.log(`  ✓ ${id} ${desc}`); return true; }
  falhas.push(`${id} ${desc} — esperava ${JSON.stringify(esperado)}, veio ${JSON.stringify(obtido)}`);
  console.log(`  ✗ ${id} ${desc} — esperava ${JSON.stringify(esperado)}, veio ${JSON.stringify(obtido)}`);
  return false;
}

/** Cabeçalho de arquivo + zeros, o bastante para o detector de formato. */
const comBytes = (arr) =>
  Buffer.concat([Buffer.from(arr), Buffer.alloc(512)]).toString('base64');

console.log('\n═════ S1 · o rótulo que quebrou a produção ═════');
// A grafia canônica tem de sobreviver intacta: é ela que o app 2.0.1, imutável
// na loja, compara byte a byte com `Somatotype.init(rawValue:)`.
eq('S1a', normalizarSomatotipo('Ectomorfo'), 'Ectomorfo', 'grafia canônica passa intacta');
eq('S1b', normalizarSomatotipo('Mesomorfo'), 'Mesomorfo', 'grafia canônica passa intacta');
eq('S1c', normalizarSomatotipo('Endomorfo'), 'Endomorfo', 'grafia canônica passa intacta');

console.log('\n═════ S2 · variações que o modelo pode escrever ═════');
eq('S2a', normalizarSomatotipo('mesomorfo'), 'Mesomorfo', 'minúscula');
eq('S2b', normalizarSomatotipo('MESOMORFO'), 'Mesomorfo', 'maiúscula');
eq('S2c', normalizarSomatotipo('  Endomorfo  '), 'Endomorfo', 'espaço sobrando');
eq('S2d', normalizarSomatotipo('Ectomórfico'), 'Ectomorfo', 'acento e sufixo');
// S2g existe por causa de um FURO achado por mutação em 12/08. A mutação
// "tirar o `.replace(/[̀-ͯ]/g,'')`" passava VERDE, e o motivo era
// constrangedor: nenhum caso de teste tinha acento DENTRO do radical de 4
// letras que a função procura (ecto/meso/endo). "Ectomórfico" tem o acento na
// 6ª letra — a dobra de acento nunca era exercitada, e o teste dava cobertura
// imaginária a uma linha de produção. Este caso põe o acento onde dói.
eq('S2g', normalizarSomatotipo('Éctomorfo'), 'Ectomorfo', 'acento DENTRO do radical');
eq('S2e', normalizarSomatotipo('meso-endomorfo'), 'Mesomorfo', 'composto → primeiro citado');
eq('S2f', normalizarSomatotipo('tipo mesomórfico predominante'), 'Mesomorfo', 'frase inteira');

console.log('\n═════ S3 · NÃO INVENTAR (o coração do B8) ═════');
// Estas seis são as mais importantes do arquivo. Um normalizador que devolvesse
// um tipo aqui estaria fabricando leitura de foto a partir do nada — o bug B8.
eq('S3a', normalizarSomatotipo(null), null, 'null não vira tipo');
eq('S3b', normalizarSomatotipo(undefined), null, 'undefined não vira tipo');
eq('S3c', normalizarSomatotipo(''), null, 'vazio não vira tipo');
eq('S3d', normalizarSomatotipo('banana'), null, 'texto qualquer não vira tipo');
eq('S3e', normalizarSomatotipo(42), null, 'número não vira tipo');
eq('S3f', normalizarSomatotipo({ tipo: 'Mesomorfo' }), null, 'objeto não vira tipo');

console.log('\n═════ S4 · o MIME sai dos BYTES, não de suposição ═════');
eq('S4a', detectarFormato(comBytes([0xFF, 0xD8, 0xFF, 0xE0])), 'jpeg', 'JPEG');
eq('S4b', detectarFormato(comBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])), 'png', 'PNG');
eq('S4c', detectarFormato(comBytes([0x52, 0x49, 0x46, 0x46, 0x24, 0, 0, 0, 0x57, 0x45, 0x42, 0x50])), 'webp', 'WEBP');
eq('S4d', detectarFormato(comBytes([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])), 'gif', 'GIF');
// HEIC é o que o app 2.0.1 manda da galeria e o provedor NÃO aceita na lista.
eq('S4e', detectarFormato(comBytes([0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63])), 'heic', 'HEIC reconhecido como HEIC');
eq('S4f', detectarFormato(comBytes([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])), null, 'lixo não vira formato');

console.log('\n═════ S5 · entrada da foto ═════');
const jpeg = comBytes([0xFF, 0xD8, 0xFF, 0xE0]);
eq('S5a', extrairBase64(`data:image/jpeg;base64,${jpeg}`), jpeg, 'data URL → base64 puro');
eq('S5b', extrairBase64(jpeg), jpeg, 'base64 puro passa');
eq('S5c', extrairBase64('nao é base64!!'), null, 'lixo é recusado');
eq('S5d', extrairBase64(''), null, 'vazio é recusado');
eq('S5e', bytesDoBase64(Buffer.alloc(3000).toString('base64')), 3000, 'bytes reais, não tamanho do base64');

// ═══════════════════════════════════════════════════════════════════════════
// CANÁRIO — dois casos que TÊM de reprovar.
//
// Um arquivo de teste que não consegue reprovar nada aprova tudo para sempre.
// É o "verde cego" que a lição de 05/08 chama de pior que vermelho. Se qualquer
// um destes dois passar, o resultado acima não vale nada e o processo sai != 0.
// ═══════════════════════════════════════════════════════════════════════════
console.log('\n═════ CANÁRIO · estes DOIS têm de reprovar ═════');
const canario = [];
if (normalizarSomatotipo('banana') === 'Mesomorfo') canario.push('normalizador inventou tipo de "banana"');
if (detectarFormato(comBytes([1, 2, 3, 4])) === 'jpeg') canario.push('detector chamou lixo de JPEG');
const antes = falhas.length;
eq('CAN-1', normalizarSomatotipo('banana'), 'Mesomorfo', '(DEVE REPROVAR) chute a partir de lixo');
eq('CAN-2', detectarFormato(comBytes([1, 2, 3, 4])), 'jpeg', '(DEVE REPROVAR) lixo virando JPEG');
const canarioReprovou = falhas.length === antes + 2;
falhas.length = antes;                       // as duas do canário não contam como falha real
ok -= 0;

console.log('\n═════ RESULTADO ═════');
console.log(`asserções: ${ok} · falhas: ${falhas.length}`);
for (const f of falhas) console.log(`   ✗ ${f}`);

if (!canarioReprovou) {
  console.error('\n✗✗ CANÁRIO PASSOU — este arquivo está CEGO. Resultado descartado.');
  process.exit(2);
}
console.log('canário reprovou as duas, como deve: o arquivo enxerga. ✓');

console.log('\n═════ O QUE ESTE ARQUIVO **NÃO** PROVA — cegueira declarada ═════');
console.log('  · Não chama a OpenAI. Não prova que o `enum` do json_schema é');
console.log('    obedecido pelo provedor — isso só o caminho real prova');
console.log('    (_scripts/provar_scan_ponta_a_ponta.sh, que gasta cota).');
console.log('  · Não prova o fluxo HTTP da função (auth, rate limit, recibo):');
console.log('    exigiria emulador, como o roda_testes_ciclo.sh faz.');
console.log('  · Não prova NADA do lado Swift. O cliente tem lint + mutação');
console.log('    (H-W4/H-W4b/H-W4c) e nenhum teste de tela — o projeto não tem');
console.log('    XCUITest, dívida declarada no CLAUDE.md.');

process.exit(falhas.length === 0 ? 0 : 1);
