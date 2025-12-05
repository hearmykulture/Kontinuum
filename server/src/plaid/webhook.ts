import type { Request, Response } from 'express';
import { prisma } from '../db/prisma.js';
import { logger } from '../config/logger.js';
import { getService } from './routes.js';

// Signature verification
import { verifyPlaidWebhookSignature } from './verify.js';

// Observability
import {
  webhooksReceivedTotal,
  webhooksErrorsTotal,
  webhookDurationSeconds,
} from '../observability/metrics.js';

type PlaidWebhookBody = {
  webhook_type?: string;
  webhook_code?: string;
  item_id?: string;
  environment?: string;
  removed_transactions?: string[];
};

// prevent duplicate overlapping syncs per item (bursty webhooks)
const inflight = new Set<string>();

export async function plaidWebhook(req: Request, res: Response) {
  // ✅ Verify signature first (dev: can be disabled via env switch)
  const ok = await verifyPlaidWebhookSignature(req);
  if (!ok) {
    logger.warn({ headers: req.headers }, 'Invalid Plaid webhook signature');
    return res.status(401).json({ error: 'unauthorized' });
  }

  const body = (req.body ?? {}) as PlaidWebhookBody;
  const { webhook_type, webhook_code, item_id, removed_transactions } = body;

  // Record receipt after verification (labels uppercased for consistency)
  webhooksReceivedTotal.inc({
    type: (webhook_type || 'unknown').toUpperCase(),
    code: (webhook_code || 'unknown').toUpperCase(),
  });

  // ACK right away so Plaid doesn't retry
  res.status(200).json({ ok: true });

  // Measure only the background work duration
  const stopTimer = webhookDurationSeconds.startTimer();

  if (!item_id) {
    logger.warn({ body }, 'Plaid webhook missing item_id');
    stopTimer();
    return;
  }

  try {
    // Our DB stores Plaid's item_id in BankItem.plaidItemId
    const item = await prisma.bankItem.findUnique({
      where: { plaidItemId: item_id },
    });

    if (!item) {
      logger.warn({ item_id }, 'Plaid webhook for unknown item');
      stopTimer();
      return;
    }

    // If Plaid is telling us transactions were removed, mark them removed quickly
    if (
      webhook_type === 'TRANSACTIONS' &&
      webhook_code === 'TRANSACTIONS_REMOVED' &&
      Array.isArray(removed_transactions) &&
      removed_transactions.length > 0
    ) {
      await prisma.bankTransaction.updateMany({
        where: { id: { in: removed_transactions } },
        data: { removed: true },
      });
    }

    // Respect pause (older clients may not have this column; cast-any is fine)
    const paused: boolean = !!(item as any)?.paused;
    if (paused) {
      logger.info({ itemId: item.id, webhook_code }, 'Webhook received; item paused → skipping sync');
      stopTimer();
      return;
    }

    // De-dup overlapping syncs for the same item
    if (inflight.has(item.id)) {
      stopTimer();
      return;
    }
    inflight.add(item.id);

    // Run the sync off the request lifecycle
    queueMicrotask(async () => {
      try {
        const { syncItem } = await getService();
        const out = await syncItem(item.id);
        logger.info({ itemId: item.id, webhook_code, ...out }, 'Webhook-triggered sync complete');
      } catch (err) {
        webhooksErrorsTotal.inc();
        logger.error({ err, itemId: item.id }, 'syncItem failed from webhook');
      } finally {
        inflight.delete(item.id);
        stopTimer();
      }
    });
  } catch (err) {
    webhooksErrorsTotal.inc();
    logger.error({ err, item_id }, 'Error handling Plaid webhook');
    stopTimer();
  }
}

export default plaidWebhook;
