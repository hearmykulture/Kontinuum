import { Router } from 'express';
import { prisma } from '../db/prisma.js';

const router = Router();

/** GET /finance/linked_accounts?userId=demo */
router.get('/linked_accounts', async (req, res, next) => {
  try {
    const userId = String(req.query.userId ?? '');
    if (!userId) return res.status(400).json({ error: 'userId is required' });

    const items = await prisma.bankItem.findMany({
      where: { userId },
      include: {
        accounts: {
          select: { id: true, name: true, mask: true, subtype: true, currency: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    res.json({
      items: items.map((i) => ({
        id: i.id,
        plaidItemId: i.plaidItemId,
        institution: i.institution,
        paused: !!(i as any)?.paused,                // cast → compiles before migration
        lastSyncAt: (i as any)?.lastSyncAt ?? null,  // cast → compiles before migration
        accounts: i.accounts,
      })),
    });
  } catch (e) {
    next(e);
  }
});

/** POST /finance/items/:itemId/pause { paused: boolean } */
router.post('/items/:itemId/pause', async (req, res, next) => {
  try {
    const { itemId } = req.params;
    const { paused } = (req.body ?? {}) as { paused?: boolean };
    if (typeof paused !== 'boolean') {
      return res.status(400).json({ error: 'paused boolean is required' });
    }
    // use any so TS doesn’t require the field at compile time
    await (prisma as any).bankItem.update({
      where: { id: itemId },
      data: { paused },
    });
    res.json({ ok: true, paused });
  } catch (e) {
    next(e);
  }
});

/** DELETE /finance/items/:itemId — unlink + cascade */
router.delete('/items/:itemId', async (req, res, next) => {
  try {
    const { itemId } = req.params;
    await prisma.bankItem.delete({ where: { id: itemId } });
    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

/** GET /finance/settings/features?userId=demo */
router.get('/settings/features', async (req, res, next) => {
  try {
    const userId = String(req.query.userId ?? '');
    if (!userId) return res.status(400).json({ error: 'userId is required' });

    let s: any = null;
    try {
      s = await (prisma as any).userSettings.findUnique({ where: { userId } });
    } catch {
      // model not generated yet — fall back to defaults
    }

    res.json({
      bankSyncEnabled: s?.bankSyncEnabled ?? true,
      consentVersion: s?.consentVersion ?? null,
      consentAcceptedAt: s?.consentAcceptedAt ?? null,
    });
  } catch (e) {
    next(e);
  }
});

/** POST /finance/settings/features/bank_sync { userId, enabled } */
router.post('/settings/features/bank_sync', async (req, res, next) => {
  try {
    const { userId, enabled } = (req.body ?? {}) as { userId?: string; enabled?: boolean };
    if (!userId || typeof enabled !== 'boolean') {
      return res.status(400).json({ error: 'userId and enabled are required' });
    }
    try {
      await (prisma as any).userSettings.upsert({
        where: { userId },
        create: { userId, bankSyncEnabled: enabled },
        update: { bankSyncEnabled: enabled },
      });
      res.json({ ok: true, enabled });
    } catch (err) {
      // table/model missing → nudge to migrate but still respond cleanly
      res.status(409).json({
        error: 'Feature store not ready',
        message: 'Run Prisma migrate/generate to create UserSettings.',
      });
    }
  } catch (e) {
    next(e);
  }
});

/** POST /finance/consent/bank_sync { userId, version } */
router.post('/consent/bank_sync', async (req, res, next) => {
  try {
    const { userId, version } = (req.body ?? {}) as { userId?: string; version?: string };
    if (!userId) return res.status(400).json({ error: 'userId is required' });

    try {
      await (prisma as any).userSettings.upsert({
        where: { userId },
        create: { userId, consentVersion: version ?? 'v1', consentAcceptedAt: new Date() },
        update: { consentVersion: version ?? 'v1', consentAcceptedAt: new Date() },
      });
      res.json({ ok: true });
    } catch {
      res.status(409).json({
        error: 'Feature store not ready',
        message: 'Run Prisma migrate/generate to create UserSettings.',
      });
    }
  } catch (e) {
    next(e);
  }
});

export default router;
