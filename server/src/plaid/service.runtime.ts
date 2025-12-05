// server/src/plaid/service.runtime.ts
import { plaid } from "./client.js";
import { prisma } from "../db/prisma.js";
import { env } from "../config/env.js";
import { encrypt, decrypt } from "../config/crypto.js";
import { logger } from "../config/logger.js";

// NEW: observability
import {
  syncDurationSeconds,
  syncAddedTotal,
  syncModifiedTotal,
  syncRemovedTotal,
  lastSyncTimestampSeconds,
} from "../observability/metrics.js";
import { track } from "../observability/analytics.js";

// Plaid v25+: string unions at type level
const COUNTRY_CODES = ["US"] as const;
const PRODUCT_LIST = ["transactions"] as const;

// --- Category helpers (unchanged) ---
const PFC_TO_HUMAN: Record<string, string> = {
  FOOD_AND_DRINK: "Food and Drink",
  TRAVEL: "Travel",
  GENERAL_MERCHANDISE: "Shopping",
  ENTERTAINMENT: "Entertainment",
  TRANSPORTATION: "Transportation",
  PERSONAL_CARE: "Personal Care",
  GENERAL_SERVICES: "Services",
  HEALTHCARE: "Healthcare",
  HOME_IMPROVEMENT: "Home",
  RENT_AND_UTILITIES: "Rent & Utilities",
  FINANCIAL: "Financial",
  INCOME: "Income",
  GOVERNMENT_AND_NON_PROFIT: "Government & Non-Profit",
  TRANSFER_OUT: "Transfer Out",
  TRANSFER_IN: "Transfer In",
  LOAN_PAYMENTS: "Loan Payments",
};

function toTopCategory(t: any): string {
  const p =
    t?.personal_finance_category?.primary ||
    t?.personal_finance_category_primary;
  if (p && PFC_TO_HUMAN[p]) return PFC_TO_HUMAN[p];
  const legacyTop =
    Array.isArray(t?.category) && t.category.length
      ? String(t.category[0])
      : undefined;
  return legacyTop ?? "Uncategorized";
}

// ---------- Link token ----------
export async function createLinkToken(opts: { userId: string }) {
  const req = {
    user: { client_user_id: opts.userId },
    client_name: "Kontinuum",
    products: PRODUCT_LIST as unknown as string[],
    country_codes: COUNTRY_CODES as unknown as string[],
    language: "en",
    ...(env.PLAID_REDIRECT_URI ? { redirect_uri: env.PLAID_REDIRECT_URI } : {}),
  };
  const res = await plaid.linkTokenCreate(req as any);
  return res.data.link_token;
}

// ---------- Exchange + persist (instrument link success/fail) ----------
export async function exchangePublicToken(params: {
  userId: string;
  publicToken: string;
  institutionName?: string;
}) {
  try {
    const { data } = await plaid.itemPublicTokenExchange({
      public_token: params.publicToken,
    });
    const accessTokenEnc = encrypt(data.access_token);

    const item = await prisma.bankItem.upsert({
      where: { plaidItemId: data.item_id },
      update: {
        userId: params.userId,
        institution: params.institutionName ?? undefined,
      },
      create: {
        userId: params.userId,
        plaidItemId: data.item_id,
        institution: params.institutionName ?? undefined,
      },
    });

    await prisma.plaidSecret.upsert({
      where: { itemId: item.id },
      update: { accessToken: accessTokenEnc },
      create: { itemId: item.id, accessToken: accessTokenEnc },
    });

    // analytics
    track("plaid_link_success", { userId: params.userId, itemId: item.id });

    return { itemId: item.id, plaidItemId: data.item_id };
  } catch (err: any) {
    track("plaid_link_fail", {
      userId: params.userId,
      reason: err?.response?.data || err?.message || String(err),
    });
    throw err;
  }
}

// ---------- Sandbox item create ----------
export async function createSandboxItem(params: {
  userId: string;
  institutionId?: string;
  institutionName?: string;
}) {
  const institution_id = params.institutionId ?? "ins_109508";
  const { data } = await plaid.sandboxPublicTokenCreate({
    institution_id,
    initial_products: PRODUCT_LIST as unknown as string[],
  } as any);

  const out = await exchangePublicToken({
    userId: params.userId,
    publicToken: data.public_token,
    institutionName: params.institutionName,
  });

  try {
    await subscribeItemWebhook(out.itemId);
  } catch (e) {
    logger.warn(
      { itemId: out.itemId, e },
      "Failed to subscribe webhook after sandbox item create"
    );
  }

  return out;
}

// ---------- Webhook subscribe ----------
export async function subscribeItemWebhook(itemId: string) {
  const item = await prisma.bankItem.findUnique({
    where: { id: itemId },
    include: { secret: true },
  });
  if (!item || !item.secret) throw new Error("Item or token not found");
  const access_token = decrypt(item.secret.accessToken);

  await plaid.itemWebhookUpdate({
    access_token,
    webhook: `${env.PUBLIC_BASE_URL}/plaid/webhook`,
  });
  return { ok: true };
}

// ---------- Transactions: request a refresh ----------
export async function transactionsRefresh(itemId: string) {
  const item = await prisma.bankItem.findUnique({
    where: { id: itemId },
    include: { secret: true },
  });
  if (!item || !item.secret) throw new Error("Item or token not found");
  const access_token = decrypt(item.secret.accessToken);

  await plaid.transactionsRefresh({ access_token });
  return { ok: true };
}

// ---------- Transactions sync (instrumented) ----------
export async function syncItem(itemId: string) {
  const item = await prisma.bankItem.findUnique({
    where: { id: itemId },
    include: { accounts: true, secret: true },
  });
  if (!item || !item.secret) throw new Error("Item or token not found");

  // Respect pause if present (works even if field absent on older client)
  const isPaused: boolean = !!(item as any)?.paused;
  if (isPaused) {
    logger.info({ itemId }, "Sync skipped: item paused");
    return { added: 0, modified: 0, removed: 0 };
  }

  // analytics: started
  track("sync_started", { itemId });

  const endTimer = syncDurationSeconds.startTimer();

  const access_token = decrypt(item.secret.accessToken);
  let cursor = item.cursor ?? undefined;
  let hasMore = true;
  const added: any[] = [];
  const modified: any[] = [];
  const removedIds: string[] = [];

  while (hasMore) {
    const { data } = await plaid.transactionsSync({ access_token, cursor });
    added.push(...data.added);
    modified.push(...data.modified);
    removedIds.push(...data.removed.map((r: any) => r.transaction_id));
    cursor = data.next_cursor;
    hasMore = data.has_more;
  }

  // Ensure we have accounts for this item
  if (!item.accounts?.length) {
    const { data } = await plaid.accountsGet({ access_token });
    await prisma.$transaction(
      data.accounts.map((a: any) =>
        prisma.bankAccount.upsert({
          where: { plaidAccountId: a.account_id },
          create: {
            plaidAccountId: a.account_id,
            itemId: item.id,
            name: a.name ?? a.official_name ?? null,
            mask: a.mask ?? null,
            subtype: a.subtype ?? null,
            officialName: a.official_name ?? null,
            currency: a.balances?.iso_currency_code ?? null,
          },
          update: {
            name: a.name ?? a.official_name ?? null,
            currency: a.balances?.iso_currency_code ?? null,
          },
        })
      )
    );
  }

  const accounts = await prisma.bankAccount.findMany({ where: { itemId } });
  const accIdMap = new Map<string, string>();
  accounts.forEach((a: { plaidAccountId: string; id: string }) =>
    accIdMap.set(a.plaidAccountId, a.id)
  );

  if (removedIds.length) {
    await prisma.bankTransaction.updateMany({
      where: { id: { in: removedIds } },
      data: { removed: true },
    });
  }

  const upserts = [...added, ...modified].flatMap((t: any) => {
    const accountId = accIdMap.get(t.account_id);
    if (!accountId) return [];
    const nt = {
      id: t.transaction_id,
      accountId,
      isoCurrency: t.iso_currency_code ?? t.unofficial_currency_code ?? null,
      amount: Number(t.amount),
      authorizedDate: t.authorized_date ? new Date(t.authorized_date) : null,
      postedDate: t.date ? new Date(t.date) : null,
      pending: !!t.pending,
      name: t.name ?? null,
      merchantName: t.merchant_name ?? null,
      categoryPath: [toTopCategory(t)],
      pendingTransactionId: t.pending_transaction_id ?? null,
      raw: t,
    };

    return [
      prisma.bankTransaction.upsert({
        where: { id: nt.id },
        create: nt,
        update: { ...nt, removed: false },
      }),
    ];
  });

  if (upserts.length) await prisma.$transaction(upserts);

  // Hide pending dupes once posted appears
  const postedWithPending = [...added, ...modified]
    .filter((t: any) => !t.pending && t.pending_transaction_id)
    .map((t: any) => t.pending_transaction_id);
  if (postedWithPending.length) {
    await prisma.bankTransaction.updateMany({
      where: { id: { in: postedWithPending } },
      data: { removed: true },
    });
  }

  // Update cursor (typed)
  await prisma.bankItem.update({
    where: { id: item.id },
    data: { cursor: cursor ?? null },
  });

  // Stamp lastSyncAt best-effort (avoids TS error if Prisma client doesn't have the field yet)
  try {
    await (prisma as any).bankItem.update({
      where: { id: item.id },
      data: { lastSyncAt: new Date() },
    });
  } catch {
    // Column not present or client behind — ignore silently.
  }

  // Prom metrics
  syncAddedTotal.inc(added.length);
  syncModifiedTotal.inc(modified.length);
  syncRemovedTotal.inc(removedIds.length);
  lastSyncTimestampSeconds.set({ itemId }, Date.now() / 1000);

  // Finish timer + analytics
  endTimer();
  track("sync_completed", {
    itemId,
    added: added.length,
    modified: modified.length,
    removed: removedIds.length,
  });

  logger.info(
    {
      itemId,
      added: added.length,
      modified: modified.length,
      removed: removedIds.length,
    },
    "Plaid sync complete"
  );
  return {
    added: added.length,
    modified: modified.length,
    removed: removedIds.length,
  };
}
