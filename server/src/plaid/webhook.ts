import type { Request, Response } from 'express';
import { prisma } from '../db/prisma.js';
import { logger } from '../config/logger.js';
import { getService } from './routes.js';

type PlaidWebhookBody = {
  webhook_type?: string;
  webhook_code?: string;
  item_id?: string;
  environment?: string;
  removed_transactions?: string[];
};

const inflight = new Set<string>();

export async function plaidWebhook(req: Request, res: Response) {
  const body = (req.body ?? {}) as PlaidWebhookBody;
  const { webhook_type, webhook_code, item_id, removed_transactions } = body;

  res.status(200).json({ ok: true });

  if (!item_id) {
    logger.warn({ body }, 'Plaid webhook missing item_id');
    return;
  }

  try {
    const item = await prisma.bankItem.findUnique({
      where: { plaidItemId: item_id },
    });

    if (!item) {
      logger.warn({ item_id }, 'Plaid webhook for unknown item');
      return;
    }

    if (
      webhook_type === 'TRANSACTIONS' &&
      webhook_code === 'TRANSACTIONS_REMOVED' &&
      Array.isArray(removed_transactions) &&
      removed_transactions.length
    ) {
      await prisma.bankTransaction.updateMany({
        where: { id: { in: removed_transactions } },
        data: { removed: true },
      });
    }

    const paused: boolean = !!(item as any)?.paused;
    if (paused) {
      logger.info({ itemId: item.id, webhook_code }, 'Webhook received; item paused → not syncing');
      return;
    }

    if (inflight.has(item.id)) return;
    inflight.add(item.id);

    queueMicrotask(async () => {
      try {
        const { syncItem } = await getService();
        const out = await syncItem(item.id);
        logger.info({ itemId: item.id, webhook_code, ...out }, 'Webhook-triggered sync complete');
      } catch (err) {
        logger.error({ err, itemId: item.id }, 'syncItem failed from webhook');
      } finally {
        inflight.delete(item.id);
      }
    });
  } catch (err: any) {
    logger.error({ err, item_id }, 'Error handling Plaid webhook');
  }
}
