import 'dotenv/config';
import { z } from 'zod';

const EnvSchema = z.object({
  // DB
  DATABASE_URL: z.string().min(1),
  SHADOW_DATABASE_URL: z.string().min(1),

  // Plaid
  PLAID_ENV: z.enum(['sandbox', 'development', 'production']).default('sandbox'),
  PLAID_CLIENT_ID: z.string().min(1),
  PLAID_SECRET: z.string().min(1),
  PLAID_REDIRECT_URI: z.string().optional().default(''),
  PLAID_WEBHOOK_URL: z.string().optional().default(''),

  // Server
  PORT: z.coerce.number().default(4000),
  PUBLIC_BASE_URL: z.string().min(1),

  // Crypto
  ENCRYPTION_KEY: z.string().min(32, 'ENCRYPTION_KEY must be 32+ chars'),
  LOG_LEVEL: z.string().default('info'),
  NODE_ENV: z.string().default('development'),
});

export const env = EnvSchema.parse(process.env);
