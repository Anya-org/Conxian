
import { describe, expect, it } from 'vitest';
import { simnet } from './setup-test-env';

describe('Sanity Check', () => {
  it('should pass this basic test', () => {
    expect(true).toBe(true);
  });

  it('should have an initialized simnet', () => {
    expect(simnet).toBeDefined();
    const accounts = simnet.getAccounts();
    expect(accounts.size).toBeGreaterThan(0);
  });
});
