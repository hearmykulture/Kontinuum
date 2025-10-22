import { prisma } from '../db/prisma.js';
import { logger } from '../config/logger.js';
import { syncItem } from './service.runtime.js';

/**
 * Run a one-off catch-up sync for items whose updatedAt is older than `maxAgeHours`.
 * We read scheduler tunables from process.env to avoid env type drift.
 */
export async function runCatchupNow(
  maxAgeHours: number,
  concurrency?: number,
) {
  const conc = Number(concurrency ?? (process.env.CATCHUP_CONCURRENCY ?? 3));
  const cutoff = new Date(Date.now() - maxAgeHours * 60 * 60 * 1000);

  // Pull ids + timestamps, then filter in memory (avoids Prisma "updatedAt" where issues)
  const items = await prisma.bankItem.findMany({
    select: { id: true, updatedAt: true },
  });

  const stale = items.filter((i) => !i.updatedAt || i.updatedAt < cutoff);

  logger.info(
    { scanned: items.length, stale: stale.length, cutoff: cutoff.toISOString() },
    'Catch-up scan complete',
  );

  const failures: Array<{ id: string; error: string }> = [];
  let completed = 0;

  await runWithConcurrency(stale, conc, async (item) => {
    try {
      await syncItem(item.id);
      completed++;
    } catch (err: any) {
      const msg = String(err?.message ?? err);
      failures.push({ id: item.id, error: msg });
      logger.error({ err, itemId: item.id }, 'Catch-up sync failed');
    }
  });

  logger.info(
    { cutoff: cutoff.toISOString(), queued: stale.length, completed, failures: failures.length },
    'Catch-up finished',
  );

  return {
    ok: true,
    runAt: new Date().toISOString(),
    maxAgeHours,
    cutoff: cutoff.toISOString(),
    scanned: items.length,
    queued: stale.length,
    completed,
    failures,
  };
}

type ItemLite = { id: string };

async function runWithConcurrency<T extends ItemLite>(
  arr: T[],
  limit: number,
  worker: (item: T, idx: number) => Promise<void>,
) {
  if (!Number.isFinite(limit) || limit <= 0) limit = 1;
  let next = 0;
  const workers = new Array(Math.min(limit, arr.length)).fill(0).map(async () => {
    while (true) {
      const idx = next++;
      if (idx >= arr.length) break;
      await worker(arr[idx], idx);
    }
  });
  await Promise.all(workers);
}

let schedulerStarted = false;

/** Starts a daily UTC scheduler if ENABLE_CATCHUP_CRON=true */
export function startCatchupScheduler() {
  if (schedulerStarted) return;
  const enabled = String(process.env.ENABLE_CATCHUP_CRON ?? '').toLowerCase() === 'true';
  if (!enabled) {
    logger.info('Catch-up scheduler disabled (set ENABLE_CATCHUP_CRON=true to enable).');
    return;
  }
  schedulerStarted = true;

  const hourUTC = Number(process.env.CATCHUP_CRON_HOUR_UTC ?? 9);
  const maxAge = Number(process.env.CATCHUP_MAX_AGE_HOURS ?? 24);

  scheduleDailyAtUTCHour(hourUTC, async () => {
    try {
      await runCatchupNow(maxAge);
    } catch (err) {
      logger.error({ err }, 'Daily catch-up job failed');
    }
  });

  logger.info({ hourUTC, maxAge }, 'Catch-up scheduler started');
}

function scheduleDailyAtUTCHour(hour: number, fn: () => Promise<void>) {
  const now = new Date();
  const next = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), hour, 0, 0, 0),
  );
  if (next <= now) next.setUTCDate(next.getUTCDate() + 1);
  const delay = next.getTime() - now.getTime();

  setTimeout(() => {
    fn().finally(() => {});
    setInterval(fn, 24 * 60 * 60 * 1000);
  }, delay);
}
