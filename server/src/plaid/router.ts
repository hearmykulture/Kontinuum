import { Router } from 'express';

type PlaidService = {
  createLinkToken: (opts: { userId: string }) => Promise<string>;
  exchangePublicToken: (p: {
    userId: string;
    publicToken: string;
    institutionName?: string;
  }) => Promise<{ itemId: string; plaidItemId: string }>;
  subscribeItemWebhook: (itemId: string) => Promise<{ ok: true }>;
  syncItem: (itemId: string) => Promise<{ added: number; modified: number; removed: number }>;
};

// Lazy loader that works for ESM/CJS outputs under --moduleResolution node16/nodenext
let svcPromise: Promise<PlaidService> | null = null;
function getService(): Promise<PlaidService> {
  if (!svcPromise) {
    svcPromise = (async () => {
      // IMPORTANT: explicit .js so compiled output is resolvable at runtime
      const mod: any = await import('./service.runtime.js');
      const svc: Partial<PlaidService> = {
        createLinkToken: mod.createLinkToken ?? mod.default?.createLinkToken,
        exchangePublicToken: mod.exchangePublicToken ?? mod.default?.exchangePublicToken,
        subscribeItemWebhook: mod.subscribeItemWebhook ?? mod.default?.subscribeItemWebhook,
        syncItem: mod.syncItem ?? mod.default?.syncItem,
      };
      for (const k of ['createLinkToken', 'exchangePublicToken', 'subscribeItemWebhook', 'syncItem'] as const) {
        if (typeof (svc as any)[k] !== 'function') {
          throw new Error(`Missing export ${k} on ./service.runtime (ESM/CJS interop)`);
        }
      }
      return svc as PlaidService;
    })();
  }
  return svcPromise;
}

export const plaidRouter = Router();

// POST /plaid/link_token
plaidRouter.post('/link_token', async (req, res, next) => {
  try {
    const { userId } = (req.body ?? {}) as { userId?: string };
    if (!userId) return res.status(400).json({ error: 'userId is required' });
    const { createLinkToken } = await getService();
    const token = await createLinkToken({ userId: String(userId) });
    res.json({ link_token: token });
  } catch (e) {
    next(e);
  }
});

// POST /plaid/exchange_public_token
plaidRouter.post('/exchange_public_token', async (req, res, next) => {
  try {
    const { userId, public_token, institutionName } = (req.body ?? {}) as {
      userId?: string;
      public_token?: string;
      institutionName?: string;
    };
    if (!userId || !public_token) {
      return res.status(400).json({ error: 'userId and public_token are required' });
    }
    const { exchangePublicToken } = await getService();
    const out = await exchangePublicToken({
      userId: String(userId),
      publicToken: String(public_token),
      institutionName,
    });
    res.json(out);
  } catch (e) {
    next(e);
  }
});

// POST /plaid/subscribe
plaidRouter.post('/subscribe', async (req, res, next) => {
  try {
    const { itemId } = (req.body ?? {}) as { itemId?: string };
    if (!itemId) return res.status(400).json({ error: 'itemId is required' });
    const { subscribeItemWebhook } = await getService();
    const out = await subscribeItemWebhook(String(itemId));
    res.json(out);
  } catch (e) {
    next(e);
  }
});

// POST /plaid/sync
plaidRouter.post('/sync', async (req, res, next) => {
  try {
    const { itemId } = (req.body ?? {}) as { itemId?: string };
    if (!itemId) return res.status(400).json({ error: 'itemId is required' });
    const { syncItem } = await getService();
    const out = await syncItem(String(itemId));
    res.json(out);
  } catch (e) {
    next(e);
  }
});

// Minimal webhook & oauth (optional to keep here)
plaidRouter.post('/webhook', (req, res) => res.json({ ok: true }));
plaidRouter.get('/oauth', (req, res) => {
  const state = String(req.query.oauth_state_id ?? '');
  const deeplink = `kontinuum://plaid/oauth${state ? `?oauth_state_id=${encodeURIComponent(state)}` : ''}`;
  res
    .status(200)
    .type('html')
    .send(`<!doctype html><meta charset="utf-8"><title>Returning…</title>
<script>setTimeout(function(){location='${deeplink}'},100)</script>
<a href="${deeplink}">Open app</a>`);
});

export default plaidRouter;
