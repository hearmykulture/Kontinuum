/// <reference types="vitest" />

import { describe, it, expect } from 'vitest';
import { resolvePendingToPosted } from '../service.runtime.js';

describe('resolvePendingToPosted', () => {
  it('returns pending IDs that should be hidden when posted arrives', () => {
    const pending = {
      transaction_id: 'p_123',
      pending: true,
      pending_transaction_id: null,
    };
    const posted = {
      transaction_id: 't_123',
      pending: false,
      pending_transaction_id: 'p_123',
    };
    const unrelated = {
      transaction_id: 'x_999',
      pending: false,
      pending_transaction_id: null,
    };

    const result = resolvePendingToPosted([pending, posted, unrelated]);
    expect(result).toEqual(['p_123']);
  });

  it('handles empty & null gracefully', () => {
    expect(resolvePendingToPosted([])).toEqual([]);
    // @ts-expect-error intentional
    expect(resolvePendingToPosted(null)).toEqual([]);
  });
});
