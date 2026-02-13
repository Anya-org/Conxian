import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('Cybernetic Revenue Allocation', () => {
  let deployer: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('verifies dynamic allocation across all ranges (CXIP-013)', () => {
    // Initialize state
    simnet.callPublicFn('agent-risk', 'set-predictive-params', [Cl.uint(10000), Cl.uint(0), Cl.uint(0)], deployer);
    simnet.callPublicFn('cxd-token', 'mint', [Cl.uint(1000000), Cl.standardPrincipal(deployer)], deployer);

    // Performance adjustment is active by default in agent-risk (bounty rate 96%)
    // adj-treasury = 4500 - 500 = 4000
    // adj-bounty = 3000 + 500 = 3500

    // 1. CRISIS (GCR < 110 or high risk)
    simnet.callPublicFn('agent-risk', 'set-predictive-params', [Cl.uint(0), Cl.uint(10000), Cl.uint(10000)], deployer);
    let policy = simnet.callReadOnlyFn('agent-treasury', 'calculate-cybernetic-policy', [], deployer);
    expect(policy.result).toEqual(Cl.tuple({
      treasury: Cl.uint(0),
      bounty: Cl.uint(0),
      lp: Cl.uint(0),
      grant: Cl.uint(0),
      buyback: Cl.uint(0),
      insurance: Cl.uint(10000)
    }));

    // 2. ABUNDANCE (GCR >= 150)
    simnet.callPublicFn('agent-risk', 'set-predictive-params', [Cl.uint(10000), Cl.uint(0), Cl.uint(0)], deployer);
    // GCR will be 10000 (Abundance) because borrows are 0
    policy = simnet.callReadOnlyFn('agent-treasury', 'calculate-cybernetic-policy', [], deployer);
    expect(policy.result).toEqual(Cl.tuple({
      treasury: Cl.uint(1000),
      bounty: Cl.uint(0),
      lp: Cl.uint(8000),
      grant: Cl.uint(0),
      buyback: Cl.uint(0),
      insurance: Cl.uint(1000)
    }));

    // 3. STABILITY (130 <= GCR < 150)
    // Force GCR = 140
    simnet.callPublicFn('agent-risk', 'set-mock-gcr', [Cl.uint(140)], deployer);
    policy = simnet.callReadOnlyFn('agent-treasury', 'calculate-cybernetic-policy', [], deployer);
    expect(policy.result).toEqual(Cl.tuple({
      treasury: Cl.uint(4000), // 4500 - 500
      bounty: Cl.uint(3500),   // 3000 + 500
      lp: Cl.uint(1500),
      grant: Cl.uint(500),
      buyback: Cl.uint(500),
      insurance: Cl.uint(0)
    }));

    // 4. INTERPOLATION (110 <= GCR < 130)
    // GCR 120 -> delta 10. multiplier 10/20 = 0.5
    simnet.callPublicFn('agent-risk', 'set-mock-gcr', [Cl.uint(120)], deployer);
    policy = simnet.callReadOnlyFn('agent-treasury', 'calculate-cybernetic-policy', [], deployer);
    expect(policy.result).toEqual(Cl.tuple({
      treasury: Cl.uint(2000), // 4000 * 0.5
      bounty: Cl.uint(1750),   // 3500 * 0.5
      lp: Cl.uint(750),        // 1500 * 0.5
      grant: Cl.uint(250),     // 500 * 0.5
      buyback: Cl.uint(250),   // 500 * 0.5
      insurance: Cl.uint(5000) // Remainder
    }));
  });
});
