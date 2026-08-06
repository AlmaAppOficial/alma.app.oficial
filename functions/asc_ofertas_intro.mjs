/**
 * READ-ONLY — as ofertas introdutórias das assinaturas do Alma, hoje.
 *
 * [2026-08-06] Escrito porque as notas do revisor da 2.0.1 vão AFIRMAR algo
 * sobre teste grátis, e afirmação em texto lido por revisor da Apple precisa
 * ser conferida na fonte no dia, não herdada de relatório.
 *
 * O ponto que confunde: "trial" tem dois donos neste produto.
 *   1. a OFERTA INTRODUTÓRIA do StoreKit, configurada aqui no ASC — é esta;
 *   2. o trial LOCAL dentro do app (`isTrialActive`), que é falso fixo.
 * A asserção A22a proíbe (2), e não diz nada sobre (1). Ler A22a como se
 * cobrisse as duas foi o meu erro na primeira versão das notas.
 *
 * Não grava nada. Só lê.
 */
import { readFileSync } from 'node:fs';
import { createSign } from 'node:crypto';

const KEY_ID = '4Y98QV45J3', ISSUER = 'a052dbae-b7ee-4e05-a3f1-4d618d17fcf4', APP = '6761478534';
const chave = readFileSync('/Volumes/felipe 1 tb/Alma_Credentials/AuthKey_4Y98QV45J3.p8', 'utf8');
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
const t = Math.floor(Date.now() / 1000);
const base = `${b64({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' })}.${b64({ iss: ISSUER, iat: t, exp: t + 900, aud: 'appstoreconnect-v1' })}`;
const sig = createSign('SHA256').update(base).sign({ key: chave, dsaEncoding: 'ieee-p1363' }).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
const JWT = `${base}.${sig}`;
const api = async (p) => {
  const r = await fetch(`https://api.appstoreconnect.apple.com${p}`, { headers: { Authorization: `Bearer ${JWT}` } });
  const x = await r.text();
  return r.ok ? JSON.parse(x) : { erro: r.status, corpo: x.slice(0, 300) };
};

console.log(`CONSULTA EM ${new Date().toISOString()}`);
console.log('='.repeat(70));

const grupos = await api(`/v1/apps/${APP}/subscriptionGroups?include=subscriptions&limit=10`);
if (grupos.erro) { console.log('ERRO grupos:', grupos.erro, grupos.corpo); process.exit(1); }

for (const g of grupos.data) {
  const subs = await api(`/v1/subscriptionGroups/${g.id}/subscriptions?limit=20`);
  if (subs.erro) { console.log('ERRO subs:', subs.erro, subs.corpo); continue; }

  for (const s of subs.data) {
    const a = s.attributes;
    console.log(`\n▸ ${a.productId}`);
    console.log(`   nome=${a.name} · período=${a.subscriptionPeriod} · estado=${a.state}`);

    const ofertas = await api(`/v1/subscriptions/${s.id}/introductoryOffers?include=territory&limit=200`);
    if (ofertas.erro) { console.log(`   ERRO ofertas: ${ofertas.erro} ${ofertas.corpo}`); continue; }

    if (!ofertas.data.length) { console.log('   OFERTA INTRODUTÓRIA: NENHUMA'); continue; }

    const hoje = new Date().toISOString().slice(0, 10);
    const territorios = Object.fromEntries(
      (ofertas.included || []).filter(i => i.type === 'territories').map(i => [i.id, i.id]));

    // Uma oferta vale hoje se já começou e (não tem fim OU o fim é futuro).
    const ativas = ofertas.data.filter(o => {
      const ini = o.attributes.startDate, fim = o.attributes.endDate;
      return (!ini || ini <= hoje) && (!fim || fim >= hoje);
    });

    const amostra = ofertas.data[0].attributes;
    console.log(`   OFERTA INTRODUTÓRIA: ${ofertas.data.length} registro(s) · ${ativas.length} valendo hoje (${hoje})`);
    console.log(`   tipo=${amostra.offerMode} · duração=${amostra.duration} · ciclos=${amostra.numberOfPeriods}`);
    console.log(`   início=${amostra.startDate ?? '(sem data — sempre valeu)'} · fim=${amostra.endDate ?? '(sem fim marcado)'}`);

    const terr = ativas.map(o => o.relationships?.territory?.data?.id).filter(Boolean);
    console.log(`   territórios com oferta valendo: ${terr.length}`);
    console.log(`   Brasil (BRA) na lista: ${terr.includes('BRA') ? 'SIM' : 'NÃO'}`);
    console.log(`   EUA (USA) na lista: ${terr.includes('USA') ? 'SIM' : 'NÃO'}`);
    if (terr.length && terr.length <= 40) console.log(`   lista: ${terr.sort().join(' ')}`);
  }
}

console.log('\n' + '='.repeat(70));
console.log('Nada foi gravado. Consulta somente de leitura.');
