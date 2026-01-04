import { Cl, cvToValue } from '@stacks/transactions';
import { describe, expect, it, beforeEach } from 'vitest';
import { Clarinet, Tx, Chain, Account } from '@stacks/clarinet-sdk';

describe('Reputation Engine', () => {
  let chain: Chain;
  let deployer: Account;
  let voter: Account;
  let clarinet: Clarinet;

  beforeEach(async () => {
    clarinet = await Clarinet.fromStream(new Uint8Array(), 'simnet', 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM');
    chain = clarinet.chain;
    deployer = clarinet.getAccounts().get('deployer')!;
    voter = clarinet.getAccounts().get('wallet_1')!;
  });

  it('should return full power for a new user', async () => {
    const { result } = await chain.callReadOnlyFn('reputation-engine', 'get-weighted-voting-power', [
      Cl.principal(voter.address),
      Cl.uint(1000),
    ], voter.address);
    expect(cvToValue(result)).toEqual(1000);
  });

  it('should decay voting power over time', async () => {
    // 1. Initial vote to set activity
    let block = chain.mineBlock([
        Tx.contractCall('reputation-engine', 'update-activity-score', [Cl.principal(voter.address)], voter.address)
    ]);
    expect(block.receipts[0].result).toBeOk(Cl.bool(true));

    // 2. Advance time (10 days)
    chain.mineEmptyBlock(144 * 10);

    // 3. Check decayed voting power
    const { result } = await chain.callReadOnlyFn('reputation-engine', 'get-weighted-voting-power', [
      Cl.principal(voter.address),
      Cl.uint(1000),
    ], voter.address);
    // Decay calculation: 10 days * 1% decay/day = 10% decay. 1000 * (1 - 0.10) = 900
    expect(cvToValue(result)).toEqual(900);
  });

  it('should reset decay on new activity', async () => {
    // 1. Initial vote
    chain.mineBlock([
        Tx.contractCall('reputation-engine', 'update-activity-score', [Cl.principal(voter.address)], voter.address)
    ]);

    // 2. Advance time (10 days)
    chain.mineEmptyBlock(144 * 10);

    // 3. Second vote
    chain.mineBlock([
        Tx.contractCall('reputation-engine', 'update-activity-score', [Cl.principal(voter.address)], voter.address)
    ]);

    // 4. Check power (should be full again)
    const { result } = await chain.callReadOnlyFn('reputation-engine', 'get-weighted-voting-power', [
      Cl.principal(voter.address),
      Cl.uint(1000),
    ], voter.address);
    expect(cvToValue(result)).toEqual(1000);
  });
});
