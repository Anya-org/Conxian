
import { describe, it, expect, beforeEach, beforeAll } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Swap Router', () => {
  let simnet: Simnet;
  let deployer: string;
  let wallet1: string;

  beforeAll(async () => {
    simnet = await initSimnet();
  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    console.log('Available accounts:', Array.from(accounts.keys()));
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
    console.log('Wallet1:', wallet1);
  });

  it('executes a single hop swap and forwards funds to user', () => {
    const token0 = `${deployer}.cxd-token`;
    const token1 = `${deployer}.cxs-token`;
    
    // Create Pool
    let result = simnet.callPublicFn(
        'concentrated-liquidity-pool',
        'create-pool',
        [
            Cl.principal(token0),
            Cl.principal(token1),
            Cl.uint(3000),
            Cl.uint(100000000),
        ],
        deployer
    );
    expect(result.result).toEqual(Cl.ok(Cl.uint(1)));

    // Mint Liquidity
    result = simnet.callPublicFn(
        'concentrated-liquidity-pool',
        'mint',
        [
            Cl.uint(1),
            Cl.int(-1000),
            Cl.int(1000),
            Cl.uint(1000000000)
        ],
        deployer
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));

    // Mint tokens to wallet1
    result = simnet.callPublicFn(
        'cxd-token',
        'mint',
        [Cl.uint(1000000), Cl.principal(wallet1)],
        deployer
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));

    // Fund the pool with CXS tokens so it can perform swaps
    result = simnet.callPublicFn(
        'cxs-token',
        'mint',
        [Cl.uint(10000000), Cl.principal(deployer)],
        deployer
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));

    // Transfer CXS from deployer to pool
    result = simnet.callPublicFn(
        'cxs-token',
        'transfer',
        [
            Cl.uint(10000000),
            Cl.principal(deployer),
            Cl.principal(`${deployer}.concentrated-liquidity-pool`),
            Cl.none()
        ],
        deployer
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));

    // Check balance
    let balance = simnet.callReadOnlyFn(
        'cxs-token',
        'get-balance',
        [Cl.principal(wallet1)],
        wallet1
    );
    expect(balance.result).toEqual(Cl.ok(Cl.uint(0)));

    // Check CXD Balance of wallet1
    let cxdBalance = simnet.callReadOnlyFn(
        'cxd-token',
        'get-balance',
        [Cl.principal(wallet1)],
        wallet1
    );
    console.log('CXD Balance of wallet1:', cxdBalance.result);

    // Check Protocol Pause Status
    let paused = simnet.callReadOnlyFn(
        'conxian-protocol',
        'is-paused',
        [],
        deployer
    );
    console.log('Protocol Paused Status:', paused.result);

    // Swap
    result = simnet.callPublicFn(
        'swap-router',
        'exact-input-single',
        [
            Cl.uint(1),
            Cl.principal(token0),
            Cl.principal(token1),
            Cl.uint(1000),
            Cl.uint(0)
        ],
        wallet1
    );
    // 997 is expected
    expect(result.result).toEqual(Cl.ok(Cl.uint(997)));

    // Verify balance
    balance = simnet.callReadOnlyFn(
        'cxs-token',
        'get-balance',
        [Cl.principal(wallet1)],
        wallet1
    );
    expect(balance.result).toEqual(Cl.ok(Cl.uint(997)));
  });
});
