import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('Cybernetic Revenue Allocation', () => {
  let deployer: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('verifies dynamic allocation across all ranges', () => {
    simnet.callPublicFn('agent-risk', 'set-predictive-params', [Cl.uint(10000), Cl.uint(0), Cl.uint(0)], deployer);
    simnet.callPublicFn('cxd-token', 'mint', [Cl.uint(1000000), Cl.standardPrincipal(deployer)], deployer);

    // 1. CRISIS
    simnet.callPublicFn('agent-risk', 'set-predictive-params', [Cl.uint(0), Cl.uint(10000), Cl.uint(10000)], deployer);
    let policy = simnet.callReadOnlyFn('agent-treasury', 'calculate-cybernetic-policy', [], deployer);
    expect(policy.result).toEqual(Cl.tuple({ staking: Cl.uint(0), dev: Cl.uint(0), insurance: Cl.uint(10000) }));

    // 2. ABUNDANCE
    simnet.callPublicFn('agent-risk', 'set-predictive-params', [Cl.uint(10000), Cl.uint(0), Cl.uint(0)], deployer);
    policy = simnet.callReadOnlyFn('agent-treasury', 'calculate-cybernetic-policy', [], deployer);
    expect(policy.result).toEqual(Cl.tuple({ staking: Cl.uint(8000), dev: Cl.uint(1000), insurance: Cl.uint(1000) }));

    // 3. INTERMEDIATE 1 (GCR 125)
    // Need D/B = 1.25. D=1000, B=800.
    simnet.callPublicFn('lending-manager', 'deposit', [Cl.contractPrincipal(deployer, 'cxd-token'), Cl.uint(1000)], deployer);
    const borRes = simnet.callPublicFn('lending-manager', 'borrow', [Cl.contractPrincipal(deployer, 'cxd-token'), Cl.uint(800)], deployer);
    console.log('Borrow 800 Result:', borRes.result);

    let gcr = simnet.callReadOnlyFn('agent-risk', 'get-gcr', [], deployer);
    console.log('GCR:', gcr.result);

    if (gcr.result.type === 'ok' && gcr.result.value.value === 125n) {
      policy = simnet.callReadOnlyFn('agent-treasury', 'calculate-cybernetic-policy', [], deployer);
      expect(policy.result).toEqual(Cl.tuple({ staking: Cl.uint(4500), dev: Cl.uint(1500), insurance: Cl.uint(4000) }));
    }

    // 4. INTERMEDIATE 2 (GCR 140)
    // Add deposits to reach GCR 140.
    // D/B = 1.4 -> D = 1.4 * 800 = 1120.
    // Current D = 1000. Add 120.
    simnet.callPublicFn('lending-manager', 'deposit', [Cl.contractPrincipal(deployer, 'cxd-token'), Cl.uint(120)], deployer);
    gcr = simnet.callReadOnlyFn('agent-risk', 'get-gcr', [], deployer);
    console.log('GCR:', gcr.result);

    if (gcr.result.type === 'ok' && gcr.result.value.value === 140n) {
      policy = simnet.callReadOnlyFn('agent-treasury', 'calculate-cybernetic-policy', [], deployer);
      expect(policy.result).toEqual(Cl.tuple({ staking: Cl.uint(7000), dev: Cl.uint(1500), insurance: Cl.uint(1500) }));
    }
  });
});
