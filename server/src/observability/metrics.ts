// server/src/observability/metrics.ts
import client from 'prom-client';

export const registry = new client.Registry();

// Collect default Node/Process metrics with a prefix
client.collectDefaultMetrics({
  register: registry,
  prefix: 'kontinuum_',
});

// ---------- Counters ----------
export const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests processed',
  labelNames: ['method', 'route', 'status'],
  registers: [registry],
});

export const plaidLinkSuccessTotal = new client.Counter({
  name: 'plaid_link_success_total',
  help: 'Number of successful Plaid Link exchanges',
  registers: [registry],
});

export const plaidLinkFailTotal = new client.Counter({
  name: 'plaid_link_fail_total',
  help: 'Number of failed Plaid Link exchanges',
  registers: [registry],
});

export const syncStartedTotal = new client.Counter({
  name: 'plaid_sync_started_total',
  help: 'Number of Plaid syncs started',
  registers: [registry],
});

export const syncCompletedTotal = new client.Counter({
  name: 'plaid_sync_completed_total',
  help: 'Number of Plaid syncs completed successfully',
  registers: [registry],
});

export const syncAddedTotal = new client.Counter({
  name: 'plaid_sync_added_total',
  help: 'Total transactions added across syncs',
  registers: [registry],
});

export const syncModifiedTotal = new client.Counter({
  name: 'plaid_sync_modified_total',
  help: 'Total transactions modified across syncs',
  registers: [registry],
});

export const syncRemovedTotal = new client.Counter({
  name: 'plaid_sync_removed_total',
  help: 'Total transactions removed across syncs',
  registers: [registry],
});

export const webhooksReceivedTotal = new client.Counter({
  name: 'plaid_webhooks_received_total',
  help: 'Number of Plaid webhooks received',
  labelNames: ['type', 'code'],
  registers: [registry],
});

export const webhooksErrorsTotal = new client.Counter({
  name: 'plaid_webhooks_errors_total',
  help: 'Number of Plaid webhook handler errors',
  registers: [registry],
});

// ---------- Histograms ----------
export const syncDurationSeconds = new client.Histogram({
  name: 'plaid_sync_duration_seconds',
  help: 'Duration of a Plaid sync in seconds',
  buckets: [0.25, 0.5, 1, 2, 5, 10, 20, 40, 80],
  registers: [registry],
});

export const webhookDurationSeconds = new client.Histogram({
  name: 'plaid_webhook_handler_duration_seconds',
  help: 'Duration of Plaid webhook handling in seconds',
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2, 5],
  registers: [registry],
});

// ---------- Gauges ----------
export const lastSyncTimestampSeconds = new client.Gauge({
  name: 'plaid_last_sync_timestamp_seconds',
  help: 'Epoch seconds of last successful sync per item',
  labelNames: ['itemId'],
  registers: [registry],
});

// ---------- Express middleware (optional but handy) ----------
export function metricsHttpMiddleware(req: any, res: any, next: any) {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const route =
      (req.route && req.route.path) ||
      (req.baseUrl ? req.baseUrl : req.path) ||
      'unknown';
    httpRequestsTotal.inc({
      method: req.method,
      route: route,
      status: String(res.statusCode),
    });
  });
  next();
}
