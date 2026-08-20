/**
 * A regra de acesso do GOOGLE, exercitada contra o JS QUE VAI PARA PRODUÇÃO
 * (`lib/`), não contra uma reimplementação.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * POR QUE ESTE ARQUIVO EXISTE — o furo de 13/08/2026
 *
 * `validateAndroidPurchase` só subia o custom claim `isPremium` e nunca o
 * descia, e não havia RTDN. Quem assinava no Android, pedia reembolso e
 * continuava premium PARA SEMPRE — o gate do cliente (`AccessRepository`) lê só
 * esse claim. Com poucos assinantes, cada caso é uma fatia grande da receita.
 *
 * Estas asserções prendem as quatro regras que decidem isso, todas puras:
 *   · `decidirEstadoGoogle`  — o evento vira acesso ou corte;
 *   · `decidirClaim`         — o cadeado do Android volta (ou não);
 *   · `reconcessaoBloqueada` — o reembolsado não recupera acesso na abertura;
 *   · `eventoDeNotificacao`  — o formato do fio vira evento sem se perder.
 *
 * Como rodar:
 *   cd functions && npm run build && node testes_google.mjs
 *
 * CANÁRIO: o último bloco planta três casos que TÊM de reprovar. Se passarem,
 * este arquivo está cego e o resultado inteiro é descartado — em voz alta.
 *
 * O QUE ESTE ARQUIVO NÃO PROVA está declarado no fim, e não é pouco.
 * ═══════════════════════════════════════════════════════════════════════════
 */
import {
  decidirEstadoGoogle,
  decidirClaim,
  reconcessaoBloqueada,
  escritaBloqueadaPorApple,
  TIPO_REEMBOLSO,
  TIPO_TESTE,
  TIPO_VALIDACAO_APP,
} from './lib/googleEstado.js';
import {
  eventoDeNotificacao,
  decodificarEnvelope,
  paraMilissegundos,
} from './lib/googleEvento.js';

let ok = 0;
const falhas = [];

function eq(id, obtido, esperado, desc) {
  if (obtido === esperado) { ok++; console.log(`  ✓ ${id} ${desc}`); return true; }
  falhas.push(`${id} ${desc} — esperava ${JSON.stringify(esperado)}, veio ${JSON.stringify(obtido)}`);
  console.log(`  ✗ ${id} ${desc} — esperava ${JSON.stringify(esperado)}, veio ${JSON.stringify(obtido)}`);
  return false;
}

const DIA = 86_400_000;
const AGORA = Date.parse('2026-08-13T12:00:00Z');
const FUTURO = AGORA + 30 * DIA;
const PASSADO = AGORA - 30 * DIA;
const TOKEN = 'tok_abcdefghijklmnop';

/** Evento de assinatura com os fatos da API já colhidos. */
const ev = (tipo, extra = {}) => ({
  tipo,
  purchaseToken: TOKEN,
  estadoApi: 'SUBSCRIPTION_STATE_ACTIVE',
  expiraEmMs: FUTURO,
  productId: 'alma_premium_monthly',
  ...extra,
});

const base64 = (obj) => Buffer.from(JSON.stringify(obj), 'utf8').toString('base64');

// ═══════════════════════════════════════════════════════════════════════════
console.log('\n═════ G1 · o envelope da Google vira evento ═════');

eq('G1a', paraMilissegundos('1503349566168'), 1503349566168,
   'eventTimeMillis vem como STRING e é convertido');
eq('G1b', paraMilissegundos(1503349566168), 1503349566168, 'número passa');
eq('G1c', paraMilissegundos('ontem'), null, 'lixo não vira data');
eq('G1d', paraMilissegundos(undefined), null, 'ausente não vira data');

eq('G1e', decodificarEnvelope('nao é base64 de json'), null, 'base64 inválido → null, sem lançar');
eq('G1f', decodificarEnvelope(Buffer.from('[1,2]').toString('base64')), null,
   'array não é envelope');
eq('G1g', decodificarEnvelope(base64({ packageName: 'com.almaapp.android' })).packageName,
   'com.almaapp.android', 'envelope válido é decodificado');

const nPurchase = { eventTimeMillis: '1000', subscriptionNotification: { notificationType: 4, purchaseToken: TOKEN } };
eq('G1h', eventoDeNotificacao(nPurchase).tipo, 'SUBSCRIPTION_PURCHASED', 'tipo 4 → PURCHASED');
eq('G1i', eventoDeNotificacao(nPurchase).eventoMs, 1000, 'a data do envelope viaja no evento');

eq('G1j', eventoDeNotificacao({ subscriptionNotification: { notificationType: 12, purchaseToken: TOKEN } }).tipo,
   'SUBSCRIPTION_REVOKED', 'tipo 12 → REVOKED');
eq('G1k', eventoDeNotificacao({ subscriptionNotification: { notificationType: 13, purchaseToken: TOKEN } }).tipo,
   'SUBSCRIPTION_EXPIRED', 'tipo 13 → EXPIRED');
eq('G1l', eventoDeNotificacao({ subscriptionNotification: { notificationType: 3, purchaseToken: TOKEN } }).tipo,
   'SUBSCRIPTION_CANCELED', 'tipo 3 → CANCELED');

// Tipo que a Google inventar depois deste código não pode virar `undefined`
// silencioso: vira rótulo cru, que aparece no Firestore e denuncia o número.
eq('G1m', eventoDeNotificacao({ subscriptionNotification: { notificationType: 99, purchaseToken: TOKEN } }).tipo,
   'SUBSCRIPTION_TIPO_99', 'tipo desconhecido vira rótulo rastreável');

const nVoid = { voidedPurchaseNotification: { purchaseToken: TOKEN, productType: 1, refundType: 1 } };
eq('G1n', eventoDeNotificacao(nVoid).tipo, TIPO_REEMBOLSO, 'voidedPurchase → VOIDED_PURCHASE');
eq('G1o', eventoDeNotificacao({ voidedPurchaseNotification: { purchaseToken: TOKEN, productType: 2 } }),
   null, 'estorno de compra AVULSA não é assunto do premium');
eq('G1p', eventoDeNotificacao({ testNotification: { version: '1.0' } }).tipo, TIPO_TESTE,
   'notificação de teste do Play Console é reconhecida');
eq('G1q', eventoDeNotificacao({ oneTimeProductNotification: { purchaseToken: TOKEN } }), null,
   'compra avulsa não vira evento');
eq('G1r', eventoDeNotificacao({}), null, 'envelope vazio não vira evento');

// ═══════════════════════════════════════════════════════════════════════════
console.log('\n═════ G2 · quem tem acesso ═════');

eq('G2a', decidirEstadoGoogle(ev('SUBSCRIPTION_PURCHASED'), AGORA).active, true,
   'compra ativa com data no futuro → assinante');
eq('G2b', decidirEstadoGoogle(ev('SUBSCRIPTION_RENEWED'), AGORA).active, true, 'renovação → assinante');
eq('G2c', decidirEstadoGoogle(ev(TIPO_VALIDACAO_APP), AGORA).active, true,
   'validação vinda do app concede igual (mesma regra dos dois caminhos)');

// O caso que mais gente erra: cancelar desliga a renovação, não o acesso.
const cancelado = decidirEstadoGoogle(
  ev('SUBSCRIPTION_CANCELED', { estadoApi: 'SUBSCRIPTION_STATE_CANCELED' }), AGORA);
eq('G2d', cancelado.active, true, 'cancelou mas o período pago corre: continua assinante');
eq('G2e', cancelado.motivo.startsWith('renovação desligada'), true, 'e o motivo diz por quê');

eq('G2f', decidirEstadoGoogle(ev('SUBSCRIPTION_EXPIRED'), AGORA).active, false, 'expirou → fora');
eq('G2g', decidirEstadoGoogle(ev('SUBSCRIPTION_ON_HOLD'), AGORA).active, false,
   'account hold → fora (a Google suspendeu o serviço)');
eq('G2h', decidirEstadoGoogle(ev('SUBSCRIPTION_PAUSED'), AGORA).active, false, 'pausada → fora');
eq('G2i', decidirEstadoGoogle(ev('SUBSCRIPTION_PENDING_PURCHASE_CANCELED'), AGORA).active, false,
   'compra pendente cancelada → nunca houve o que conceder');

eq('G2j', decidirEstadoGoogle(ev('SUBSCRIPTION_PURCHASED', { expiraEmMs: PASSADO }), AGORA).active,
   false, 'data no passado não concede, mesmo a API dizendo ACTIVE');
eq('G2k', decidirEstadoGoogle(ev('SUBSCRIPTION_PURCHASED', { expiraEmMs: null }), AGORA).active,
   false, 'sem expiryTime não dá para afirmar acesso');
eq('G2l', decidirEstadoGoogle(ev('SUBSCRIPTION_PURCHASED', { estadoApi: 'SUBSCRIPTION_STATE_EXPIRED' }), AGORA).active,
   false, 'quem manda é a API, não o rótulo da notificação');

eq('G2m', decidirEstadoGoogle(ev('SUBSCRIPTION_TIPO_99'), AGORA).deveGravar, false,
   'tipo desconhecido não inventa acesso NEM tira o de ninguém');
eq('G2n', decidirEstadoGoogle(ev('SUBSCRIPTION_PRICE_CHANGE_CONFIRMED'), AGORA).deveGravar, false,
   'mudança de preço não mexe em acesso');
eq('G2o', decidirEstadoGoogle(ev('SUBSCRIPTION_CANCELLATION_SCHEDULED'), AGORA).deveGravar, false,
   'cancelamento AGENDADO não muda nada hoje');
eq('G2p', decidirEstadoGoogle(ev('SUBSCRIPTION_PURCHASED', { purchaseToken: null }), AGORA).deveGravar,
   false, 'sem purchaseToken não há a quem aplicar');

// ═══════════════════════════════════════════════════════════════════════════
console.log('\n═════ G3 · o corte — a razão desta sessão existir ═════');

const estornado = decidirEstadoGoogle({ tipo: TIPO_REEMBOLSO, purchaseToken: TOKEN, refundType: 1 }, AGORA);
eq('G3a', estornado.active, false, 'reembolso corta o acesso');
eq('G3b', estornado.deveGravar, true, 'e o corte É gravado');
eq('G3c', estornado.cortePrioritario, true,
   'e vence mesmo fora de ordem (senão uma renovação atrasada devolve o acesso)');

const revogado = decidirEstadoGoogle({ tipo: 'SUBSCRIPTION_REVOKED', purchaseToken: TOKEN }, AGORA);
eq('G3d', revogado.active, false, 'revogação corta');
eq('G3e', revogado.cortePrioritario, true, 'revogação também vence fora de ordem');

// O corte NÃO pode depender da API: é o caminho que precisa funcionar com a
// Google fora do ar, e a documentação diz que o voided basta por si.
eq('G3f', decidirEstadoGoogle({ tipo: TIPO_REEMBOLSO, purchaseToken: TOKEN }, AGORA).apiIndisponivel,
   false, 'reembolso decide SEM consultar a Google');

eq('G3g', decidirEstadoGoogle({ tipo: TIPO_REEMBOLSO, purchaseToken: TOKEN, refundType: 2 }, AGORA).deveGravar,
   false, 'estorno parcial por quantidade não derruba assinatura');

// ═══════════════════════════════════════════════════════════════════════════
console.log('\n═════ G4 · a Google calada NÃO é "não é assinante" ═════');
//
// Se um 503 da Google virasse corte, trocaríamos um furo de receita por
// assinante pagante trancado do lado de fora — a pior falha possível do produto,
// nas palavras do próprio alertaEntitlement.ts.

const semApi = decidirEstadoGoogle(ev('SUBSCRIPTION_RENEWED', { estadoApi: null }), AGORA);
eq('G4a', semApi.apiIndisponivel, true, 'sem resposta da API, o evento é marcado como indeciso');
eq('G4b', semApi.deveGravar, false, 'e NADA é gravado — ninguém perde acesso por falha nossa');
eq('G4c', semApi.active, false, 'o estado indeciso nunca concede acesso, só não grava');

// ═══════════════════════════════════════════════════════════════════════════
console.log('\n═════ G5 · o cadeado do Android (custom claim) ═════');

eq('G5a', decidirClaim(true, null), 'subir', 'virou assinante → claim sobe');
eq('G5b', decidirClaim(false, 'google'), 'rebaixar', 'perdeu acesso pela Google → claim DESCE');
eq('G5c', decidirClaim(false, null), 'rebaixar', 'sem origem anterior conhecida → desce');
eq('G5d', decidirClaim(false, 'apple'), 'nao_mexer',
   'evento da Google NÃO derruba o claim de assinante da Apple');
eq('G5e', decidirClaim(true, 'apple'), 'subir', 'conceder é sempre seguro');

// ── e a mesma guarda valendo para o DOCUMENTO, não só para o claim ────────
// Achado da revisão independente de 13/08: proteger só o claim deixava o
// assinante da Apple com o cadeado aberto no app e SEM acesso no servidor,
// porque `ehAssinante` (usado pelo `chat`) lê o `active` do documento.
eq('G5f', escritaBloqueadaPorApple('apple', true, false), true,
   'evento da Google NÃO derruba entitlement ATIVO da Apple');
eq('G5g', escritaBloqueadaPorApple('apple', false, false), false,
   'entitlement da Apple já inativo não é protegido de nada');
eq('G5h', escritaBloqueadaPorApple('apple', true, true), false,
   'conceder por cima é sempre seguro');
eq('G5i', escritaBloqueadaPorApple('google', true, false), false,
   'corte da Google sobre entitlement da Google passa normalmente');
eq('G5j', escritaBloqueadaPorApple(null, false, false), false,
   'documento novo não bloqueia nada');

// ═══════════════════════════════════════════════════════════════════════════
console.log('\n═════ G6 · o reembolsado não recupera acesso ao abrir o app ═════');
//
// Reembolso nem sempre cancela a assinatura na Google. Existe o estado real em
// que a pessoa foi reembolsada e a API ainda responde ACTIVE — e aí o app,
// chamando validateAndroidPurchase na abertura, devolveria o acesso sozinho.

eq('G6a', reconcessaoBloqueada(true, true, true), true,
   'mesma compra, já estornada: reconceder é PROIBIDO');
eq('G6b', reconcessaoBloqueada(true, true, false), false,
   'compra NOVA depois do estorno: pode conceder (assinou de novo)');
eq('G6c', reconcessaoBloqueada(false, true, true), false,
   'a marca não bloqueia CORTE, só reconcessão');
eq('G6d', reconcessaoBloqueada(true, false, true), false,
   'sem estorno anterior, nada a bloquear');

// ═══════════════════════════════════════════════════════════════════════════
// CANÁRIO — três casos que TÊM de reprovar.
//
// Um arquivo de teste que não consegue reprovar nada aprova tudo para sempre.
// Se qualquer um destes três passar, o resultado acima não vale e o processo
// sai != 0.
// ═══════════════════════════════════════════════════════════════════════════
console.log('\n═════ CANÁRIO · estes TRÊS têm de reprovar ═════');
const antes = falhas.length;
eq('CAN-1', decidirEstadoGoogle({ tipo: TIPO_REEMBOLSO, purchaseToken: TOKEN }, AGORA).active,
   true, '(DEVE REPROVAR) reembolsado seguindo assinante');
// CAN-2 também não pode espelhar asserção real. A primeira versão era o inverso
// exato do G5b — e a revisão independente provou o estrago: trocando o corpo de
// `decidirClaim` por `return 'subir'` (ou seja, plantando de volta o bug
// original desta sessão), G5b ficava vermelha E o canário passava, fazendo o
// arquivo imprimir "resultado descartado" por cima de um vermelho legítimo.
// Um canário que dispara junto com o defeito que ele deveria vigiar não é
// canário: é ruído em cima da prova.
eq('CAN-2', eventoDeNotificacao({}), 'algo',
   '(DEVE REPROVAR) envelope vazio virando evento');
// CAN-3 não pode espelhar uma asserção real. A primeira versão deste canário
// era o inverso do G4b, e na bateria de mutação de 13/08 isso deu um sinal
// duplo enganoso: a mutação que quebrava o G4b também fazia o canário passar, e
// o arquivo imprimia "resultado descartado" em cima de um vermelho legítimo.
// Alerta que grita sem motivo é alerta que se aprende a ignorar — o canário
// agora prende uma coisa que nenhuma mutação testada aqui encosta.
eq('CAN-3', decidirEstadoGoogle(ev('SUBSCRIPTION_PURCHASED', { purchaseToken: null }), AGORA).active,
   true, '(DEVE REPROVAR) concedendo acesso a compra sem token');
const canarioReprovou = falhas.length === antes + 3;
falhas.length = antes;                       // as do canário não contam como falha real

console.log('\n═════ RESULTADO ═════');
console.log(`asserções: ${ok} · falhas: ${falhas.length}`);
for (const f of falhas) console.log(`   ✗ ${f}`);

if (!canarioReprovou) {
  console.error('\n✗✗ CANÁRIO PASSOU — este arquivo está CEGO. Resultado descartado.');
  process.exit(2);
}
console.log('canário reprovou os três, como deve: o arquivo enxerga. ✓');

console.log('\n═════ O QUE ESTE ARQUIVO **NÃO** PROVA — cegueira declarada ═════');
console.log('  · Não fala com a Google. Não prova que `purchases.subscriptionsv2.get`');
console.log('    responde, nem que a conta de serviço tem permissão no Play Console —');
console.log('    isso só a primeira compra real prova.');
console.log('  · Não prova a GRAVAÇÃO: dedupe, guarda de ordem e transação do');
console.log('    Firestore exigem emulador (ver testes_entitlement_ciclo.mjs, que');
console.log('    o Assis roda no Mac; este sandbox não tem firebase-tools).');
console.log('  · Não prova que o claim chega ao APP. `setCustomUserClaims` só vale');
console.log('    depois de o cliente renovar o ID token; a prova disso é um device');
console.log('    com uma compra de teste, e o device não estava disponível.');
console.log('  · Não prova que existe produto no Play Console. Em 05/08 não existia.');

process.exit(falhas.length === 0 ? 0 : 1);
