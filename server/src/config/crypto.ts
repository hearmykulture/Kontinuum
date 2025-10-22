import crypto from 'node:crypto';
import { env } from './env.js';

// Require 32+ chars; use first 32 bytes for AES-256-GCM
const rawKey = env.ENCRYPTION_KEY ?? '';
if (rawKey.length < 32) {
  throw new Error('ENCRYPTION_KEY must be >= 32 ASCII characters');
}
const KEY = Buffer.from(rawKey.slice(0, 32), 'utf8');
const ALGO = 'aes-256-gcm';

export function encrypt(plain: string): string {
  const iv = crypto.randomBytes(12); // 96-bit nonce for GCM
  const cipher = crypto.createCipheriv(ALGO, KEY, iv);
  const enc = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  // Layout: [IV(12)][TAG(16)][CIPHERTEXT]
  return Buffer.concat([iv, tag, enc]).toString('base64');
}

export function decrypt(b64: string): string {
  const buf = Buffer.from(b64, 'base64');
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const data = buf.subarray(28);
  const decipher = crypto.createDecipheriv(ALGO, KEY, iv);
  decipher.setAuthTag(tag);
  const dec = Buffer.concat([decipher.update(data), decipher.final()]);
  return dec.toString('utf8');
}
