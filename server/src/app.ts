import express from 'express';
import cors from 'cors';
import morgan from 'morgan';

import { healthRouter } from './routes/health.js';
import { plaidRouter } from './plaid/routes.js';
import financeRouter from './routes/finance.js';
import { sandboxRouter } from './plaid/sandbox.js';
import manageRouter from './finance/manage.routes.js'; // ← mount this too

// NEW: metrics
import { metricsHttpMiddleware, registry } from './observability/metrics.js';

const app = express();

// If you run behind a tunnel/proxy, this helps with req.protocol, secure cookies, etc.
app.enable('trust proxy');

// Core middleware
app.use(cors());

// IMPORTANT: keep raw body for Plaid webhook signature verification
app.use(
  express.json({
    limit: '1mb',
    verify: (req: any, _res, buf) => {
      // exact bytes that Plaid signs; used by webhook verifier
      req.rawBody = Buffer.isBuffer(buf) ? buf : Buffer.from(buf || '');
    },
  }),
);

app.use(morgan(process.env.LOG_LEVEL === 'debug' ? 'dev' : 'tiny'));

// Optional: count HTTP requests (method/route/status)
app.use(metricsHttpMiddleware);

// Friendly root so your tunnel URL doesn't 404
app.get('/', (_req, res) => {
  res.type('text/plain').send(
    [
      'Kontinuum API',
      '----------------',
      'ok: true',
      '',
      'Useful endpoints:',
      '  GET    /health',
      '  GET    /healthz',
      '  POST   /plaid/link_token',
      '  POST   /plaid/exchange_public_token',
      '  POST   /plaid/sync',
      '  POST   /plaid/webhook',
      '  GET    /plaid/oauth (OAuth return page)',
      '  POST   /plaid/sandbox/fire-webhook (sandbox only)',
      '  GET    /finance/accounts?userId=...',
      '  GET    /finance/transactions?userId=...&limit=50',
      '  GET    /finance/cashflow/by-category?userId=...&from=YYYY-MM-DD&to=YYYY-MM-DD',
      '  GET    /finance/budget-vs-actual?userId=...&month=YYYY-MM',
      '  GET    /finance/linked_accounts?userId=...',          // ← manage routes
      '  POST   /finance/settings/features/bank_sync',          // ← feature flag
      '  POST   /finance/items/:itemId/pause',                  // ← pause/unpause
      '  POST   /finance/items/:itemId/unlink',                 // ← unlink
      '  GET    /metrics (Prometheus format)',                  // ← NEW
      '',
    ].join('\n'),
  );
});

// Simple alias if your healthRouter serves /healthz
app.get('/health', (_req, res) => {
  res.json({ ok: true, ts: new Date().toISOString() });
});

// Expose Prometheus metrics
app.get('/metrics', async (_req, res) => {
  try {
    res.set('Content-Type', registry.contentType);
    res.send(await registry.metrics());
  } catch (err: any) {
    res.status(500).type('text/plain').send(err?.message ?? 'metrics error');
  }
});

// Feature routers
app.use(healthRouter);                    // includes /healthz
app.use('/plaid', plaidRouter);           // link/exchange/sync/webhook/oauth
app.use('/plaid/sandbox', sandboxRouter); // sandbox fire-webhook helper
app.use('/finance', financeRouter);       // read APIs (accounts/txns/etc)
app.use('/finance', manageRouter);        // mgmt + flags (linked_accounts, pause, unlink, flag)

// 404 handler
app.use((_req, res) => res.status(404).json({ error: 'Not Found' }));

// Error handler — in dev, expose message so you can see Plaid/Prisma causes
app.use((
  err: any,
  _req: express.Request,
  res: express.Response,
  _next: express.NextFunction,
) => {
  console.error(err);
  const isProd = process.env.NODE_ENV === 'production';
  const message =
    typeof err === 'string'
      ? err
      : err?.message ||
        (err?.response?.data ? JSON.stringify(err.response.data) : 'Internal Server Error');

  res.status(500).json(isProd ? { error: 'Internal Server Error' } : { error: 'Internal Server Error', message });
});

export { app };
export default app;
