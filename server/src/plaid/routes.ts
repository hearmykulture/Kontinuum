import { Router } from "express";
import { prisma } from "../db/prisma.js";
import { decrypt } from "../config/crypto.js";
import { plaid } from "./client.js";
import { plaidWebhook } from "./webhook.js";
import { SandboxItemFireWebhookRequestWebhookCodeEnum } from "plaid";

// ---- Lazy-loaded runtime service (works for ESM/CJS under NodeNext) ----
type PlaidService = {
  createLinkToken: (opts: { userId: string }) => Promise<string>;
  exchangePublicToken: (p: {
    userId: string;
    publicToken: string;
    institutionName?: string;
  }) => Promise<{ itemId: string; plaidItemId: string }>;
  createSandboxItem: (p: {
    userId: string;
    institutionId?: string;
    institutionName?: string;
  }) => Promise<{ itemId: string; plaidItemId: string }>;
  transactionsRefresh: (itemId: string) => Promise<{ ok: true }>;
  subscribeItemWebhook: (itemId: string) => Promise<{ ok: true }>;
  syncItem: (
    itemId: string
  ) => Promise<{ added: number; modified: number; removed: number }>;
};

let svcPromise: Promise<PlaidService> | null = null;
export function getService(): Promise<PlaidService> {
  if (!svcPromise) {
    svcPromise = (async () => {
      const mod: any = await import("./service.runtime.js"); // explicit .js for NodeNext
      const svc: Partial<PlaidService> = {
        createLinkToken: mod.createLinkToken ?? mod.default?.createLinkToken,
        exchangePublicToken:
          mod.exchangePublicToken ?? mod.default?.exchangePublicToken,
        createSandboxItem:
          mod.createSandboxItem ?? mod.default?.createSandboxItem,
        transactionsRefresh:
          mod.transactionsRefresh ?? mod.default?.transactionsRefresh,
        subscribeItemWebhook:
          mod.subscribeItemWebhook ?? mod.default?.subscribeItemWebhook,
        syncItem: mod.syncItem ?? mod.default?.syncItem,
      };
      (
        [
          "createLinkToken",
          "exchangePublicToken",
          "createSandboxItem",
          "transactionsRefresh",
          "subscribeItemWebhook",
          "syncItem",
        ] as const
      ).forEach((k) => {
        if (typeof (svc as any)[k] !== "function") {
          throw new Error(
            `Missing export ${k} on ./service.runtime (ESM/CJS interop)`
          );
        }
      });
      return svc as PlaidService;
    })();
  }
  return svcPromise;
}

export const plaidRouter = Router();

// POST /plaid/link_token
plaidRouter.post("/link_token", async (req, res, next) => {
  try {
    const { userId } = (req.body ?? {}) as { userId?: string };
    if (!userId) {
      return res.status(400).json({ error: "userId is required" });
    }

    const { createLinkToken } = await getService();
    const token = await createLinkToken({ userId: String(userId) });
    return res.json({ link_token: token });
  } catch (e: any) {
    // 🔍 EXTRA LOGGING FOR PLAID LINK TOKEN FAILURES
    console.error("❌ /plaid/link_token failed");
    console.error("  body.userId:", (req.body ?? {}).userId);
    console.error("  name:", e?.name);
    console.error("  message:", e?.message);

    if (e?.response) {
      console.error("  plaid status:", e.response.status);
      console.error("  plaid data:", e.response.data);
    } else {
      console.error("  raw error:", e);
    }

    const status = e?.response?.status ?? 500;
    const payload = e?.response?.data ?? { message: String(e?.message ?? e) };

    return res.status(status).json({
      error: "Internal Server Error",
      ...payload,
    });
  }
});

// POST /plaid/exchange_public_token
plaidRouter.post("/exchange_public_token", async (req, res, next) => {
  try {
    const { userId, public_token, institutionName } = (req.body ?? {}) as {
      userId?: string;
      public_token?: string;
      institutionName?: string;
    };
    if (!userId || !public_token) {
      return res
        .status(400)
        .json({ error: "userId and public_token are required" });
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

// POST /plaid/sandbox/create-item  (programmatically create a brand-new sandbox item)
plaidRouter.post("/sandbox/create-item", async (req, res, next) => {
  try {
    const { userId, institutionId, institutionName } = (req.body ?? {}) as {
      userId?: string;
      institutionId?: string;
      institutionName?: string;
    };
    if (!userId) return res.status(400).json({ error: "userId is required" });
    const { createSandboxItem } = await getService();
    const out = await createSandboxItem({
      userId,
      institutionId,
      institutionName,
    });
    res.json(out);
  } catch (e) {
    next(e);
  }
});

// POST /plaid/subscribe (helpful in sandbox/local)
plaidRouter.post("/subscribe", async (req, res, next) => {
  try {
    const { itemId } = (req.body ?? {}) as { itemId?: string };
    if (!itemId) return res.status(400).json({ error: "itemId is required" });
    const { subscribeItemWebhook } = await getService();
    const out = await subscribeItemWebhook(String(itemId));
    res.json(out);
  } catch (e) {
    next(e);
  }
});

// POST /plaid/transactions/refresh
plaidRouter.post("/transactions/refresh", async (req, res, next) => {
  try {
    const { itemId } = (req.body ?? {}) as { itemId?: string };
    if (!itemId) return res.status(400).json({ error: "itemId is required" });
    const { transactionsRefresh } = await getService();
    const out = await transactionsRefresh(String(itemId));
    res.json(out);
  } catch (e) {
    next(e);
  }
});

// POST /plaid/sync (manual sync)
plaidRouter.post("/sync", async (req, res, next) => {
  try {
    const { itemId } = (req.body ?? {}) as { itemId?: string };
    if (!itemId) return res.status(400).json({ error: "itemId is required" });
    const { syncItem } = await getService();
    const out = await syncItem(String(itemId));
    res.json(out);
  } catch (e) {
    next(e);
  }
});

// ---- Helpers for sandbox fire_webhook ----
function toWebhookCodeEnum(
  input?: string
): SandboxItemFireWebhookRequestWebhookCodeEnum {
  const E = SandboxItemFireWebhookRequestWebhookCodeEnum;
  const candidate = (input ?? "").toUpperCase();
  return (Object.values(E) as string[]).includes(candidate)
    ? (candidate as SandboxItemFireWebhookRequestWebhookCodeEnum)
    : E.DefaultUpdate;
}

// Plaid's type enum for webhook_type isn't exported in this SDK version.
// We'll whitelist common types and pass only valid ones.
function toWebhookType(input?: string): string | undefined {
  const allowed = new Set([
    "TRANSACTIONS",
    "AUTH",
    "INVESTMENTS",
    "LIABILITIES",
    "INCOME",
    "ASSETS",
    "HOLDINGS",
  ]);
  const t = (input ?? "").toUpperCase();
  return allowed.has(t) ? t : undefined;
}

/** POST /plaid/sandbox/fire-webhook — trigger a Plaid sandbox webhook for an item */
plaidRouter.post("/sandbox/fire-webhook", async (req, res, next) => {
  try {
    const { itemId, webhookType, webhookCode, code } = (req.body ?? {}) as {
      itemId?: string;
      webhookType?: string;
      webhookCode?: string;
      code?: string; // alias
    };
    if (!itemId) return res.status(400).json({ error: "itemId is required" });

    // Find and decrypt the access token for the item
    const secret = await prisma.plaidSecret.findFirst({
      where: { itemId },
      select: { accessToken: true },
    });
    if (!secret?.accessToken)
      return res.status(404).json({ error: "No Plaid secret for itemId" });

    const access_token = decrypt(secret.accessToken);
    const body: any = {
      access_token,
      webhook_code: toWebhookCodeEnum(webhookCode ?? code),
    };
    const wt = toWebhookType(webhookType);
    if (wt) body.webhook_type = wt;

    const { data } = await plaid.sandboxItemFireWebhook(body);
    res.json({ ok: true, requestId: data.request_id });
  } catch (e: any) {
    const status = e?.response?.status;
    const err = e?.response?.data || { message: String(e?.message ?? e) };
    if (status)
      return res.status(500).json({ error: "Internal Server Error", ...err });
    next(e);
  }
});

/** GET /plaid/oauth — simple return page that deep-links back into the app */
plaidRouter.get("/oauth", (req, res) => {
  const state = String(req.query.oauth_state_id ?? "");
  const deeplink = `kontinuum://plaid/oauth${
    state ? `?oauth_state_id=${encodeURIComponent(state)}` : ""
  }`;
  const html = `<!doctype html>
<html><head><meta charset="utf-8"><title>Returning to Kontinuum…</title></head>
<body style="font-family: system-ui; display:grid; place-items:center; height:100vh; background:#0B2B26; color:#DAF1DE;">
  <div>
    <h2>Returning to Kontinuum…</h2>
    <p>If the app doesn't open automatically, tap below:</p>
    <p><a href="${deeplink}" style="color:#DAF1DE; font-weight:800; font-size:18px;">Open Kontinuum</a></p>
    <script>setTimeout(function(){ window.location = ${JSON.stringify(
      deeplink
    )}; }, 200);</script>
  </div>
</body></html>`;
  res.status(200).type("html").send(html);
});

/** POST /plaid/webhook — real handler (auto-sync + removed) */
plaidRouter.post("/webhook", plaidWebhook);

export default plaidRouter;
