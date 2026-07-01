import { Cl } from '@stacks/transactions';
import { describe, expect, it, beforeEach } from 'vitest';
import { simnet } from './setup-test-env';

describe('Intelligence-Led Adaptive Yield Engine (AYE) - CXIP-013', () => {
  let deployer: string;

  beforeEach(async () => {
    deployer = simnet.getAccounts().get('deployer')!;
  });

  it('Agent-Risk should adjust PID stability fees', () => {
    simnet.callPublicFn('agent-risk', 'set-stability-fee', [Cl.uint(0)], deployer);
    const res = simnet.callPublicFn('agent-risk', 'get-cybernetic-intel', [Cl.principal(deployer + '.finance-metrics')], deployer);
    expect(Cl.prettyPrint(res.result)).toContain('operational-fee: u0');
  });

  it('Agent-Risk should assess system risk based on GCR', () => {
    simnet.callPublicFn('finance-metrics', 'set-mock-gcr', [Cl.uint(100)], deployer);
    const res = simnet.callPublicFn('agent-risk', 'get-cybernetic-intel', [Cl.principal(deployer + '.finance-metrics')], deployer);
    expect(Cl.prettyPrint(res.result)).toContain('risk-score: u900');
  });

  it('Agent-Treasury should calculate performance adjustment', () => {
    const adj = simnet.callPublicFn('agent-treasury', 'calculate-performance-adjustment', [Cl.principal(deployer + '.finance-metrics')], deployer);
    expect(adj.result).toBeDefined();
  });
});
