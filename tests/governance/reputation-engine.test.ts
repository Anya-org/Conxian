import { Cl } from '@stacks/transactions';
import { describe, expect, it, beforeAll, beforeEach } from 'vitest';
import { simnet } from '../setup-test-env';

describe('Reputation Engine', () => {
    let deployer: string;
  let voter: string;

  beforeAll(async () => {

  });

  beforeEach(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    voter = accounts.get('wallet_1')!;
  });

  it('should return 1.5x power for a user (BNS Boost active)', async () => {
    const { result } = await simnet.callPublicFn('reputation-engine', 'get-weighted-voting-power', [
      Cl.principal(voter),
      Cl.uint(1000),
    ], voter);
    // 1000 * 1.5 = 1500
    expect(result).toEqual(Cl.ok(Cl.uint(1500)));
  });
});
