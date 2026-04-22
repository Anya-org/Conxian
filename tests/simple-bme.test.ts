import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('Simple BME', () => {
    let deployer: string;

  beforeEach(async () => {

    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('compiles and registers activity', () => {
    const accounts = simnet.getAccounts();
    const pool1 = accounts.get('wallet_1')!;

    let res = simnet.callPublicFn('bme-engine', 'add-activity-reporter', [Cl.principal(deployer)], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.bool(true)));

    res = simnet.callPublicFn('bme-engine', 'register-fee-activity', [Cl.principal(pool1), Cl.uint(1000)], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
