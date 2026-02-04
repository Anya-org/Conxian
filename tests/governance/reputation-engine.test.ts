import { Cl, cvToValue } from '@stacks/transactions';
import { describe, expect, it, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';

describe('Reputation Engine', () => {
  let simnet: Simnet;
  let deployer: string;
  let voter: string;

  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
  });

  beforeEach(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    voter = accounts.get('wallet_1')!;
  });

  it('should return full power for a new user', async () => {
    const { result } = await simnet.callPublicFn('reputation-engine', 'get-weighted-voting-power', [
      Cl.principal(voter),
      Cl.uint(1000),
    ], voter);
    expect(cvToValue(result)).toEqual(1000);
  });

  it('should decay voting power over time', async () => {
    // 1. Initial vote to set activity
    const { result: updateResult } = await simnet.callPublicFn(
      'reputation-engine',
      'update-activity-score',
      [Cl.principal(voter)],
      voter
    );
    expect(updateResult).toEqual(Cl.ok(Cl.bool(true)));

    // 2. Advance time (10 days)
    await simnet.mineEmptyBlocks(144 * 10);

    // 3. Check decayed voting power
    const { result } = await simnet.callPublicFn('reputation-engine', 'get-weighted-voting-power', [
      Cl.principal(voter),
      Cl.uint(1000),
    ], voter);
    // Decay calculation: 10 days * 1% decay/day = 10% decay. 1000 * (1 - 0.10) = 900
    expect(cvToValue(result)).toEqual(900);
  });

  it('should reset decay on new activity', async () => {
    // 1. Initial vote
    await simnet.callPublicFn(
      'reputation-engine',
      'update-activity-score',
      [Cl.principal(voter)],
      voter
    );

    // 2. Advance time (10 days)
    await simnet.mineEmptyBlocks(144 * 10);

    // 3. Second vote
    await simnet.callPublicFn(
      'reputation-engine',
      'update-activity-score',
      [Cl.principal(voter)],
      voter
    );

    // 4. Check power (should be full again)
    const { result } = await simnet.callPublicFn('reputation-engine', 'get-weighted-voting-power', [
      Cl.principal(voter),
      Cl.uint(1000),
    ], voter);
    expect(cvToValue(result)).toEqual(1000);
  });
});
