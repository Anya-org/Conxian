import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@stacks/clarinet-sdk';

describe('Simple BME', () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('compiles and registers activity', () => {
    const pool1 = 'ST1SJ3DTE5DN7X54Y7D5KS8M7JJ8V3EN6N9X392E';

    let res = simnet.callPublicFn('bme-engine', 'add-activity-reporter', [Cl.principal(deployer)], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.bool(true)));

    res = simnet.callPublicFn('bme-engine', 'register-fee-activity', [Cl.principal(pool1), Cl.uint(1000)], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
