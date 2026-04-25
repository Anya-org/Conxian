import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('Cybernetic Revenue Allocation', () => {
    let deployer: string;

  beforeEach(async () => {

    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('verifies dynamic allocation across all ranges (CXIP-013)', () => {
    const admin = deployer;
    const metrics = admin + ".finance-metrics";

    // Set Owner first
    simnet.callPublicFn('conxian-protocol', 'set-owner', [Cl.principal(admin)], admin);

    // 1. STABILITY Range (GCR = 140)
    simnet.callPublicFn('finance-metrics', 'set-mock-gcr', [Cl.uint(140)], admin);

    let policy = simnet.callPublicFn('fiscal-orchestrator', 'calculate-cybernetic-policy', [Cl.principal(metrics)], admin);
    expect(Cl.prettyPrint(policy.result)).toContain('treasury: u4500');
    expect(Cl.prettyPrint(policy.result)).toContain('bounty: u3000');

    // 2. CRISIS Range (GCR = 100)
    simnet.callPublicFn('finance-metrics', 'set-mock-gcr', [Cl.uint(100)], admin);

    policy = simnet.callPublicFn('fiscal-orchestrator', 'calculate-cybernetic-policy', [Cl.principal(metrics)], admin);
    expect(Cl.prettyPrint(policy.result)).toContain('insurance: u10000');
  });
});
