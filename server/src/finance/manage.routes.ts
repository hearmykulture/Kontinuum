// server/src/finance/manage.routes.ts
import { Router } from 'express';
import { prisma } from '../db/prisma.js';

const router = Router();

/**
 * GET /finance/linked_accounts?userId=demo
 * Returns { items: [...] } with paused + lastSyncAt included in the JSON,
 * but we avoid putting `paused` in a Prisma `select` so TS stays happy even
 * if your generated client is behind.
 */
router.get('/linked_accounts', async (req, res, next) => {
  try {
    const userId = String(req.query.userId ?? '');
    if (!userId) return res.status(400).json({ error: 'userId is required' });

    // Don’t select paused explicitly—just include accounts and read it via `as any`.
    const rawItems = await prisma.bankItem.findMany({
      where: { userId },
      include: {
        accounts: {
          select: {
            id: true,
            name: true,
            mask: true,
            subtype: true,
            currency: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const items = rawItems.map((it) => ({
      id: it.id,
      plaidItemId: it.plaidItemId,
      institution: it.institution,
      paused: Boolean((it as any).paused),          // <- read via any
      lastSyncAt: (it as any).lastSyncAt ?? null,   // <- read via any
      accounts: it.accounts,
    }));

    res.json({ items });
  } catch (e) {
    next(e);
  }
});

/**
 * POST /finance/settings/features/bank_sync
 * Body: { userId: string, enabled: boolean }
 *
 * Uses raw SQL against "UserSettings" so we don’t care about Prisma’s model delegate name.
 */
router.post('/settings/features/bank_sync', async (req, res, next) => {
  try {
    const { userId, enabled } = (req.body ?? {}) as {
      userId?: string;
      enabled?: boolean;
    };
    if (!userId || typeof enabled !== 'boolean') {
      return res.status(400).json({ error: 'userId and enabled boolean are required' });
    }

    const id = `us_${userId}`;

    // Ensure row exists
    await prisma.$executeRawUnsafe(
      `
      INSERT INTO "UserSettings" ("id","userId","features","createdAt","updatedAt")
      VALUES ($1, $2, COALESCE('{}'::jsonb,'{}'::jsonb), now(), now())
      ON CONFLICT ("userId") DO UPDATE
      SET "updatedAt" = now();
      `,
      id,
      userId,
    );

    // Upsert the flag in features JSON
    await prisma.$executeRawUnsafe(
      `
      UPDATE "UserSettings"
      SET "features" = COALESCE("features",'{}'::jsonb) || jsonb_build_object('bank_sync_enabled', $1),
          "updatedAt" = now()
      WHERE "userId" = $2;
      `,
      enabled,
      userId,
    );

    res.json({ ok: true, enabled });
  } catch (e) {
    next(e);
  }
});

/**
 * POST /finance/items/:itemId/pause
 * Body: { paused: boolean }
 *
 * Use `as any` for the update data to bypass Prisma’s generated types if they
 * don’t yet include the `paused` column.
 */
router.post('/items/:itemId/pause', async (req, res, next) => {
  try {
    const itemId = String(req.params.itemId);
    const { paused } = (req.body ?? {}) as { paused?: boolean };
    if (typeof paused !== 'boolean') {
      return res.status(400).json({ error: 'paused boolean is required' });
    }

    const clientAny = prisma as any;
    await clientAny.bankItem.update({
      where: { id: itemId },
      data: { paused }, // typed as any via the client above
      select: { id: true }, // don’t select paused here to keep TS quiet
    });

    res.json({ ok: true, paused });
  } catch (e: any) {
    if (e?.code === 'P2025') return res.status(404).json({ error: 'Not Found' });
    next(e);
  }
});

/**
 * POST /finance/items/:itemId/unlink
 * Deletes the item and its secret. Accounts/transactions cascade via FK.
 */
router.post('/items/:itemId/unlink', async (req, res, next) => {
  try {
    const itemId = String(req.params.itemId);

    await prisma.plaidSecret.deleteMany({ where: { itemId } });
    await prisma.bankItem.delete({ where: { id: itemId } });

    res.json({ ok: true });
  } catch (e: any) {
    if (e?.code === 'P2025') return res.status(404).json({ error: 'Not Found' });
    next(e);
  }
});

export default router;
