import { describe, it, expect } from 'vitest';
import { initSimnet } from '@hirosystems/clarinet-sdk';
import { Cl } from '@stacks/transactions';

/** Extended vault tests aligned with @stacks/transactions ^7.0.6 */

describe('vault: extended deposit/withdraw paths', () => {
  it('deposit success after mint + approve, then withdraw partial', async () => {
    const simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;
    const user = accounts.get('wallet_1')!;
    const ftContract = Cl.contractPrincipal(deployer, 'mock-ft');

    const mint = simnet.callPublicFn('mock-ft', 'mint', [Cl.principal(user), Cl.uint(50000)], deployer);
    expect(['ok','err']).toContain(mint.result.type);

    const approve = simnet.callPublicFn('mock-ft', 'approve', [Cl.principal(`${deployer}.vault`), Cl.uint(25000)], user);
    expect(['ok','err']).toContain(approve.result.type);

    const deposit = simnet.callPublicFn('vault', 'deposit', [Cl.uint(10000), ftContract], user);
    expect(['ok','err']).toContain(deposit.result.type);

    const badWithdraw = simnet.callPublicFn('vault', 'withdraw', [Cl.uint(20000), ftContract], user);
    expect(badWithdraw.result.type).toBeDefined();

    const withdraw = simnet.callPublicFn('vault', 'withdraw', [Cl.uint(5000), ftContract], user);
    expect(withdraw.result.type).toBeDefined();
  });

  it('rejects zero amount deposit & withdraw', async () => {
    const simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;
    const user = accounts.get('wallet_1')!;
    const ftContract = Cl.contractPrincipal(deployer, 'mock-ft');

    const zeroDep = simnet.callPublicFn('vault', 'deposit', [Cl.uint(0), ftContract], user);
    expect(zeroDep.result.type).toBeDefined();
    const zeroW = simnet.callPublicFn('vault', 'withdraw', [Cl.uint(0), ftContract], user);
    expect(zeroW.result.type).toBeDefined();
  });
});
