/**
 * Asserções da máquina de estados do entitlement.
 *
 * Roda contra o JS COMPILADO (lib/), não contra o TypeScript — é o mesmo código
 * que vai para produção. Sai com código != 0 se qualquer asserção reprovar,
 * para que o teste de mutação seja objetivo.
 *
 *   cd functions && npm run build && node testes_entitlement.mjs
 */
import { decidirEstado } from './lib/entitlementState.js';

const AGORA = Date.parse('2026-08-04T12:00:00Z');
const FUTURO = Date.parse('2026-09-04T12:00:00Z');
const PASSADO = Date.parse('2026-07-04T12:00:00Z');
const TX = '2000000999888777';

let ok = 0;
const falhas = [];

function checa(id, desc, condicao, observado) {
  if (condicao) {
    ok += 1;
    console.log(`  ✓ ${id} ${desc} — ${observado}`);
  } else {
    falhas.push(`${id} ${desc}`);
    console.log(`  ✗ ${id} ${desc} — OBSERVADO: ${observado}`);
  }
}

const ev = (extra) => ({ originalTransactionId: TX, ambiente: 'Production', ...extra });
const est = (extra) => decidirEstado(ev(extra), AGORA);

console.log('═══ ENTITLEMENT — máquina de estados ═══\n');

console.log('— compra e renovação —');
let e = est({ tipo: 'SUBSCRIBED', subtipo: 'INITIAL_BUY', expiresDateMs: FUTURO, productId: 'alma.premium.mensal' });
checa('E1', 'compra inicial concede acesso até a data', e.active === true && e.expiresAtMs === FUTURO, `${e.active} ${e.motivo}`);
checa('E2', 'compra inicial carrega o productId', e.productId === 'alma.premium.mensal', String(e.productId));

e = est({ tipo: 'DID_RENEW', expiresDateMs: FUTURO });
checa('E3', 'renovação mantém acesso', e.active === true && e.expiresAtMs === FUTURO, `${e.active} ${e.motivo}`);

e = est({ tipo: 'SUBSCRIBED', subtipo: 'RESUBSCRIBE', expiresDateMs: FUTURO });
checa('E4', 'reassinatura concede acesso', e.active === true, `${e.active} ${e.motivo}`);

console.log('\n— cancelamento (o caso que mais gente erra) —');
e = est({ tipo: 'DID_CHANGE_RENEWAL_STATUS', subtipo: 'AUTO_RENEW_DISABLED', expiresDateMs: FUTURO });
checa('E5', 'cancelar NÃO tira o acesso do período já pago', e.active === true && e.expiresAtMs === FUTURO, `${e.active} ${e.motivo}`);

e = est({ tipo: 'DID_CHANGE_RENEWAL_STATUS', subtipo: 'AUTO_RENEW_ENABLED', expiresDateMs: FUTURO });
checa('E6', 'religar a renovação mantém acesso', e.active === true, `${e.active} ${e.motivo}`);

console.log('\n— fim do acesso —');
// NOTA SOBRE ESTAS ASSERÇÕES (importante — 04/08)
// `active === false` sozinho é CEGO aqui. Se alguém apagar o bloco de REFUND,
// o evento cai em "tipo desconhecido", que também devolve `active: false` —
// e a asserção continuaria verde. Só que o estrago seria real: com
// `deveGravar: false` nada é escrito, e o `entitlements/{uid}` ficaria com o
// `active: true` ANTIGO parado lá. Reembolsado com acesso vitalício.
// Por isso todo corte de acesso exige também `deveGravar === true`.
e = est({ tipo: 'EXPIRED', subtipo: 'VOLUNTARY' });
checa('E7', 'expirada não é assinante E manda gravar o corte',
      e.active === false && e.deveGravar === true, `${e.active} gravar=${e.deveGravar} ${e.motivo}`);

e = est({ tipo: 'REFUND', revocationDateMs: AGORA, expiresDateMs: FUTURO });
checa('E8', 'reembolso corta na hora, mesmo com data futura, E manda gravar',
      e.active === false && e.deveGravar === true && /refund/.test(e.motivo),
      `${e.active} gravar=${e.deveGravar} ${e.motivo}`);

e = est({ tipo: 'REVOKE', revocationDateMs: AGORA, expiresDateMs: FUTURO });
checa('E9', 'revogação (compartilhamento familiar) corta na hora E manda gravar',
      e.active === false && e.deveGravar === true && /revoke/.test(e.motivo),
      `${e.active} gravar=${e.deveGravar} ${e.motivo}`);

e = est({ tipo: 'GRACE_PERIOD_EXPIRED' });
checa('E10', 'fim da tolerância não é assinante E manda gravar',
      e.active === false && e.deveGravar === true, `${e.active} gravar=${e.deveGravar} ${e.motivo}`);

console.log('\n— falha de cobrança e tolerância —');
e = est({ tipo: 'DID_FAIL_TO_RENEW', subtipo: 'GRACE_PERIOD', gracePeriodExpiresDateMs: FUTURO });
checa('E11', 'tolerância vigente mantém acesso', e.active === true && e.expiresAtMs === FUTURO, `${e.active} ${e.motivo}`);

e = est({ tipo: 'DID_FAIL_TO_RENEW', subtipo: 'GRACE_PERIOD', gracePeriodExpiresDateMs: PASSADO });
checa('E12', 'tolerância já vencida NÃO mantém acesso E manda gravar',
      e.active === false && e.deveGravar === true && /tolerância/.test(e.motivo),
      `${e.active} gravar=${e.deveGravar} ${e.motivo}`);

e = est({ tipo: 'DID_FAIL_TO_RENEW' });
checa('E13', 'falha sem tolerância tira o acesso E manda gravar',
      e.active === false && e.deveGravar === true && /tolerância/.test(e.motivo),
      `${e.active} gravar=${e.deveGravar} ${e.motivo}`);

console.log('\n— mudança de plano —');
e = est({ tipo: 'DID_CHANGE_RENEWAL_PREF', subtipo: 'UPGRADE', expiresDateMs: FUTURO, productId: 'alma.premium.anual' });
checa('E14', 'mudança de plano mantém acesso e troca o produto', e.active === true && e.productId === 'alma.premium.anual', `${e.active} ${e.productId}`);

console.log('\n— falhar para o lado seguro —');
// E15 exige o MOTIVO, não só o `active === false`. Sem isso a asserção é cega:
// apagando o guarda `if (!expira)`, o `null <= agoraMs` do guarda seguinte
// coage `null` para 0 e devolve inativo por acidente — a assertion passaria e a
// defesa teria sumido. Note que a coerção só salva com `null`; com `undefined`
// a comparação é `false` e o código concederia acesso com data indefinida.
e = est({ tipo: 'SUBSCRIBED', subtipo: 'INITIAL_BUY' });
checa('E15', 'sem expiresDate NÃO vira assinante, e diz que foi por isso',
      e.active === false && /sem expiresDate/.test(e.motivo),
      `${e.active} "${e.motivo}"`);

e = est({ tipo: 'DID_RENEW', expiresDateMs: PASSADO });
checa('E16', 'expiresDate no passado NÃO vira assinante', e.active === false, `${e.active} ${e.motivo}`);

e = est({ tipo: 'TIPO_QUE_A_APPLE_INVENTOU_AMANHA', expiresDateMs: FUTURO });
checa('E17', 'tipo desconhecido NÃO concede acesso', e.active === false, `${e.active} ${e.motivo}`);
checa('E18', 'tipo desconhecido não grava nada', e.deveGravar === false, `deveGravar=${e.deveGravar}`);

e = decidirEstado({ tipo: 'SUBSCRIBED', expiresDateMs: FUTURO }, AGORA);
checa('E19', 'sem originalTransactionId não há a quem conceder', e.active === false && e.deveGravar === false, `${e.active} ${e.motivo}`);

e = est({ tipo: 'TEST' });
checa('E20', 'notificação de teste da Apple não mexe em entitlement', e.active === false && e.deveGravar === false, `deveGravar=${e.deveGravar}`);

e = est({ tipo: 'CONSUMPTION_REQUEST' });
checa('E21', 'pedido de consumo não mexe em entitlement', e.deveGravar === false, `deveGravar=${e.deveGravar}`);

console.log('\n— o motivo tem de ser legível —');
e = est({ tipo: 'DID_CHANGE_RENEWAL_STATUS', subtipo: 'AUTO_RENEW_DISABLED', expiresDateMs: FUTURO });
checa('E22', 'estado ativo explica por que está ativo', /renovação desligada/.test(e.motivo), `"${e.motivo}"`);

console.log(`\n═══ RESULTADO ═══`);
console.log(`aprovados: ${ok}`);
if (falhas.length === 0) {
  console.log('reprovados: NENHUM');
  process.exit(0);
} else {
  console.log(`REPROVADOS (${falhas.length}):`);
  falhas.forEach((f) => console.log(`   ✗ ${f}`));
  process.exit(1);
}
