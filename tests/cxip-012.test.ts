import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('CXIP-012: Dynamic Fiscal & Operational Logic', () => {
  let deployer: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('ops-engine should have trigger-epoch-update', () => {
    // First authorize ops-engine to mint CXD
    simnet.callPublicFn('cxd-token', 'add-minter', [Cl.contractPrincipal(deployer, 'ops-engine')], deployer);
    // Set oracle prices
    simnet.callPublicFn('oracle-aggregator', 'set-source', [Cl.contractPrincipal(deployer, 'cxd-token'), Cl.uint(100000000), Cl.uint(100)], deployer);
    simnet.callPublicFn('oracle-aggregator', 'set-source', [Cl.contractPrincipal(deployer, 'cxvg-token'), Cl.uint(100000000), Cl.uint(100)], deployer);

    const response = simnet.callPublicFn('ops-engine', 'trigger-epoch-update', [], deployer);
    expect(response.result).toBeDefined();
  });

  it('Fiscal Dam should react to GCR changes', () => {
    simnet.callPublicFn('agent-risk', 'set-predictive-params', [Cl.uint(0), Cl.uint(10000), Cl.uint(10000)], deployer);
    const damResponse = simnet.callPublicFn('agent-treasury', 'apply-fiscal-dam', [], deployer);
    expect(damResponse.result).toEqual(Cl.ok(Cl.bool(true)));
    const policy = simnet.callReadOnlyFn('cxd-treasury', 'get-allocation-percentages', [], deployer);
    expect(policy.result).toEqual(Cl.ok(Cl.tuple({ staking: Cl.uint(0), dev: Cl.uint(0), insurance: Cl.uint(10000) })));
  });
});
