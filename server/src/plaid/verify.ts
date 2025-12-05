import type { Request } from 'express';
import { compactVerify, decodeProtectedHeader, importJWK, JWK } from 'jose';
import { plaid } from './client.js';
import { logger } from '../config/logger.js';

// Dev off, Prod on (set PLAID_VERIFY_WEBHOOKS=true in prod .env)
const ENFORCE = String(process.env.PLAID_VERIFY_WEBHOOKS ?? 'false').toLowerCase() === 'true';

// tiny in-memory cache for Plaid JWKs
const cache = new Map<string, { key: any; exp: number }>();
const TTL_MS = 10 * 60 * 1000;

async function getPlaidKey(kid: string, algHint?: string): Promise<any> {
  const now = Date.now();
  const hit = cache.get(kid);
  if (hit && hit.exp > now) return hit.key;

  // Plaid Node client exposes: webhookVerificationKeyGet({ key_id })
  const { data } = await plaid.webhookVerificationKeyGet({ key_id: kid } as any);
  const jwk = (data as any)?.key as JWK | undefined;
  if (!jwk) throw new Error('Plaid JWK not found');

  const key: any = await importJWK(jwk, (jwk.alg as string) || algHint || 'ES256');
  cache.set(kid, { key, exp: now + TTL_MS });
  return key;
}

export async function verifyPlaidWebhookSignature(req: Request): Promise<boolean> {
  if (!ENFORCE) return true; // dev: allow manual curl without JWS

  // Header name is case-insensitive; Plaid uses "Plaid-Verification"
  const jws =
    (req.headers['plaid-verification'] as string | undefined) ??
    req.get('Plaid-Verification') ??
    undefined;

  if (!jws) {
    logger.warn({ headers: req.headers }, 'Missing Plaid-Verification header');
    return false;
  }

  // exact raw JSON bytes captured by app.ts verify hook
  const raw: Buffer | undefined = (req as any).rawBody;
  if (!raw) {
    logger.warn('Missing rawBody for webhook verification');
    return false;
  }

  try {
    const { kid, alg } = decodeProtectedHeader(jws) || {};
    if (!kid) {
      logger.warn('Plaid JWS missing kid');
      return false;
    }
    const key = await getPlaidKey(String(kid), typeof alg === 'string' ? alg : undefined);

    // Verify signature over payload
    const verified = await compactVerify(jws, key);
    const signedPayload = Buffer.from(verified.payload);

    // Payload must equal the exact bytes Plaid sent
    if (!signedPayload.equals(raw)) {
      logger.warn(
        { signedLen: signedPayload.length, rawLen: raw.length },
        'Webhook JWS payload mismatch',
      );
      return false;
    }

    return true;
  } catch (err: any) {
    logger.warn({ err: err?.message }, 'Plaid webhook signature verification failed');
    return false;
  }
}
