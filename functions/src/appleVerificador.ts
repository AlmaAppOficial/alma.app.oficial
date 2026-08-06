/**
 * Verificador JWS da Apple — instância única, compartilhada.
 *
 * [2026-08-06] Existia dentro do `appleNotifications.ts` e agora é usado por
 * dois caminhos: o webhook (notificação) e o endpoint de vínculo (transação
 * assinada mandada pelo app). Duplicar a construção significaria duas listas de
 * raízes, dois `bundleId` e a chance de um dos dois ficar para trás numa
 * mudança — exatamente o tipo de divergência que criou o furo que estamos
 * fechando. Um lugar só.
 *
 * O QUE NÃO MUDA, e por que importa:
 *   • `enableOnlineChecks = true` — consulta OCSP da Apple. Custa latência e
 *     recusa certificado revogado. Num endpoint que decide dinheiro, a troca
 *     vale a pena. O app chama o vínculo no máximo uma vez por dia (ver
 *     `AlmaEntitlementBridge.swift`), então o custo é irrisório.
 *   • Tentamos PRODUÇÃO e depois SANDBOX. A Apple usa URLs diferentes, mas o
 *     mesmo endpoint pode atender as duas — e em teste de sandbox a assinatura
 *     só bate no verificador de sandbox.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  SignedDataVerifier,
  Environment,
  JWSTransactionDecodedPayload,
  JWSRenewalInfoDecodedPayload,
  ResponseBodyV2DecodedPayload,
} from '@apple/app-store-server-library';

export const BUNDLE_ID = 'com.almaapp.app';
export const APP_APPLE_ID = 6761478534;

/**
 * Produtos de assinatura do Alma.
 *
 * ⚠️ ESPELHA `StoreKitManager.allIDs` (Shared/StoreKitManager.swift:30-32).
 * Se um produto novo for criado no App Store Connect e não entrar aqui, a
 * compra é verificada com sucesso e MESMO ASSIM não concede acesso — falha
 * silenciosa e do lado errado. Ao criar produto, mexer nos dois lugares.
 */
export const PRODUTOS_DE_ASSINATURA: ReadonlySet<string> = new Set([
  'com.almaapp.app.premium_monthly',
  'com.almaapp.app.premium_annual',
]);

let cache: { ambiente: Environment; v: SignedDataVerifier }[] | null = null;

function verificadores(): { ambiente: Environment; v: SignedDataVerifier }[] {
  if (cache) return cache;
  const dir = join(__dirname, '..', 'apple_certs');
  const raizes = ['AppleRootCA-G3.pem'].map((f) => readFileSync(join(dir, f)));
  cache = [Environment.PRODUCTION, Environment.SANDBOX].map((ambiente) => ({
    ambiente,
    v: new SignedDataVerifier(raizes, true, ambiente, BUNDLE_ID, APP_APPLE_ID),
  }));
  return cache;
}

/** Erro de verificação — carrega o que cada ambiente reclamou, para o log. */
export class AssinaturaInvalida extends Error {
  constructor(public readonly detalhes: string[]) {
    super(`assinatura inválida: ${detalhes.join(' | ')}`);
    this.name = 'AssinaturaInvalida';
  }
}

/**
 * Roda `fn` no primeiro verificador que aceitar a assinatura.
 * Nada é decodificado de um payload que não passou — é a regra da casa.
 */
async function comVerificador<T>(
  fn: (v: SignedDataVerifier) => Promise<T>,
): Promise<{ valor: T; ambiente: Environment }> {
  const erros: string[] = [];
  for (const { ambiente, v } of verificadores()) {
    try {
      return { valor: await fn(v), ambiente };
    } catch (e) {
      erros.push(`${ambiente}: ${(e as Error).message}`);
    }
  }
  throw new AssinaturaInvalida(erros);
}

export function verificarNotificacao(
  jws: string,
): Promise<{ valor: ResponseBodyV2DecodedPayload; ambiente: Environment }> {
  return comVerificador((v) => v.verifyAndDecodeNotification(jws));
}

export function verificarTransacao(
  jws: string,
): Promise<{ valor: JWSTransactionDecodedPayload; ambiente: Environment }> {
  return comVerificador((v) => v.verifyAndDecodeTransaction(jws));
}

export function verificarRenovacao(
  jws: string,
): Promise<{ valor: JWSRenewalInfoDecodedPayload; ambiente: Environment }> {
  return comVerificador((v) => v.verifyAndDecodeRenewalInfo(jws));
}
