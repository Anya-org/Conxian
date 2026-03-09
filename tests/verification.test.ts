import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@stacks/clarinet-sdk';

describe('BME & Intent Layer Verification', () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('verifies bme-engine has Activity Marker logic', () => {
    const pool = 'ST1SJ3DTE5DN7X54Y7D5KS8M7JJ8V3EN6N9X392E';

    // Register Activity Marker
    simnet.callPublicFn('bme-engine', 'add-activity-reporter', [Cl.principal(deployer)], deployer);
    let res = simnet.callPublicFn('bme-engine', 'register-fee-activity', [Cl.principal(pool), Cl.uint(5000)], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.bool(true)));

    let activity = simnet.callReadOnlyFn('bme-engine', 'get-pool-activity', [Cl.principal(pool)], deployer);
    expect(activity.result).toEqual(Cl.uint(5000));
  });

  it('verifies intent-solver-gateway execution', () => {
    const solver = deployer;
    const intentId = '0x1234567812345678123456781234567812345678123456781234567812345678';

    let res = simnet.callPublicFn('intent-solver-gateway', 'execute-intent', [
      Cl.buffer(Buffer.from(intentId.slice(2), 'hex')),
      Cl.buffer(Buffer.alloc(10)),
      Cl.principal(solver)
    ], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
