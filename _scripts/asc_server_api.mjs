/**
 * Cliente do App Store Server API — autenticação e requestTestNotification.
 *
 * [2026-08-04] A chave de In-App Purchase (4Y98QV45J3) é DIFERENTE das duas de
 * App Store Connect API que já existiam. Vive fora do git, junto das outras.
 *
 * Uso:
 *   node asc_server_api.mjs auth    → só prova que autentica (não depende do ASC)
 *   node asc_server_api.mjs test    → dispara requestTestNotification
 *   node asc_server_api.mjs token X → consulta o resultado de um teste
 */
import { readFileSync } from 'node:fs';
import { AppStoreServerAPIClient, Environment } from '@apple/app-store-server-library';

const KEY_PATH = '/Volumes/felipe 1 tb/Alma_Credentials/AuthKey_4Y98QV45J3.p8';
const KEY_ID = '4Y98QV45J3';
const ISSUER_ID = 'a052dbae-b7ee-4e05-a3f1-4d618d17fcf4';
const BUNDLE_ID = 'com.almaapp.app';

const chave = readFileSync(KEY_PATH, 'utf8');
const cliente = (env) => new AppStoreServerAPIClient(chave, KEY_ID, ISSUER_ID, BUNDLE_ID, env);

const cmd = process.argv[2] ?? 'auth';

if (cmd === 'auth') {
  // Prova de autenticação SEM depender da URL estar cadastrada no ASC:
  // consultamos um originalTransactionId inexistente.
  //   • 401 / 4010000  → a chave não autentica
  //   • 404 / 4040010  → autenticou, transação é que não existe  ← esperado
  for (const [nome, env] of [['SANDBOX', Environment.SANDBOX], ['PRODUCTION', Environment.PRODUCTION]]) {
    try {
      await cliente(env).getTransactionHistory('000000000000000', null, {});
      console.log(`${nome}: 200 — autenticou (e a transação existe?!)`);
    } catch (e) {
      const status = e?.httpStatusCode ?? '?';
      const code = e?.apiError ?? e?.errorCode ?? '?';
      const autenticou = status !== 401;
      console.log(`${autenticou ? '✓' : '✗'} ${nome}: HTTP ${status} · apiError ${code} · ` +
                  (autenticou ? 'AUTENTICOU (erro é da transação inexistente)' : 'FALHA DE AUTENTICAÇÃO'));
    }
  }
} else if (cmd === 'test') {
  const alvo = process.argv[3] === 'production' ? Environment.PRODUCTION : Environment.SANDBOX;
  const r = await cliente(alvo).requestTestNotification();
  console.log('testNotificationToken:', r.testNotificationToken);
} else if (cmd === 'token') {
  const alvo = process.argv[4] === 'production' ? Environment.PRODUCTION : Environment.SANDBOX;
  const r = await cliente(alvo).getTestNotificationStatus(process.argv[3]);
  console.log(JSON.stringify({
    sendAttempts: r.sendAttempts?.map((a) => ({ date: a.attemptDate, result: a.sendAttemptResult })),
  }, null, 2));
}
