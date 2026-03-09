import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@stacks/clarinet-sdk';

describe('Sovereign BME Integration', () => {
  let simnet: any;
  let accounts: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('verifies fee activity registration and meritocratic minting', () => {
    const pool1 = 'ST1SJ3DTE5DN7X54Y7D5KS8M7JJ8V3EN6N9X392E';
    const pool2 = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
    const bmeEngine = 'bme-engine';
    const cxdToken = 'cxd-token';

    // 1. Authorize reporter
    let res = simnet.callPublicFn(bmeEngine, 'add-activity-reporter', [Cl.principal(deployer)], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.bool(true)));

    // 2. Register activity
    simnet.callPublicFn(bmeEngine, 'register-fee-activity', [Cl.principal(pool1), Cl.uint(6000)], deployer);
    simnet.callPublicFn(bmeEngine, 'register-fee-activity', [Cl.principal(pool2), Cl.uint(4000)], deployer);

    // 3. Verify stats
    let stats = simnet.callReadOnlyFn(bmeEngine, 'get-bme-stats', [], deployer);
    expect(stats.result).toEqual(Cl.ok(Cl.tuple({
      'total-epoch-fees': Cl.uint(10000),
      'last-mint-block': Cl.uint(0),
      'total-burned': Cl.uint(0),
      'mint-per-epoch': Cl.uint(100000000000)
    })));

    // 4. Advance time for epoch
    simnet.mineEmptyBlocks(150);

    // 5. Execute minting
    // Need to make bme-engine a minter for cxd-token
    // Correct principal for contracts in simnet is deployer.contract-name
    simnet.callPublicFn(cxdToken, 'add-minter', [Cl.principal(`${deployer}.bme-engine`)], deployer);

    res = simnet.callPublicFn(bmeEngine, 'execute-epoch-minting', [
      Cl.list([Cl.principal(pool1), Cl.principal(pool2)])
    ], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.bool(true)));

    // 6. Verify pool balances (meritocratic distribution)
    let bal1 = simnet.callReadOnlyFn(cxdToken, 'get-balance', [Cl.principal(pool1)], deployer);
    expect(bal1.result).toEqual(Cl.ok(Cl.uint(60000000000)));

    let bal2 = simnet.callReadOnlyFn(cxdToken, 'get-balance', [Cl.principal(pool2)], deployer);
    expect(bal2.result).toEqual(Cl.ok(Cl.uint(40000000000)));
  });

  it('verifies intent gateway execution', () => {
    const gateway = 'intent-solver-gateway';
    const intentId = '1234567812345678123456781234567812345678123456781234567812345678';
    const solver = accounts.get('wallet_1')!;

    let res = simnet.callPublicFn(gateway, 'execute-intent', [
      Cl.buffer(Buffer.from(intentId, 'hex')),
      Cl.buffer(Buffer.alloc(10)),
      Cl.principal(solver)
    ], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.bool(true)));

    let settled = simnet.callReadOnlyFn(gateway, 'is-intent-settled', [
      Cl.buffer(Buffer.from(intentId, 'hex'))
    ], deployer);
    expect(settled.result).toEqual(Cl.bool(true));
  });
});
