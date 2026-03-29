import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@stacks/clarinet-sdk';

describe('Protocol Benchmarks', () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('captures gas for run-fiscal-strategy', () => {
    // Mine a few blocks to ensure burn-block-height progresses
    simnet.mineEmptyBlocks(10);

    const accounts = simnet.getAccounts();
    const wallet1 = accounts.get('wallet_1')!;
    const res = simnet.callPublicFn('fiscal-orchestrator', 'run-fiscal-strategy',
      [Cl.list([Cl.principal(wallet1)]), Cl.contractPrincipal(deployer, 'cxd-token')],
      deployer);
    console.log('BENCHMARK: run-fiscal-strategy');
    console.log(JSON.stringify(res.events, null, 2));
    // In Clarinet SDK, gas is often in res.result if it returns a response or check events
    // For now we look at the raw output in the terminal
    expect(res.result).toBeDefined();
  });

  it('captures gas for distribute-token', () => {
    // Mock token transfer
    const res = simnet.callPublicFn('revenue-distributor', 'distribute-stx', [Cl.uint(1000000)], deployer);
    console.log('BENCHMARK: distribute-stx');
    // console.log(JSON.stringify(res, null, 2));
    expect(res.result).toBeDefined();
  });
});

describe('Observability Benchmarks', () => {
  it('captures gas for get-protocol-status', async () => {
    const simnet = await initSimnet();
    const res = simnet.callReadOnlyFn('conxian-protocol', 'get-protocol-status', [], 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM');
    expect(res.result).toBeDefined();
  });
});
