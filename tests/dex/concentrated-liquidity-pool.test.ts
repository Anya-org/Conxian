import { describe, expect, it, beforeEach } from 'vitest';
import { Clarinet, Tx, Chain, Account, types } from '@stacks/clarinet-sdk';

describe('Concentrated Liquidity Pool', () => {
  let clarinet: Clarinet;
  let chain: Chain;
  let deployer: Account;
  let wallet1: Account;
  let wallet2: Account;

  beforeEach(async () => {
    clarinet = await Clarinet.new();
    chain = clarinet.getChain();
    deployer = clarinet.getDeployerAccount();
    [wallet1, wallet2] = clarinet.getAccounts([
      'wallet-1',
      'wallet-2',
    ]);
  });

  it('ensures that the contract is deployed', () => {
    const { address } = deployer;
    const contract = chain.getContract(address, 'concentrated-liquidity-pool');
    expect(contract).toBeDefined();
  });

  it('allows a user to mint a new position', () => {
    const { address } = deployer;
    const block = chain.mineBlock([
      Tx.contractCall(
        'concentrated-liquidity-pool',
        'mint',
        [
          types.uint(1),
          types.int(-100),
          types.int(100),
          types.uint(1000),
          types.uint(1000),
        ],
        address
      ),
    ]);
    expect(block.receipts[0].result).toBeOk(types.bool(true));
  });

  it('allows a user to burn a position', () => {
    const { address } = deployer;
    chain.mineBlock([
      Tx.contractCall(
        'concentrated-liquidity-pool',
        'mint',
        [
          types.uint(1),
          types.int(-100),
          types.int(100),
          types.uint(1000),
          types.uint(1000),
        ],
        address
      ),
    ]);
    const block = chain.mineBlock([
      Tx.contractCall(
        'concentrated-liquidity-pool',
        'burn',
        [
          types.uint(1),
          types.int(-100),
          types.int(100),
          types.uint(500),
        ],
        address
      ),
    ]);
    expect(block.receipts[0].result).toBeOk(types.bool(true));
  });

  it('prevents a user from burning more liquidity than they have', () => {
    const { address } = deployer;
    chain.mineBlock([
      Tx.contractCall(
        'concentrated-liquidity-pool',
        'mint',
        [
          types.uint(1),
          types.int(-100),
          types.int(100),
          types.uint(1000),
          types.uint(1000),
        ],
        address
      ),
    ]);
    const block = chain.mineBlock([
      Tx.contractCall(
        'concentrated-liquidity-pool',
        'burn',
        [
          types.uint(1),
          types.int(-100),
          types.int(100),
          types.uint(1500),
        ],
        address
      ),
    ]);
    expect(block.receipts[0].result).toBeErr(types.uint(101));
  });

  it('allows a user to collect fees', () => {
    const { address } = deployer;
    chain.mineBlock([
      Tx.contractCall(
        'concentrated-liquidity-pool',
        'mint',
        [
          types.uint(1),
          types.int(-100),
          types.int(100),
          types.uint(1000),
          types.uint(1000),
        ],
        address
      ),
    ]);
    // TODO: Add a swap to generate fees
    const block = chain.mineBlock([
      Tx.contractCall(
        'concentrated-liquidity-pool',
        'collect',
        [
          types.uint(1),
          types.int(-100),
          types.int(100),
        ],
        address
      ),
    ]);
    expect(block.receipts[0].result).toBeOk(types.tuple({
      'collected-0': types.uint(0),
      'collected-1': types.uint(0),
    }));
  });
});
