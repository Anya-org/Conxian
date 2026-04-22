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
    simnet.mineEmptyBlocks(10);
    const wallet1 = simnet.getAccounts().get('wallet_1')!;

    const res = simnet.callPublicFn('agent-treasury', 'run-fiscal-strategy',
      [
        Cl.principal(`${deployer}.alex-adapter`),
        Cl.list([Cl.principal(wallet1)]),
        Cl.principal(`${deployer}.cxd-token`)
      ],
      deployer);

    console.log('BENCHMARK: run-fiscal-strategy');
    // console.log('Result:', Cl.prettyPrint(res.result));
    expect(res.result).toBeDefined();
  });

  it('captures gas for distribute-token', () => {
    const res = simnet.callPublicFn('revenue-distributor', 'distribute-stx', [Cl.uint(1000000)], deployer);
    console.log('BENCHMARK: distribute-stx');
    expect(res.result).toBeDefined();
  });
});
