import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('Intelligence-Led Adaptive Yield Engine (AYE) - CXIP-013', () => {
  let deployer: string;
  const P0 = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;

    // Initialize agents and treasury with deployer as owner/admin
    simnet.callPublicFn(
      'agent-risk',
      'initialize',
      [Cl.principal(deployer)],
      P0
    );
    simnet.callPublicFn(
      'cxd-treasury',
      'initialize',
      [Cl.principal(deployer)],
      P0
    );
    simnet.callPublicFn(
      'agent-treasury',
      'initialize',
      [Cl.principal(deployer)],
      P0
    );
  });

  it('Initial state should be CXIP-013 Equilibrium', () => {
    const response = simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-allocation-percentages',
      [],
      deployer
    );
    expect(response.result).toEqual(Cl.ok(Cl.tuple({
      treasury: Cl.uint(4500),
      bounty: Cl.uint(3000),
      lp: Cl.uint(1500),
      grant: Cl.uint(500),
      buyback: Cl.uint(500),
      insurance: Cl.uint(0),
      staking: Cl.uint(1500),
      dev: Cl.uint(4500)
    })));
  });

  it('Agent-Risk should provide performance metrics', () => {
    // Set TVL and bounty completion rate
    simnet.callPublicFn(
      'agent-risk',
      'set-tvl',
      [Cl.uint(1000000000), Cl.uint(900000000), Cl.uint(9600)],
      deployer
    );

    const metrics = simnet.callReadOnlyFn(
      'agent-risk',
      'get-performance-metrics',
      [],
      deployer
    );
    expect(metrics.result).toEqual(Cl.tuple({
      tvl: Cl.uint(1000000000),
      'last-month-tvl': Cl.uint(900000000),
      'bounty-completion-rate': Cl.uint(9600),
      'tvl-growth-bps': Cl.uint(1111) // (1B-0.9B)/0.9B * 10000 = 1111.11...
    }));
  });

  it('Performance adjustment should be active if bounty rate > 95%', () => {
    // Bounty rate 9600 > 9500
    const adj = simnet.callReadOnlyFn(
      'agent-treasury',
      'calculate-performance-adjustment',
      [],
      deployer
    );
    expect(adj.result).toEqual(Cl.uint(500));
  });

  it('Agent-Treasury should rebalance with performance adjustment in stability', () => {
    // Set mock GCR to 140 (Stability)
    simnet.callPublicFn(
      "agent-risk",
      "set-mock-gcr",
      [Cl.uint(140)],
      deployer
    );
    // Authorize agent-treasury in cxd-treasury
    const auth = simnet.callPublicFn(
      'cxd-treasury',
      'set-authorized-principals',
      [Cl.contractPrincipal(deployer, 'agent-treasury'), Cl.contractPrincipal(deployer, 'revenue-distributor')],
      deployer
    );
    expect(auth.result).toEqual(Cl.ok(Cl.bool(true)));

    // Trigger rebalance
    const rebalanceResponse = simnet.callPublicFn(
      'agent-treasury',
      'run-fiscal-strategy',
      [],
      deployer
    );
    expect(rebalanceResponse.result).toEqual(Cl.ok(Cl.bool(true)));

    const newPolicy = simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-allocation-percentages',
      [],
      deployer
    );

    // Stability Baseline: T:4500, B:3000, LP:1500, G:500, BB:500
    // Perf Adj (+500 to B, -500 from T): T:4000, B:3500, LP:1500, G:500, BB:500
    expect(newPolicy.result).toEqual(Cl.ok(Cl.tuple({
      treasury: Cl.uint(4000),
      bounty: Cl.uint(3500),
      lp: Cl.uint(1500),
      grant: Cl.uint(500),
      buyback: Cl.uint(500),
      insurance: Cl.uint(0),
      staking: Cl.uint(1500),
      dev: Cl.uint(4000)
    })));
  });

  it('Agent-Risk Crisis should trigger 100% insurance', () => {
    // Set high risk score
    simnet.callPublicFn(
      'agent-risk',
      'set-mock-gcr',
      [Cl.uint(105)], // Crisis is GCR < 110
      deployer
    );

    // Mine a block to allow re-run of strategy
    simnet.mineEmptyBurnBlock();

    const rebalanceResponse = simnet.callPublicFn(
      'agent-treasury',
      'run-fiscal-strategy',
      [],
      deployer
    );
    expect(rebalanceResponse.result).toEqual(Cl.ok(Cl.bool(true)));

    const crisisPolicy = simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-allocation-percentages',
      [],
      deployer
    );
    expect(crisisPolicy.result).toEqual(Cl.ok(Cl.tuple({
      treasury: Cl.uint(0),
      bounty: Cl.uint(0),
      lp: Cl.uint(0),
      grant: Cl.uint(0),
      buyback: Cl.uint(0),
      insurance: Cl.uint(10000),
      staking: Cl.uint(0),
      dev: Cl.uint(0)
    })));
  });
});
