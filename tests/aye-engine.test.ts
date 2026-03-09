import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('Intelligence-Led Adaptive Yield Engine (AYE) - CXIP-013', () => {
  let deployer: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;

    // 1. Setup protocol authority
    simnet.callPublicFn('conxian-protocol', 'set-owner', [Cl.principal(deployer)], deployer);

    // 2. Setup Oracle
    simnet.callPublicFn('oracle-aggregator', 'set-source-authorized', [Cl.principal(deployer), Cl.bool(true)], deployer);
    simnet.callPublicFn('oracle-aggregator', 'set-price', [Cl.principal(`${deployer}.cxd-token`), Cl.uint(110000000)], deployer);
  });

  it('Agent-Risk should adjust PID stability fees', () => {
    const update = simnet.callPublicFn('agent-risk', 'update-pid-rates', [], deployer);
    expect(update.result).toEqual(Cl.ok(Cl.bool(true)));

    const intel = simnet.callReadOnlyFn('agent-risk', 'get-cybernetic-intel', [], deployer);
    expect(Cl.prettyPrint(intel.result)).toContain('operational-fee: u0');
  });

  it('Agent-Risk should assess system risk based on GCR', () => {
    simnet.callPublicFn('agent-risk', 'set-mock-gcr', [Cl.uint(105)], deployer);

    const intel = simnet.callReadOnlyFn('agent-risk', 'get-cybernetic-intel', [], deployer);
    expect(Cl.prettyPrint(intel.result)).toContain('risk-score: u900');
  });

  it('Agent-Treasury should calculate performance adjustment', () => {
    // Set high TVL growth
    simnet.callPublicFn('agent-risk', 'set-tvl', [Cl.uint(2000000), Cl.uint(1000000), Cl.uint(9600)], deployer);

    const adj = simnet.callReadOnlyFn('agent-treasury', 'calculate-performance-adjustment', [], deployer);
    expect(adj.result).toEqual(Cl.ok(Cl.uint(500)));
  });
});
