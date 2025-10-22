// server/src/plaid/sandbox.ts
import express from 'express';
import { prisma } from '../db/prisma.js';
import { plaid } from '../plaid/client.js';
import { decrypt } from '../config/crypto.js';

export const sandboxRouter = express.Router();

/**
 * POST /plaid/sandbox/fire-webhook
 * body: { itemId: string, code?: 'DEFAULT_UPDATE' | 'NEW_ACCOUNTS_AVAILABLE' | 'SYNC_UPDATES_AVAILABLE' }
 *
 * Notes:
 * - Uses Plaid sandboxItemFireWebhook.
 * - Item must have a webhook set. (Use /plaid/subscribe or re-link with PLAID_WEBHOOK_URL in the link token.)
 * - We unwrap/decrypt the access token if needed.
 */
sandboxRouter.post('/fire-webhook', async (req, res) => {
  try {
    const { itemId, code: raw } = (req.body ?? {}) as {
      itemId?: string;
      code?: string;
    };
    if (!itemId) return res.status(400).json({ error: 'itemId required' });

    // 1) Load the secret row
    const secret = await (prisma as any).plaidSecret.findUnique({ where: { itemId } });
    if (!secret) return res.status(404).json({ error: 'No Plaid secret for itemId' });

    // 2) Unwrap/decrypt to a plain "access-..." token
    const maybePlain = (secret.accessToken as string | undefined) ?? '';
    let accessToken = maybePlain;

    if (typeof accessToken !== 'string' || !accessToken.startsWith('access-')) {
      const enc =
        (secret as any).accessTokenEnc ??
        (typeof maybePlain === 'string' && maybePlain && !maybePlain.startsWith('access-') ? maybePlain : undefined);

      if (!enc) {
        return res.status(500).json({ error: 'Internal Server Error', message: 'No usable access token on secret' });
      }

      try {
        const plain = decrypt(enc);
        if (typeof plain !== 'string' || !plain.startsWith('access-')) {
          return res
            .status(500)
            .json({ error: 'Internal Server Error', message: 'Decryption did not yield a valid access token' });
        }
        accessToken = plain;
      } catch (e: any) {
        return res.status(500).json({
          error: 'Internal Server Error',
          message: `Failed to decrypt access token: ${String(e?.message ?? e)}`,
        });
      }
    }

    // 3) Normalize webhook_code to Plaid-accepted values
    const allowed = new Set(['DEFAULT_UPDATE', 'NEW_ACCOUNTS_AVAILABLE', 'SYNC_UPDATES_AVAILABLE'] as const);
    const webhook_code = allowed.has(String(raw ?? '').toUpperCase() as any)
      ? String(raw).toUpperCase()
      : 'DEFAULT_UPDATE';

    // 4) Fire the sandbox webhook (cast to any to smooth over SDK enum/typing differences)
    const payload: any = {
      access_token: accessToken,
      webhook_type: 'TRANSACTIONS',
      webhook_code,
    };

    const resp = await plaid.sandboxItemFireWebhook(payload);
    res.json({ ok: true, fired: webhook_code, plaid: resp.data });
  } catch (e: any) {
    const status = e?.response?.status ?? 500;
    const data = e?.response?.data ?? String(e);
    console.error('sandbox fire-webhook error:', data);
    res.status(status).json({ error: 'Internal Server Error', message: data });
  }
});

export default sandboxRouter;
