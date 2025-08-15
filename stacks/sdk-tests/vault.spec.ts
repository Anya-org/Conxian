import { initSimnet } from '@hirosystems/clarinet-sdk';
import { describe, it, expect } from 'vitest';
import { Cl } from '@stacks/transactions';

// Basic share-based behavior: deposit then withdraw

describe('vault: deposit then withdraw updates balances correctly (share-based)', () => {
  it('should mint shares on deposit and burn on withdraw, preserving balances', async () => {
    const simnet = await initSimnet();
    const accounts = simnet.getAccounts();

    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;

    // Prepare vault contract principal for approvals
    const vaultPrincipal = Cl.contractPrincipal(deployer, 'vault');

    // Mint tokens to wallet_1 and approve vault to spend
    let r1 = simnet.callPublicFn('mock-ft', 'mint', [Cl.standardPrincipal(wallet1), Cl.uint(1000)], deployer);
    expect(r1.result.expectOk).toBeDefined();

    let r2 = simnet.callPublicFn('mock-ft', 'approve', [vaultPrincipal, Cl.uint(1000)], wallet1);
    expect(r2.result.expectOk).toBeDefined();

    // Deposit 600
    const dep = simnet.callPublicFn('vault', 'deposit', [Cl.uint(600)], wallet1);
    // fee-deposit-bps = 30 (0.30%), fee = 600*30/10000 = 1, credited = 599
    expect(dep.result.value).toBe(599n);

    // get-balance reflects assets from shares
    const bal = simnet.callReadOnlyFn('vault', 'get-balance', [Cl.standardPrincipal(wallet1)], wallet1);
    expect(bal.result.value).toBe(599n);

    // Withdraw 100 (withdraw fee = 10 bps => 0 in integer math), payout 100
    const w = simnet.callPublicFn('vault', 'withdraw', [Cl.uint(100)], wallet1);
    expect(w.result.value).toBe(100n);

    const bal2 = simnet.callReadOnlyFn('vault', 'get-balance', [Cl.standardPrincipal(wallet1)], wallet1);
    expect(bal2.result.value).toBe(499n);
  });
});
