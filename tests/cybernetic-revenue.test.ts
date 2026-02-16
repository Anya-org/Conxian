import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@stacks/clarinet-sdk';

describe('Cybernetic Revenue Allocation', () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('verifies dynamic allocation across all ranges (CXIP-013)', () => {
    // 1. STABILITY Range (GCR = 140)
    simnet.callPublicFn('agent-risk', 'set-mock-gcr', [Cl.uint(140)], deployer);
    let policy = simnet.callReadOnlyFn('agent-treasury', 'calculate-cybernetic-policy', [], deployer);

    expect(policy.result).toEqual(Cl.tuple({
      treasury: Cl.uint(4500),
      bounty: Cl.uint(3000),
      lp: Cl.uint(1500),
      grant: Cl.uint(500),
      buyback: Cl.uint(500),
      insurance: Cl.uint(0)
    }));

    // 2. CRISIS Range (GCR = 100)
    simnet.callPublicFn('agent-risk', 'set-mock-gcr', [Cl.uint(100)], deployer);
    policy = simnet.callReadOnlyFn('agent-treasury', 'calculate-cybernetic-policy', [], deployer);
    expect(policy.result).toEqual(Cl.tuple({
      treasury: Cl.uint(0),
      bounty: Cl.uint(0),
      lp: Cl.uint(0),
      grant: Cl.uint(0),
      buyback: Cl.uint(0),
      insurance: Cl.uint(10000)
    }));
  });
});
