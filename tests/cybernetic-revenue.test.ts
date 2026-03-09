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
    const admin = deployer;

    // Set Owner first
    simnet.callPublicFn('conxian-protocol', 'set-owner', [Cl.principal(admin)], admin);

    // 1. STABILITY Range (GCR = 140)
    simnet.callPublicFn('agent-risk', 'set-mock-gcr', [Cl.uint(140)], admin);

    let policy = simnet.callReadOnlyFn('agent-treasury', 'calculate-cybernetic-policy', [], admin);
    expect(Cl.prettyPrint(policy.result)).toContain('treasury: u4500');
    expect(Cl.prettyPrint(policy.result)).toContain('bounty: u3000');

    // 2. CRISIS Range (GCR = 100)
    simnet.callPublicFn('agent-risk', 'set-mock-gcr', [Cl.uint(100)], admin);

    policy = simnet.callReadOnlyFn('agent-treasury', 'calculate-cybernetic-policy', [], admin);
    expect(Cl.prettyPrint(policy.result)).toContain('insurance: u10000');
  });
});
