// server/src/observability/analytics.ts
import { logger } from '../config/logger.js';
import {
  plaidLinkSuccessTotal,
  plaidLinkFailTotal,
  syncStartedTotal,
  syncCompletedTotal,
} from './metrics.js';

export type AnalyticsEvent =
  | 'plaid_link_success'
  | 'plaid_link_fail'
  | 'sync_started'
  | 'sync_completed'
  | 'auto_category_hit';

export function track(event: AnalyticsEvent, props: Record<string, any> = {}) {
  // Lightweight structured event log
  logger.info({ event, ...props }, 'analytics');

  // Mirror a few events into counters
  switch (event) {
    case 'plaid_link_success':
      plaidLinkSuccessTotal.inc();
      break;
    case 'plaid_link_fail':
      plaidLinkFailTotal.inc();
      break;
    case 'sync_started':
      syncStartedTotal.inc();
      break;
    case 'sync_completed':
      syncCompletedTotal.inc();
      break;
    default:
      break;
  }
}
