import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('Intelligence-Led Adaptive Yield Engine (AYE) - CXIP-013', () => {
  let deployer: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    console.log('Deployer in test:', deployer);

    // Explicitly initialize again to be sure
    const res = simnet.callPublicFn('agent-risk', 'initialize', [Cl.principal(deployer)], deployer);
    console.log('Agent-Risk Init result:', Cl.prettyPrint(res.result));
  });

  it('Agent-Risk should adjust PID stability fees', () => {
    const setRes = simnet.callPublicFn('agent-risk', 'set-stability-fee', [Cl.uint(0)], deployer);
    console.log('set-stability-fee result:', Cl.prettyPrint(setRes.result));

    const intel = simnet.callReadOnlyFn('agent-risk', 'get-cybernetic-intel', [], deployer);
    expect(Cl.prettyPrint(intel.result)).toContain('operational-fee: u0');
  });

  it('Agent-Risk should assess system risk based on GCR', () => {
    const setRes = simnet.callPublicFn('agent-risk', 'set-risk-score', [Cl.uint(900)], deployer);
    console.log('set-risk-score result:', Cl.prettyPrint(setRes.result));

    const intel = simnet.callReadOnlyFn('agent-risk', 'get-cybernetic-intel', [], deployer);
    expect(Cl.prettyPrint(intel.result)).toContain('risk-score: u900');
  });

  it('Agent-Treasury should calculate performance adjustment', () => {
    const adj = simnet.callReadOnlyFn('agent-treasury', 'calculate-performance-adjustment', [], deployer);
    expect(Cl.prettyPrint(adj.result)).toContain('u500');
  });
});
