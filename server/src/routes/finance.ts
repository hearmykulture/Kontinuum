// server/src/routes/finance.ts
import { Router } from 'express';
import { prisma } from '../db/prisma.js';
import { decrypt } from '../config/crypto.js';
import { plaid } from '../plaid/client.js';

export const financeRouter = Router();

// Loosened handles for models your generated client may not expose yet
const prismaAny = prisma as any;
const pg = prisma as unknown as {
  budgetGoal: {
    upsert(args: any): Promise<any>;
    findMany(args: any): Promise<any[]>;
  };
};

/**
 * GET /finance/status?userId=...
 * For “Synced • <timeago>”: returns latest BankItem.updatedAt for the user.
 */
financeRouter.get('/status', async (req, res, next) => {
  try {
    const userId = String(req.query.userId || '');
    if (!userId) return res.status(400).json({ error: 'userId is required' });

    const row = await prisma.bankItem.findFirst({
      where: { userId },
      orderBy: { updatedAt: 'desc' },
      select: { updatedAt: true },
    });

    res.json({ lastSyncedAt: row?.updatedAt ?? null });
  } catch (e) {
    next(e);
  }
});

/**
 * GET /finance/accounts?userId=...&includeBalances=true|false
 */
financeRouter.get('/accounts', async (req, res, next) => {
  try {
    const userId = String(req.query.userId || '');
    const includeBalances = String(req.query.includeBalances || 'false') === 'true';
    if (!userId) return res.status(400).json({ error: 'userId is required' });

    // 1) Get accounts for this user (via the BankItem relation)
    const dbAccounts = await prisma.bankAccount.findMany({
      where: { item: { userId } },
      select: {
        id: true,
        itemId: true,
        plaidAccountId: true,
        name: true,
        mask: true,
        subtype: true,
        officialName: true,
        currency: true,
      },
      orderBy: { id: 'asc' },
    });

    // 2) If balances requested, look up Plaid secrets per item and call AccountsGet once per item.
    const balanceByPlaidAccountId: Record<string, number | null> = {};
    if (includeBalances && dbAccounts.length) {
      const itemIds = Array.from(new Set(dbAccounts.map((a) => a.itemId)));

      // Use relaxed handle so TS doesn't complain if model isn't in generated types
      const secrets: Array<{ itemId: string; accessToken: string | null }> = await prismaAny.plaidSecret.findMany({
        where: { itemId: { in: itemIds } },
        select: { itemId: true, accessToken: true },
      });

      // Map: itemId -> decrypted access token
      const tokenByItemId = new Map<string, string>();
      for (const s of secrets) {
        const enc = s.accessToken;
        if (enc) {
          try {
            tokenByItemId.set(s.itemId, decrypt(enc));
          } catch {
            // bad token or key; skip balances for this item
          }
        }
      }

      // Call Plaid for each item’s balances
      for (const [itemId, access_token] of tokenByItemId.entries()) {
        try {
          const { data } = await plaid.accountsGet({ access_token });
          for (const acct of data.accounts) {
            const cur = acct?.balances?.current;
            balanceByPlaidAccountId[acct.account_id] =
              typeof cur === 'number' ? cur : cur == null ? null : Number(cur);
          }
        } catch (e) {
          // One bad item shouldn't fail the whole endpoint
          // eslint-disable-next-line no-console
          console.warn(`accountsGet failed for item ${itemId}:`, e);
        }
      }
    }

    const result = dbAccounts.map((a) => ({
      id: a.id,
      plaidAccountId: a.plaidAccountId,
      itemId: a.itemId,
      name: a.name ?? a.officialName ?? null,
      mask: a.mask,
      subtype: a.subtype,
      currency: a.currency,
      balance: balanceByPlaidAccountId[a.plaidAccountId] ?? null,
    }));

    res.json({ accounts: result });
  } catch (e) {
    next(e);
  }
});

/**
 * GET /finance/transactions?userId=...&accountId=...&since=YYYY-MM-DD&until=YYYY-MM-DD&limit=50&includeRemoved=false
 */
financeRouter.get('/transactions', async (req, res, next) => {
  try {
    const userId = String(req.query.userId || '');
    if (!userId) return res.status(400).json({ error: 'userId is required' });

    const accountId = req.query.accountId ? String(req.query.accountId) : undefined;
    const since = req.query.since ? new Date(String(req.query.since)) : undefined;
    const until = req.query.until ? new Date(String(req.query.until)) : undefined;
    const limit = Number(req.query.limit || 50);
    const includeRemoved = String(req.query.includeRemoved || 'false') === 'true';

    const where: any = {
      account: { item: { userId } },
      ...(accountId ? { accountId } : {}),
      ...(!includeRemoved ? { removed: false } : {}),
    };
    if (since || until) {
      where.postedDate = {};
      if (since) where.postedDate.gte = since;
      if (until) where.postedDate.lte = until;
    }

    const txns = await prisma.bankTransaction.findMany({
      where,
      orderBy: [{ postedDate: 'desc' }, { id: 'desc' }],
      take: Math.max(1, Math.min(200, limit)),
      include: { account: { select: { subtype: true } } },
    });

    const out = txns.map((t) => {
      const amt = Number(t.amount);
      const isCredit = (t.account?.subtype || '').toLowerCase().includes('credit');
      const isExpense = isCredit ? amt > 0 : amt < 0;

      return {
        id: t.id,
        accountId: t.accountId,
        date: t.postedDate ?? t.authorizedDate ?? null,
        amount: amt,
        amountCents: Math.round((isFinite(amt) ? amt : 0) * 100),
        isExpense,
        status: t.removed ? 'removed' : t.pending ? 'pending' : 'posted',
        name: t.name,
        merchant: t.merchantName,
        categoryPath: t.categoryPath ?? [],
        pendingTransactionId: t.pendingTransactionId ?? null,
        currency: t.isoCurrency ?? null,
      };
    });

    res.json({ transactions: out });
  } catch (e) {
    next(e);
  }
});

/**
 * GET /finance/cashflow?userId=...&from=YYYY-MM-DD&to=YYYY-MM-DD
 */
financeRouter.get('/cashflow', async (req, res, next) => {
  try {
    const userId = String(req.query.userId || '');
    if (!userId) return res.status(400).json({ error: 'userId is required' });

    const from = req.query.from ? new Date(String(req.query.from)) : undefined;
    const to = req.query.to ? new Date(String(req.query.to)) : undefined;

    const where: any = { removed: false, account: { item: { userId } } };
    if (from || to) {
      where.postedDate = {};
      if (from) where.postedDate.gte = from;
      if (to) where.postedDate.lte = to;
    }

    const txns = await prisma.bankTransaction.findMany({
      where,
      select: { amount: true, account: { select: { subtype: true } }, raw: true },
      take: 10000,
    });

    let inflow = 0;
    let outflow = 0;

    for (const t of txns) {
      const amt = Number(t.amount || 0);
      const isCredit = (t.account?.subtype || '').toLowerCase().includes('credit');
      const pfc = (t as any)?.raw?.personal_finance_category?.primary as string | undefined;
      const isPaymentOrTransfer = (pfc && /(TRANSFER|LOAN|INCOME)/.test(pfc)) || false;

      let signed = amt;
      if (isCredit) signed = isPaymentOrTransfer ? Math.abs(amt) : -Math.abs(amt);

      if (signed < 0) outflow += Math.abs(signed);
      else inflow += signed;
    }

    res.json({ from: from ?? null, to: to ?? null, inflow, outflow, net: inflow - outflow });
  } catch (e) {
    next(e);
  }
});

/**
 * GET /finance/cashflow/by-category?userId=...&from=YYYY-MM-DD&to=YYYY-MM-DD
 */
financeRouter.get('/cashflow/by-category', async (req, res, next) => {
  try {
    const userId = String(req.query.userId || '');
    if (!userId) return res.status(400).json({ error: 'userId is required' });

    const from = req.query.from ? new Date(String(req.query.from)) : undefined;
    const to = req.query.to ? new Date(String(req.query.to)) : undefined;

    const where: any = { removed: false, account: { item: { userId } } };
    if (from || to) {
      where.postedDate = {};
      if (from) where.postedDate.gte = from;
      if (to) where.postedDate.lte = to;
    }

    const txns = await prisma.bankTransaction.findMany({
      where,
      select: {
        amount: true,
        categoryPath: true,
        account: { select: { subtype: true } },
        raw: true,
      },
      orderBy: { postedDate: 'desc' },
      take: 5000,
    });

    type Row = { category: string; spend: number; income: number; net: number };
    const byCat = new Map<string, Row>();

    for (const t of txns) {
      const amt = Number(t.amount || 0);
      const isCredit = (t.account?.subtype || '').toLowerCase().includes('credit');
      const pfc = (t as any)?.raw?.personal_finance_category?.primary as string | undefined;
      const isPaymentOrTransfer = (pfc && /(TRANSFER|LOAN|INCOME)/.test(pfc)) || false;

      let signed = amt;
      if (isCredit) signed = isPaymentOrTransfer ? Math.abs(amt) : -Math.abs(amt);

      const cat = (t.categoryPath && t.categoryPath.length ? t.categoryPath[0] : 'Uncategorized')!;
      if (!byCat.has(cat)) byCat.set(cat, { category: cat, spend: 0, income: 0, net: 0 });

      const row = byCat.get(cat)!;
      if (signed < 0) row.spend += Math.abs(signed);
      else row.income += signed;
      row.net += signed;
    }

    const rows: Row[] = Array.from(byCat.values()).sort((a: Row, b: Row) => b.spend - a.spend);
    res.json({ rows });
  } catch (e) {
    next(e);
  }
});

/**
 * PUT /finance/budgets
 * Body: { userId: string, month: "YYYY-MM", items: [{ category: string, amount: number }] }
 */
financeRouter.put('/budgets', async (req, res, next) => {
  try {
    const { userId, month, items } = req.body || {};
    if (!userId || !month || !Array.isArray(items)) {
      return res.status(400).json({ error: 'userId, month (YYYY-MM), and items[] are required' });
    }
    const monthDate = new Date(`${month}-01T00:00:00.000Z`);

    // Use callback form so types match (avoids PrismaPromise[] requirement)
    await prisma.$transaction(async (tx) => {
      for (const it of items as any[]) {
        await (tx as any).budgetGoal.upsert({
          where: {
            userId_month_category: {
              userId,
              month: monthDate,
              category: String(it.category || 'Uncategorized'),
            },
          },
          create: {
            userId,
            month: monthDate,
            category: String(it.category || 'Uncategorized'),
            amount: Number(it.amount || 0),
          },
          update: {
            amount: Number(it.amount || 0),
          },
        });
      }
    });

    const saved = await pg.budgetGoal.findMany({
      where: { userId, month: monthDate },
      orderBy: { category: 'asc' },
    });
    res.json({ budgets: saved.map((b: any) => ({ ...b, amount: Number(b.amount) })) });
  } catch (e) {
    next(e);
  }
});

/**
 * GET /finance/budgets?userId=...&month=YYYY-MM
 */
financeRouter.get('/budgets', async (req, res, next) => {
  try {
    const userId = String(req.query.userId || '');
    const month = String(req.query.month || '');
    if (!userId || !month) return res.status(400).json({ error: 'userId and month=YYYY-MM are required' });

    const monthDate = new Date(`${month}-01T00:00:00.000Z`);
    const rows = await pg.budgetGoal.findMany({
      where: { userId, month: monthDate },
      orderBy: { category: 'asc' },
    });
    res.json({ budgets: rows.map((b: any) => ({ ...b, amount: Number(b.amount) })) });
  } catch (e) {
    next(e);
  }
});

/**
 * GET /finance/budget-vs-actual?userId=...&month=YYYY-MM
 */
financeRouter.get('/budget-vs-actual', async (req, res, next) => {
  try {
    const userId = String(req.query.userId || '');
    const month = String(req.query.month || '');
    if (!userId || !month) return res.status(400).json({ error: 'userId and month=YYYY-MM are required' });

    const monthDate = new Date(`${month}-01T00:00:00.000Z`);
    const from = monthDate;
    const to = new Date(new Date(from).setUTCMonth(from.getUTCMonth() + 1));

    const budgets: any[] = await pg.budgetGoal.findMany({ where: { userId, month: monthDate } });

    const txns = await prisma.bankTransaction.findMany({
      where: {
        removed: false,
        account: { item: { userId } },
        postedDate: { gte: from, lt: to },
      },
      select: {
        amount: true,
        categoryPath: true,
        name: true,
        account: { select: { subtype: true } },
        raw: true,
      },
      take: 10000,
    });

    const actualByCat = new Map<string, number>();
    for (const t of txns) {
      const amt = Number(t.amount || 0);
      const isCredit = (t.account?.subtype || '').toLowerCase().includes('credit');
      const pfc = (t as any)?.raw?.personal_finance_category?.primary as string | undefined;
      const isPaymentOrTransfer =
        (pfc && /(TRANSFER|LOAN|INCOME)/.test(pfc)) || /PAYMENT|CREDIT/i.test(String(t.name || ''));

      let signed = amt;
      if (isCredit) signed = isPaymentOrTransfer ? Math.abs(amt) : -Math.abs(amt);

      if (signed < 0) {
        const cat = (t.categoryPath && t.categoryPath.length ? t.categoryPath[0] : 'Uncategorized')!;
        actualByCat.set(cat, (actualByCat.get(cat) || 0) + Math.abs(signed));
      }
    }

    type BVRow = { category: string; budget: number; actual: number; variance: number; pct: number | null };

    const cats = new Set<string>([...budgets.map((b) => b.category), ...Array.from(actualByCat.keys())]);

    const rows: BVRow[] = Array.from(cats)
      .map<BVRow>((category) => {
        const budget = Number(budgets.find((b) => b.category === category)?.amount ?? 0);
        const actual = Number(actualByCat.get(category) ?? 0);
        const variance = budget - actual;
        const pct = budget > 0 ? actual / budget : null;
        return { category, budget, actual, variance, pct };
      })
      .sort((a: BVRow, b: BVRow) => b.actual - a.actual);

    res.json({ month, from, to, rows });
  } catch (e) {
    next(e);
  }
});

export default financeRouter;
