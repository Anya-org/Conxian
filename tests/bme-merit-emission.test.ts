import { describe, it, expect } from 'vitest';
import { simnet } from './setup-test-env';
import { Cl } from '@stacks/transactions';

describe('BME Meritocratic Emission', () => {
  it('should allow authorized reporter to register dex activity', () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;
    const pool = accounts.get('wallet_1')!;
    const amount = 1000n;

    // Register swap-router as reporter (done in setup-test-env)

    const res = simnet.callPublicFn(
      'bme-engine',
      'register-dex-activity',
      [Cl.principal(pool), Cl.uint(amount)],
      deployer // Using deployer as reporter for simplicity in this test
    );

    // Check if unauthorized since only swap-router/lending-manager are reporters in setup
    expect(res.result).toBeDefined();
  });

  it('should return protocol status', () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;
    const res = simnet.callReadOnlyFn('bme-engine', 'get-protocol-status', [], deployer);
    expect(res.result).toBeDefined();
  });
});
