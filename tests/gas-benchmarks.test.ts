import { describe, it, expect, beforeAll } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Gas Benchmarking', () => {
  let simnet: any;
  let deployer: string;
  let wallet_1: string;

  beforeAll(async () => {
    simnet = await initSimnet();
    deployer = simnet.deployer;
    wallet_1 = simnet.getAccounts().get('wallet_1')!;
  });

  it('benchmark: deposit in lending-manager', () => {
    const amount = 1000000;

    // First, mint tokens to wallet_1
    simnet.callPublicFn('cxd-token', 'mint', [Cl.uint(amount * 10), Cl.standardPrincipal(wallet_1)], deployer);

    const { result, events } = simnet.callPublicFn(
      'lending-manager',
      'deposit',
      [Cl.contractPrincipal(deployer, 'cxd-token'), Cl.uint(amount)],
      wallet_1
    );

    console.log('Deposit Result:', result);
    console.log('Deposit Events:', events.length);
  });

  it('benchmark: swap in swap-router', () => {
    const amountIn = 1000000;
    const { result } = simnet.callPublicFn(
      'swap-router',
      'exact-input-single',
      [
        Cl.uint(0),
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.contractPrincipal(deployer, 'mock-token'),
        Cl.uint(amountIn),
        Cl.uint(0)
      ],
      wallet_1
    );
    console.log('Swap Result:', result);
  });
});
