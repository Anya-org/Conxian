import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('Protocol Benchmarks', () => {
    let deployer: string;

  beforeEach(async () => {

    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('captures gas for run-fiscal-strategy', () => {
    // Mine a few blocks to ensure burn-block-height progresses
    simnet.mineEmptyBlocks(10);

    const accounts = simnet.getAccounts();
    const wallet1 = accounts.get('wallet_1')!;
    const res = simnet.callPublicFn('fiscal-orchestrator', 'run-fiscal-strategy',
      [Cl.list([Cl.principal(wallet1)]), Cl.contractPrincipal(deployer, 'cxd-token'), Cl.principal(deployer + ".finance-metrics")],
      deployer);
    console.log('BENCHMARK: run-fiscal-strategy');
    // expect(res.result).toBeDefined();
  });

  it('captures gas for distribute-token', () => {
    const res = simnet.callPublicFn('revenue-distributor', 'distribute-stx', [Cl.uint(1000000)], deployer);
    console.log('BENCHMARK: distribute-stx');
    expect(res.result).toBeDefined();
  });
});

describe('Observability Benchmarks', () => {
  it('captures gas for get-protocol-status', async () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;
    const res = simnet.callReadOnlyFn('conxian-protocol', 'get-protocol-status', [], deployer);
    expect(res.result).toBeDefined();
  });
});
