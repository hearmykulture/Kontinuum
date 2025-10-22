// server/src/app.ts
import express from 'express';
import cors from 'cors';
import morgan from 'morgan';

import { healthRouter } from './routes/health.js';
import { plaidRouter } from './plaid/routes.js';
import financeRouter from './routes/finance.js';
import manageRouter from './finance/manage.routes.js'; // ⬅️ added
import { sandboxRouter } from './plaid/sandbox.js';

const app = express();

// If you run behind a tunnel/proxy, this helps with req.protocol, secure cookies, etc.
app.enable('trust proxy');

// Core middleware
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(morgan(process.env.LOG_LEVEL === 'debug' ? 'dev' : 'tiny'));

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
      '',
    ].join('\n'),
  );
});

// Simple alias if your healthRouter serves /healthz
app.get('/health', (_req, res) => {
  res.json({ ok: true, ts: new Date().toISOString() });
});

// Feature routers
app.use(healthRouter);                    // includes /healthz
app.use('/plaid', plaidRouter);           // link/exchange/sync/webhook/oauth
app.use('/plaid/sandbox', sandboxRouter); // sandbox fire-webhook helper
app.use('/finance', manageRouter);        // ⬅️ added (Phase 13 management endpoints)
app.use('/finance', financeRouter);

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
