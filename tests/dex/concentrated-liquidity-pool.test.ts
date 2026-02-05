import { describe, expect, it, beforeEach, beforeAll } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;

describe('Concentrated Liquidity Pool', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;

  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
  });

  it('ensures that the contract is deployed', () => {
    // Check that the contract is loaded by calling a read-only function
    const result = simnet.callReadOnlyFn(
      'concentrated-liquidity-pool',
      'get-pool',
      [Cl.uint(1)],
      deployer
    );
    // Should return none for uninitialized pool
    expect(result.result).toBeDefined();
  });

  it('allows a user to mint a new position', () => {
    // First create a pool
    const cxdToken = `${deployer}.cxd-token`;
    const cxsToken = `${deployer}.cxs-token`;

    let result = simnet.callPublicFn(
      'concentrated-liquidity-pool',
      'create-pool',
      [
        Cl.principal(cxdToken),
        Cl.principal(cxsToken),
        Cl.uint(3000), // 0.3% fee
        Cl.uint(79228162514264337593543950336n), // sqrt price as BigInt
      ],
      deployer
    );
    expect(result.result).toEqual(Cl.ok(Cl.uint(1)));

    // Then mint a position
    result = simnet.callPublicFn(
      'concentrated-liquidity-pool',
      'mint',
      [
        Cl.uint(1),
        Cl.int(-100),
        Cl.int(100),
        Cl.uint(1000),
      ],
      deployer
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('returns error when pool does not exist', () => {
    const result = simnet.callPublicFn(
      'concentrated-liquidity-pool',
      'mint',
      [
        Cl.uint(999), // Non-existent pool
        Cl.int(-100),
        Cl.int(100),
        Cl.uint(1000),
      ],
      deployer
    );
    expect(result.result).toEqual(Cl.error(Cl.uint(1002))); // ERR_INSUFFICIENT_LIQUIDITY
  });
});
