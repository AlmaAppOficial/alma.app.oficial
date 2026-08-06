/**
 * Ciclo de vida do entitlement, ponta a ponta, contra o EMULADOR do Firestore.
 *
 * Por que existe, além do `testes_entitlement.mjs`: aquele exercita a decisão
 * (função pura). Este exercita o que estava REALMENTE quebrado — a conversão do
 * payload da Apple em evento, a gravação, a fila de pendentes e a leitura final
 * por `ehAssinante`. Nada aqui é reimplementado: importa `lib/`, o mesmo
 * JavaScript que vai para produção.
 *
 * Como rodar (o emulador sobe e desce sozinho):
 *   cd functions && npm run build && ./roda_testes_ciclo.sh
 *
 * CANÁRIO: o último bloco planta um caso que TEM de reprovar. Se ele passar, o
 * arquivo inteiro está cego e o resultado é descartado — em voz alta.
 */
import admin from 'firebase-admin';
import { readFile } from 'node:fs/promises';
import { eventoDeNotificacao, eventoDeTransacao } from './lib/appleEvento.js';
import { aplicarEvento, reprocessarPendentes, vincularEAplicar } from './lib/entitlementApply.js';
import { ehAssinante } from './lib/entitlementLeitura.js';
import { apurarPendencias } from './lib/alertaEntitlement.js';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('✗✗ FIRESTORE_EMULATOR_HOST não está definido — este teste NÃO pode rodar contra dado real.');
  process.exit(2);
}

admin.initializeApp({ projectId: 'demo-alma' });
const db = admin.firestore();

const DIA = 86_400_000;
const AGORA = Date.now();
const FUTURO = AGORA + 30 * DIA;
const PASSADO = AGORA - 30 * DIA;
const MENSAL = 'com.almaapp.app.premium_monthly';
const ANUAL = 'com.almaapp.app.premium_annual';

let ok = 0;
const falhas = [];

function checa(id, desc, condicao, observado) {
  if (condicao) {
    ok += 1;
    console.log(`  ✓ ${id} ${desc} — ${observado}`);
  } else {
    falhas.push(`${id} ${desc} — OBSERVADO: ${observado}`);
    console.log(`  ✗ ${id} ${desc} — OBSERVADO: ${observado}`);
  }
}

/**
 * Cada caso usa uid e transação próprios, para um não sujar o outro.
 * O prefixo por execução existe para o teste poder rodar VÁRIAS VEZES contra o
 * mesmo emulador sem herdar o estado da rodada anterior — é o que a bateria de
 * mutação faz, e sem isso a segunda rodada leria documentos da primeira e daria
 * verde por acidente.
 */
const EXECUCAO = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`;
let n = 0;
function novoCaso() {
  n += 1;
  return { uid: `uid-${EXECUCAO}-${n}`, tx: `9${EXECUCAO}${n}` };
}

async function vincular(tx, uid) {
  await db.collection('apple_transaction_links').doc(tx).set({ uid });
}

/** Grava uma notificação no mesmo formato que o webhook grava. */
async function notificacaoPendente(uuid, evento, recebidaEm) {
  await db.collection('apple_notifications').doc(uuid).set({
    notificationType: evento.tipo,
    subtype: evento.subtipo,
    originalTransactionId: evento.originalTransactionId,
    evento,
    processada: false,
    recebidaEm: admin.firestore.Timestamp.fromMillis(recebidaEm),
  });
}

const notif = (tipo, sub, signedDateMs) => ({
  notificationType: tipo,
  subtype: sub,
  notificationUUID: `uuid-${tipo}-${signedDateMs}`,
  signedDate: signedDateMs,
  data: { environment: 'Sandbox' },
});

// ═══════════════════════════════════════════════════════════════════════════
console.log('═══ CICLO DO ENTITLEMENT — emulador ═══\n');
console.log('— conversão do payload da Apple (o cano que não existia) —');

{
  // A tolerância só existe no RenewalInfo. Se a conversão não juntar os dois,
  // todo DID_FAIL_TO_RENEW/GRACE_PERIOD corta acesso de quem ainda está pagando.
  const e = eventoDeNotificacao(
    notif('DID_FAIL_TO_RENEW', 'GRACE_PERIOD', AGORA),
    { originalTransactionId: 'tx1', productId: MENSAL, expiresDate: PASSADO },
    { gracePeriodExpiresDate: FUTURO },
  );
  checa('T1', 'notificação junta transação E tolerância do RenewalInfo',
    e.originalTransactionId === 'tx1' && e.gracePeriodExpiresDateMs === FUTURO,
    `tx=${e.originalTransactionId} tolerância=${e.gracePeriodExpiresDateMs}`);
  checa('T2', 'notificação carrega o signedDate (guarda de ordem depende dele)',
    e.signedDateMs === AGORA, String(e.signedDateMs));
}
{
  const e = eventoDeTransacao({ originalTransactionId: 'tx2', productId: MENSAL, expiresDate: FUTURO }, AGORA);
  checa('T3', 'transação com data futura vira evento de acesso', e.tipo === 'SUBSCRIBED', e.tipo);
}
{
  const e = eventoDeTransacao({ originalTransactionId: 'tx3', productId: MENSAL, expiresDate: PASSADO }, AGORA);
  checa('T4', 'transação vencida vira EXPIRED', e.tipo === 'EXPIRED', e.tipo);
}
{
  const e = eventoDeTransacao(
    { originalTransactionId: 'tx4', productId: MENSAL, expiresDate: FUTURO, revocationDate: AGORA }, AGORA);
  checa('T5', 'transação reembolsada vira REVOKE mesmo com data futura', e.tipo === 'REVOKE', e.tipo);
}

// ═══════════════════════════════════════════════════════════════════════════
console.log('\n— a pergunta que o chat faz: ehAssinante —');

{
  const { uid, tx } = novoCaso();
  const antes = await ehAssinante(db, uid);
  checa('C1', 'uid sem entitlement NÃO é assinante', antes === false, String(antes));

  await vincular(tx, uid);
  await aplicarEvento(db, eventoDeNotificacao(
    notif('SUBSCRIBED', 'INITIAL_BUY', AGORA),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO },
    null), AGORA);

  const depois = await ehAssinante(db, uid);
  checa('C2', 'compra verificada + vínculo → É ASSINANTE', depois === true, String(depois));
}

{
  // A linha `expira.toMillis() < Date.now()` de `ehAssinante`. Para chegar num
  // documento `active: true` com data já vencida sem esperar um mês, decidimos o
  // estado com o relógio no passado: na época era ativo, hoje não é mais.
  const { uid, tx } = novoCaso();
  await vincular(tx, uid);
  const dezDiasAtras = AGORA - 10 * DIA;
  await aplicarEvento(db, eventoDeNotificacao(
    notif('SUBSCRIBED', 'INITIAL_BUY', dezDiasAtras),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: AGORA - 5 * DIA },
    null), dezDiasAtras);

  const doc = (await db.doc(`entitlements/${uid}`).get()).data();
  checa('C3', 'documento ficou active:true com data já vencida (a armadilha)',
    doc.active === true && doc.expiresAt.toMillis() < Date.now(),
    `active=${doc.active} expira=${doc.expiresAt.toDate().toISOString()}`);
  const r = await ehAssinante(db, uid);
  checa('C4', 'DEPOIS DE EXPIRAR não é mais assinante, mesmo com active:true', r === false, String(r));
}

{
  const { uid, tx } = novoCaso();
  await vincular(tx, uid);
  await aplicarEvento(db, eventoDeNotificacao(
    notif('EXPIRED', 'VOLUNTARY', AGORA),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: PASSADO }, null), AGORA);
  const r = await ehAssinante(db, uid);
  checa('C5', 'EXPIRED corta o acesso', r === false, String(r));
}

{
  const { uid, tx } = novoCaso();
  await vincular(tx, uid);
  await aplicarEvento(db, eventoDeNotificacao(
    notif('DID_CHANGE_RENEWAL_STATUS', 'AUTO_RENEW_DISABLED', AGORA),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO }, null), AGORA);
  const r = await ehAssinante(db, uid);
  checa('C6', 'quem CANCELOU continua assinante até o fim do período pago', r === true, String(r));
}

{
  const { uid, tx } = novoCaso();
  await vincular(tx, uid);
  await aplicarEvento(db, eventoDeNotificacao(
    notif('SUBSCRIBED', 'INITIAL_BUY', AGORA - DIA),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO }, null), AGORA);
  await aplicarEvento(db, eventoDeNotificacao(
    notif('DID_CHANGE_RENEWAL_PREF', 'UPGRADE', AGORA),
    { originalTransactionId: tx, productId: ANUAL, expiresDate: FUTURO }, null), AGORA);
  const doc = (await db.doc(`entitlements/${uid}`).get()).data();
  checa('C7', 'upgrade troca o produto e mantém acesso',
    doc.active === true && doc.productId === ANUAL, `${doc.active} ${doc.productId}`);
}

// ═══════════════════════════════════════════════════════════════════════════
console.log('\n— reentrega e ordem (o que a Apple faz de verdade) —');

{
  const { uid, tx } = novoCaso();
  await vincular(tx, uid);
  const ev = eventoDeNotificacao(
    notif('SUBSCRIBED', 'INITIAL_BUY', AGORA),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO }, null);
  await aplicarEvento(db, ev, AGORA);
  const primeiro = (await db.doc(`entitlements/${uid}`).get()).data();
  await aplicarEvento(db, ev, AGORA);
  await aplicarEvento(db, ev, AGORA);
  const depois = (await db.doc(`entitlements/${uid}`).get()).data();
  checa('C8', 'aplicar o MESMO evento 3× não corrompe o estado',
    depois.active === primeiro.active &&
    depois.expiresAt.toMillis() === primeiro.expiresAt.toMillis() &&
    depois.productId === primeiro.productId,
    `active=${depois.active} expira=${depois.expiresAt.toMillis()}`);
}

{
  // O caso que motiva a guarda de ordem: REFUND de hoje, DID_RENEW de ontem
  // reentregue DEPOIS. Sem guarda, o reembolsado volta a ter acesso.
  const { uid, tx } = novoCaso();
  await vincular(tx, uid);
  const ontem = AGORA - DIA;
  await aplicarEvento(db, eventoDeNotificacao(
    notif('DID_RENEW', null, ontem),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO }, null), AGORA);
  await aplicarEvento(db, eventoDeNotificacao(
    notif('REFUND', null, AGORA),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO, revocationDate: AGORA }, null), AGORA);
  checa('C9', 'reembolso corta mesmo com data de expiração no futuro',
    (await ehAssinante(db, uid)) === false, String(await ehAssinante(db, uid)));

  // A reentrega do evento velho chega agora.
  await aplicarEvento(db, eventoDeNotificacao(
    notif('DID_RENEW', null, ontem),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO }, null), AGORA);
  const r = await ehAssinante(db, uid);
  checa('C10', 'RENOVAÇÃO ANTIGA reentregue DEPOIS do reembolso NÃO devolve acesso',
    r === false, String(r));
}

{
  // A recíproca: um REFUND que chega fora de ordem tem de vencer assim mesmo.
  const { uid, tx } = novoCaso();
  await vincular(tx, uid);
  await aplicarEvento(db, eventoDeNotificacao(
    notif('DID_RENEW', null, AGORA),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO }, null), AGORA);
  await aplicarEvento(db, eventoDeNotificacao(
    notif('REFUND', null, AGORA - 2 * DIA),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO, revocationDate: AGORA - 2 * DIA }, null), AGORA);
  const r = await ehAssinante(db, uid);
  checa('C11', 'reembolso ATRASADO vence a guarda de ordem e corta', r === false, String(r));
}

// ═══════════════════════════════════════════════════════════════════════════
console.log('\n— a fila de pendentes (o cano que estava entupido e calado) —');

{
  const { uid, tx } = novoCaso();
  const ev = eventoDeNotificacao(
    notif('SUBSCRIBED', 'INITIAL_BUY', AGORA),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO }, null);

  const r1 = await aplicarEvento(db, ev, AGORA);
  checa('C12', 'sem vínculo a notificação fica PENDENTE, não é perdida nem aplicada',
    r1.aplicado === false && r1.pendente === true, `aplicado=${r1.aplicado} pendente=${r1.pendente}`);
  checa('C13', 'e ninguém vira assinante por acidente',
    (await ehAssinante(db, uid)) === false, String(await ehAssinante(db, uid)));

  await notificacaoPendente(`uuid-pend-${n}`, ev, AGORA);
  await vincular(tx, uid);
  const aplicadas = await reprocessarPendentes(db, tx, AGORA);
  checa('C14', 'quando o vínculo aparece, o histórico guardado é APLICADO',
    aplicadas === 1, `${aplicadas} aplicada(s)`);
  checa('C15', 'e a pessoa vira assinante sem ter perdido nada',
    (await ehAssinante(db, uid)) === true, String(await ehAssinante(db, uid)));

  const doc = (await db.doc(`apple_notifications/uuid-pend-${n}`).get()).data();
  checa('C16', 'a notificação aplicada é marcada como processada',
    doc.processada === true, `processada=${doc.processada}`);
}

// ═══════════════════════════════════════════════════════════════════════════
console.log('\n— caminho B2: o app manda a compra assinada —');

{
  const { uid, tx } = novoCaso();
  const r = await vincularEAplicar(db, uid, {
    originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO, signedDate: AGORA,
  }, AGORA);
  checa('C17', 'transação assinada concede acesso NA HORA, sem esperar webhook',
    r.ok === true && r.ativo === true && (await ehAssinante(db, uid)) === true,
    `ok=${r.ok} ativo=${r.ativo} ${r.motivo}`);
  const vinc = (await db.doc(`apple_transaction_links/${tx}`).get()).data();
  checa('C18', 'e o vínculo transação→uid fica gravado', vinc.uid === uid, vinc.uid);
}

{
  const { uid, tx } = novoCaso();
  const r = await vincularEAplicar(db, uid, {
    originalTransactionId: tx, productId: 'com.almaapp.app.qualquer_outra_coisa',
    expiresDate: FUTURO, signedDate: AGORA,
  }, AGORA);
  checa('C19', 'produto fora da lista de assinaturas NÃO concede Premium',
    r.ok === false && (await ehAssinante(db, uid)) === false, `ok=${r.ok} ${r.motivo}`);
}

// ═══════════════════════════════════════════════════════════════════════════
console.log('\n— a JANELA: assina antes do build novo existir —');

{
  // Cenário exato de quem assina depois do deploy do servidor e ANTES de o
  // build com o `AlmaEntitlementBridge` chegar ao aparelho. A pergunta do Assis
  // em 06/08: "existe janela em que alguém paga e não recebe?"
  // A resposta é sim, e estas asserções são a prova — e também a prova de que a
  // janela FECHA sozinha, sem intervenção, quando a pessoa atualiza o app.
  const { uid, tx } = novoCaso();
  const ev = eventoDeNotificacao(
    notif('SUBSCRIBED', 'INITIAL_BUY', AGORA),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO }, null);

  // 1) A pessoa compra. A Apple avisa o servidor. O app velho não vincula nada.
  const r = await aplicarEvento(db, ev, AGORA);
  await notificacaoPendente(`uuid-janela-${n}`, ev, AGORA);
  checa('C22', 'JANELA REAL: pagou, servidor recebeu, e ela NÃO é assinante ainda',
    r.pendente === true && (await ehAssinante(db, uid)) === false,
    `pendente=${r.pendente} assinante=${await ehAssinante(db, uid)}`);

  // 2) Dias depois ela atualiza o app. O bridge manda a transação assinada.
  await vincularEAplicar(db, uid, {
    originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO, signedDate: AGORA + DIA,
  }, AGORA + DIA);
  checa('C23', 'ao atualizar o app, o acesso aparece sem ninguém mexer à mão',
    (await ehAssinante(db, uid)) === true, String(await ehAssinante(db, uid)));

  const pend = (await db.doc(`apple_notifications/uuid-janela-${n}`).get()).data();
  checa('C24', 'e a notificação que ficou esperando é resolvida, não abandonada',
    pend.processada === true, `processada=${pend.processada} · ${pend.resultado}`);
}

// ═══════════════════════════════════════════════════════════════════════════
console.log('\n— o alerta: descobrir que alguém pagou e não recebeu —');

{
  // Três notificações do mesmo tipo, idades diferentes. Só a velha e ainda
  // pendente pode disparar o alerta: se a recente entrar, o alerta grita todo
  // dia sem motivo e a gente aprende a ignorá-lo — que é o mesmo que não ter.
  const base = novoCaso();
  const evPara = (tx, sd) => eventoDeNotificacao(
    notif('SUBSCRIBED', 'INITIAL_BUY', sd),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: FUTURO }, null);

  const txVelha = `${base.tx}v`;
  const txNova = `${base.tx}n`;
  const txFeita = `${base.tx}f`;

  await notificacaoPendente(`al-velha-${n}`, evPara(txVelha, AGORA), AGORA - 5 * DIA);
  await notificacaoPendente(`al-nova-${n}`, evPara(txNova, AGORA), AGORA - 2 * 3600_000);
  await notificacaoPendente(`al-feita-${n}`, evPara(txFeita, AGORA), AGORA - 9 * DIA);
  await db.doc(`apple_notifications/al-feita-${n}`).update({ processada: true });

  const r = await apurarPendencias(db, AGORA, 3);
  checa('C25', 'pendência ANTIGA entra no alerta',
    r.transacoes.includes(txVelha), r.transacoes.join(',') || '(nenhuma)');
  checa('C26', 'pendência RECENTE não entra (senão o alerta vira ruído diário)',
    !r.transacoes.includes(txNova), `${r.total} no total`);
  checa('C27', 'notificação já resolvida não entra, por mais velha que seja',
    !r.transacoes.includes(txFeita), `${r.total} no total`);
}

// ═══════════════════════════════════════════════════════════════════════════
console.log('\n— o bug original: código vivo no repo, morto em produção —');

{
  // O Firebase só implanta o que sai do `index.ts`. `entitlementApply.ts`
  // existia, compilava e era testado desde 04/08 — e nunca foi exportado, então
  // NADA daquilo rodava. O diagnóstico foi feito lendo `lib/index.js`; a
  // asserção vigia o mesmo artefato, para que a regressão seja impossível de
  // passar despercebida: basta alguém apagar a linha de export.
  const compilado = await readFile(new URL('./lib/index.js', import.meta.url), 'utf8');
  checa('C20', 'vincularAssinatura está EXPORTADO no index compilado',
    /exports\.vincularAssinatura/.test(compilado) && /require\("\.\/entitlementApply"\)/.test(compilado),
    /exports\.vincularAssinatura/.test(compilado) ? 'presente' : 'AUSENTE — não vai para produção');
  checa('C21', 'appleNotifications continua exportado',
    /exports\.appleNotifications/.test(compilado), 'presente');
}

// ═══════════════════════════════════════════════════════════════════════════
// CANÁRIO — este bloco TEM de reprovar. Se passar, o arquivo está cego.
// ═══════════════════════════════════════════════════════════════════════════
console.log('\n— canário (tem de reprovar) —');
let detectorVivo = false;
{
  const { uid, tx } = novoCaso();
  await vincular(tx, uid);
  await aplicarEvento(db, eventoDeNotificacao(
    notif('EXPIRED', 'VOLUNTARY', AGORA),
    { originalTransactionId: tx, productId: MENSAL, expiresDate: PASSADO }, null), AGORA);
  // Afirmação deliberadamente FALSA: expirado não é assinante.
  const r = await ehAssinante(db, uid);
  detectorVivo = r === false;
  console.log(
    detectorVivo
      ? '  ✓ detector vivo — o canário foi acusado como esperado'
      : '  ✗✗ DETECTOR CEGO — o canário passou; TODO o resultado acima é inválido',
  );
}

console.log('\n═══ RESULTADO ═══');
console.log(`aprovados: ${ok}`);
if (!detectorVivo) {
  console.log('✗✗ HARNESS CEGO — resultado descartado.');
  process.exit(3);
}
if (falhas.length === 0) {
  console.log('reprovados: NENHUM');
  process.exit(0);
} else {
  console.log(`REPROVADOS (${falhas.length}):`);
  falhas.forEach((f) => console.log(`   ✗ ${f}`));
  process.exit(1);
}
