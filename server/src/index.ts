import 'dotenv/config';
import app from './app.js';
import { logger } from './config/logger.js';
import { env } from './config/env.js';
import { startCatchupScheduler } from './plaid/catchup.runtime.js';

const server = app.listen(env.PORT, () => {
  logger.info(
    `API listening on ${env.PUBLIC_BASE_URL ?? `http://localhost:${env.PORT}`}`
  );

  // Start the daily catch-up scheduler (controlled by ENABLE_CATCHUP_CRON)
  try {
    startCatchupScheduler();
  } catch (err) {
    logger.error({ err }, 'Failed to start catch-up scheduler');
  }
});

// Graceful shutdown
function shutdown(signal: string) {
  logger.info({ signal }, 'Shutting down HTTP server');
  server.close(() => process.exit(0));
}
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

// Safety nets
process.on('unhandledRejection', (reason) => {
  logger.error({ reason }, 'Unhandled promise rejection');
});
process.on('uncaughtException', (err) => {
  logger.error({ err }, 'Uncaught exception');
});
