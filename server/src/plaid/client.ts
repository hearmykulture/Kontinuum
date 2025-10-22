import { Configuration, PlaidApi, PlaidEnvironments } from 'plaid';
import { env } from '../config/env.js';

const basePath = PlaidEnvironments[env.PLAID_ENV as keyof typeof PlaidEnvironments];

const configuration = new Configuration({
  basePath,
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': env.PLAID_CLIENT_ID,
      'PLAID-SECRET': env.PLAID_SECRET,
    },
  },
});

export const plaid = new PlaidApi(configuration);
