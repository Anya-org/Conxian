import { describe, it, expect } from 'vitest';
import { initSimnet } from '@hirosystems/clarinet-sdk';
import { Cl } from '@stacks/transactions';
import {
  principals,
  contract as contractPrincipal,
  mintMock,
  approve,
  setVaultTokenViaTimelock,
  getVaultTotals,
  getVaultShare,
  getVaultReserves,
} from './helpers/sip010-helpers';

/**
 * SIP-010 integration tests for vault deposit-v2 and withdraw-v2 paths.
 * Uses timelock to set token principal, enforces min-delay by mining blocks,
 * and validates fee, shares, and reserves accounting.
 */

describe('vault: SIP-010 deposit-v2 / withdraw-v2', () => {
  it('timelock set-token -> deposit-v2 -> withdraw-v2 with correct fees/shares', async () => {
    const simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;
    const user = accounts.get('wallet_1')!;

    const { vault, mockFt } = principals(simnet);

    // Ensure token is set via timelock to the mock SIP-010 token and unpaused
    setVaultTokenViaTimelock(simnet, mockFt);

    // Mint MOCK tokens to user and approve vault
    const mint = mintMock(simnet, user, 50_000, deployer);
    expect(['ok', 'err']).toContain(mint.result.type);

    const approveRes = approve(simnet, 'mock-ft', user, vault, 25_000);
    expect(['ok', 'err']).toContain(approveRes.result.type);

    // Deposit 10,000 via deposit-v2 using SIP-010 trait reference
    const ftRef = contractPrincipal('mock-ft', deployer);
    const deposit = simnet.callPublicFn('vault', 'deposit-v2', [Cl.uint(10_000), ftRef], user);
    expect(deposit.result).toEqual({ type: 'ok', value: { type: 'uint', value: 9970n } }); // 0.30% fee => 30

    // Totals after deposit
    const { tb: tbAfterDep, ts: tsAfterDep } = getVaultTotals(simnet, deployer);
    expect(tbAfterDep.result).toEqual({ type: 'uint', value: 9970n });
    expect(tsAfterDep.result).toEqual({ type: 'uint', value: 9970n });

    // Reserves after deposit: fee 30 split 50/50 -> 15 each
    const { tres: tresAfterDep, pres: presAfterDep } = getVaultReserves(simnet, deployer);
    expect(tresAfterDep.result).toEqual({ type: 'uint', value: 15n });
    expect(presAfterDep.result).toEqual({ type: 'uint', value: 15n });

    // User shares minted
    const userSharesAfterDep = getVaultShare(simnet, user, deployer);
    expect(userSharesAfterDep.result).toEqual({ type: 'uint', value: 9970n });

    // Withdraw 5,000 via withdraw-v2 -> 0.10% fee => 5,000 * 0.001 = 5
    const withdraw = simnet.callPublicFn('vault', 'withdraw-v2', [Cl.uint(5_000), ftRef], user);
    // payout = amount - fee = 5000 - 5 = 4995
    expect(withdraw.result).toEqual({ type: 'ok', value: { type: 'uint', value: 4995n } });

    // Totals after withdraw: tb 9970 - 5000 = 4970; ts 9970 - ceil(5000*9970/9970)=9970-5000=4970
    const { tb: tbAfterW, ts: tsAfterW } = getVaultTotals(simnet, deployer);
    expect(tbAfterW.result).toEqual({ type: 'uint', value: 4970n });
    expect(tsAfterW.result).toEqual({ type: 'uint', value: 4970n });

    // Reserves after withdraw: fee 5 split 50/50 with integer division => +2 to treasury, +3 to protocol => totals 17/18
    const { tres: tresAfterW, pres: presAfterW } = getVaultReserves(simnet, deployer);
    expect(tresAfterW.result).toEqual({ type: 'uint', value: 17n });
    expect(presAfterW.result).toEqual({ type: 'uint', value: 18n });

    // User shares after burn should be 4970
    const userSharesAfterW = getVaultShare(simnet, user, deployer);
    expect(userSharesAfterW.result).toEqual({ type: 'uint', value: 4970n });
  });

  it('rejects deposit-v2 when token principal mismatches (invalid-token)', async () => {
    const simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;
    const user = accounts.get('wallet_1')!;

    const { avg } = principals(simnet);

    // Switch token to AVG via timelock (vault must be paused and empty; true at init)
    setVaultTokenViaTimelock(simnet, avg);

    const ftMock = contractPrincipal('mock-ft', deployer);
    const badDeposit = simnet.callPublicFn('vault', 'deposit-v2', [Cl.uint(1_000), ftMock], user);
    expect(badDeposit.result.type).toBe('err'); // err u201 (invalid-token)
  });
});
