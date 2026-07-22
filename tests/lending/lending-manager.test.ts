import { describe, expect, it, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

describe('lending-orchestrator', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let managerPrincipal: string;
  let mockTokenPrincipal: string;

  beforeAll(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
    managerPrincipal = `${deployer}.lending-manager`;
    mockTokenPrincipal = `${deployer}.mock-token`;
    // Mint mock tokens to deployer for testing
    simnet.callPublicFn('mock-token', 'mint', [Cl.uint(1000000), Cl.principal(deployer)], deployer);
    // Mint mock tokens to wallet1 for testing
    simnet.callPublicFn('mock-token', 'mint', [Cl.uint(1000000), Cl.principal(wallet1)], deployer);
    simnet.callPublicFn('mock-token', 'mint', [Cl.uint(1000000), Cl.principal(wallet2)], deployer);

    // The lending manager is the only source for this asset's scheduled
    // protocol-fee stream. Repayment tests must fail closed if this mapping or
    // the collector stream is absent.
    simnet.callPublicFn(
      'protocol-fee-collector',
      'set-authorized-source',
      [Cl.principal(managerPrincipal), Cl.bool(true)],
      deployer,
    );
    simnet.callPublicFn(
      'protocol-fee-collector',
      'register-ft-stream',
      [Cl.principal(managerPrincipal), Cl.uint(77), Cl.principal(mockTokenPrincipal), Cl.uint(1)],
      deployer,
    );
    simnet.callPublicFn(
      'lending-manager',
      'set-protocol-fee-stream',
      [Cl.principal(mockTokenPrincipal), Cl.uint(77)],
      deployer,
    );
  });

  it('should deposit assets successfully', async () => {
    const { result } = await simnet.callPublicFn(
      'lending-manager',
      'deposit',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)],
      deployer,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('should withdraw assets successfully', async () => {
    // Deposit first
    simnet.callPublicFn('lending-manager', 'deposit', [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)], deployer);
    const { result } = await simnet.callPublicFn(
      'lending-manager',
      'withdraw',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)],
      deployer,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('should borrow assets successfully', async () => {
    // Deposit first to establish liquidity
    simnet.callPublicFn('lending-manager', 'deposit', [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(500)], deployer);
    const { result } = await simnet.callPublicFn(
      'lending-manager',
      'borrow',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)],
      deployer,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('should repay assets successfully', async () => {
    // Setup: deposit + borrow
    simnet.callPublicFn('lending-manager', 'deposit', [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(500)], deployer);
    simnet.callPublicFn('lending-manager', 'borrow', [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)], deployer);
    // Mint repayment tokens
    simnet.callPublicFn('mock-token', 'mint', [Cl.uint(100), Cl.principal(deployer)], deployer);
    const { result } = await simnet.callPublicFn(
      'lending-manager',
      'repay',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100), Cl.contractPrincipal(deployer, 'lending-manager')],
      deployer,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('charges the launch schedule on interest only and credits net reserves', async () => {
    const asset = Cl.contractPrincipal(deployer, 'mock-token');
    const beforeLoan: any = simnet.callReadOnlyFn('lending-manager', 'get-reserve-data', [asset], deployer).result;
    expect(beforeLoan.type).toBe('some');

    await simnet.callPublicFn('lending-manager', 'deposit', [asset, Cl.uint(2000)], wallet2);
    await simnet.callPublicFn('lending-manager', 'borrow', [asset, Cl.uint(1000)], wallet2);
    await simnet.callPublicFn('mock-token', 'mint', [Cl.uint(1000), Cl.principal(wallet2)], deployer);

    const beforeRepay: any = simnet.callReadOnlyFn('lending-manager', 'get-reserve-data', [asset], deployer).result;
    expect(beforeRepay.type).toBe('some');
    const managerBeforeResult: any = simnet.callReadOnlyFn(
      'mock-token',
      'get-balance',
      [Cl.principal(managerPrincipal)],
      deployer,
    ).result;
    expect(managerBeforeResult.type).toBe('ok');
    const managerBefore = BigInt(managerBeforeResult.value.value);
    const revenueBefore: any = simnet.callReadOnlyFn(
      'mock-token',
      'get-balance',
      [Cl.principal(`${deployer}.revenue-distributor`)],
      deployer,
    ).result;
    expect(revenueBefore.type).toBe('ok');
    const accountingBefore: any = simnet.callReadOnlyFn(
      'protocol-fee-collector',
      'get-accounting',
      [Cl.principal(managerPrincipal), Cl.uint(77), Cl.uint(1), Cl.some(Cl.principal(mockTokenPrincipal))],
      deployer,
    ).result;
    expect(accountingBefore.type).toBe('ok');
    expect(accountingBefore.value.type).toBe('some');

    const { result } = await simnet.callPublicFn(
      'lending-manager',
      'repay',
      [asset, Cl.uint(1000), Cl.contractPrincipal(deployer, 'lending-manager')],
      wallet2,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));

    const after: any = simnet.callReadOnlyFn('lending-manager', 'get-reserve-data', [asset], deployer).result;
    expect(after.type).toBe('some');
    const afterData: any = after.value.value;
    const beforeRepayData: any = beforeRepay.value.value;
    expect(BigInt(afterData['total-reserves'].value) - BigInt(beforeRepayData['total-reserves'].value)).toBe(98n);
    expect(BigInt(beforeRepayData['total-borrows'].value) - BigInt(afterData['total-borrows'].value)).toBe(900n);

    const managerAfterResult: any = simnet.callReadOnlyFn(
      'mock-token',
      'get-balance',
      [Cl.principal(managerPrincipal)],
      deployer,
    ).result;
    expect(managerAfterResult.type).toBe('ok');
    expect(BigInt(managerAfterResult.value.value) - managerBefore).toBe(998n);

    const revenueAfter: any = simnet.callReadOnlyFn(
      'mock-token',
      'get-balance',
      [Cl.principal(`${deployer}.revenue-distributor`)],
      deployer,
    ).result;
    expect(revenueAfter).toEqual(revenueBefore);

    const collectorAccounting: any = simnet.callReadOnlyFn(
      'protocol-fee-collector',
      'get-accounting',
      [
        Cl.principal(managerPrincipal),
        Cl.uint(77),
        Cl.uint(1),
        Cl.some(Cl.principal(mockTokenPrincipal)),
      ],
      deployer,
    ).result;
    expect(collectorAccounting.type).toBe('ok');
    expect(collectorAccounting.value.type).toBe('some');
    expect(BigInt(collectorAccounting.value.value.value['eligible-base'].value) - BigInt(accountingBefore.value.value.value['eligible-base'].value)).toBe(100n);
    expect(BigInt(collectorAccounting.value.value.value['assessed-fees'].value) - BigInt(accountingBefore.value.value.value['assessed-fees'].value)).toBe(2n);
  });

  it('fails closed when the asset stream mapping is absent or mismatched', async () => {
    const asset = Cl.contractPrincipal(deployer, 'mock-token');
    const source = Cl.contractPrincipal(deployer, 'lending-manager');
    const beforeUser: any = simnet.callReadOnlyFn('mock-token', 'get-balance', [Cl.principal(wallet1)], deployer).result;
    const beforeManager: any = simnet.callReadOnlyFn('mock-token', 'get-balance', [Cl.principal(managerPrincipal)], deployer).result;
    expect(beforeUser.type).toBe('ok');
    expect(beforeManager.type).toBe('ok');

    expect(simnet.callPublicFn('lending-manager', 'clear-protocol-fee-stream', [Cl.principal(mockTokenPrincipal)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const missing = await simnet.callPublicFn(
      'lending-manager',
      'repay',
      [asset, Cl.uint(1000), source],
      wallet1,
    );
    expect(missing.result).toEqual(Cl.error(Cl.uint(5010)));

    expect(simnet.callPublicFn(
      'protocol-fee-collector',
      'register-ft-stream',
      [Cl.principal(managerPrincipal), Cl.uint(78), Cl.principal(`${deployer}.cxvg-token`), Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn('lending-manager', 'set-protocol-fee-stream', [Cl.principal(mockTokenPrincipal), Cl.uint(78)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(78)));
    const mismatched = await simnet.callPublicFn(
      'lending-manager',
      'repay',
      [asset, Cl.uint(1000), source],
      wallet1,
    );
    expect(mismatched.result.type).toBe('err');

    const afterUser: any = simnet.callReadOnlyFn('mock-token', 'get-balance', [Cl.principal(wallet1)], deployer).result;
    const afterManager: any = simnet.callReadOnlyFn('mock-token', 'get-balance', [Cl.principal(managerPrincipal)], deployer).result;
    expect(afterUser).toEqual(beforeUser);
    expect(afterManager).toEqual(beforeManager);
    expect(simnet.callPublicFn('lending-manager', 'set-protocol-fee-stream', [Cl.principal(mockTokenPrincipal), Cl.uint(77)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(77)));
  });

  describe('Multi-Asset Collateral Risk Configuration and Health Calculations', () => {
    it('should allow admin to configure collateral-factor and liquidation-threshold', async () => {
      const asset = Cl.contractPrincipal(deployer, 'mock-token');
      const { result } = await simnet.callPublicFn(
        'lending-manager',
        'configure-asset-collateral',
        [asset, Cl.uint(6000), Cl.uint(7000)], // 60% CF, 70% LT
        deployer
      );
      expect(result).toEqual(Cl.ok(Cl.bool(true)));

      // Query reserve data to confirm configuration
      const reserveRes = simnet.callReadOnlyFn(
        'lending-manager',
        'get-reserve-data',
        [asset],
        deployer
      );
      const data = reserveRes.result as any;
      expect(data).toBeDefined();
      expect(Cl.prettyPrint(data)).toContain('collateral-factor: u6000');
      expect(Cl.prettyPrint(data)).toContain('liquidation-threshold: u7000');
    });

    it('should reject collateral configuration from unauthorized users', async () => {
      const asset = Cl.contractPrincipal(deployer, 'mock-token');
      const { result } = await simnet.callPublicFn(
        'lending-manager',
        'configure-asset-collateral',
        [asset, Cl.uint(6000), Cl.uint(7000)],
        wallet1
      );
      expect(result).toEqual(Cl.error(Cl.uint(1000))); // ERR_UNAUTHORIZED
    });

    it('should dynamically calculate account health using asset-specific collateral factors', async () => {
      const asset = Cl.contractPrincipal(deployer, 'mock-token');

      // Step A: Configure mock-token to 50% collateral-factor (u5000)
      await simnet.callPublicFn(
        'lending-manager',
        'configure-asset-collateral',
        [asset, Cl.uint(5000), Cl.uint(6000)],
        deployer
      );

      // Step B: Deposit 1000 mock-token as wallet1
      await simnet.callPublicFn(
        'lending-manager',
        'deposit',
        [asset, Cl.uint(1000)],
        wallet1
      );

      // Step C: Borrow 400 mock-token as wallet1 (should succeed as 400 <= 500 max borrow)
      const borrowRes = await simnet.callPublicFn(
        'lending-manager',
        'borrow',
        [asset, Cl.uint(400)],
        wallet1
      );
      expect(borrowRes.result).toEqual(Cl.ok(Cl.bool(true)));

      // Step D: Verify account health.
      // Collateral = 1000 * 50% = 500 value. Borrowed = 400 value.
      // Expected health factor = (500 * 10000) / 400 = 12500.
      const healthRes = simnet.callReadOnlyFn(
        'lending-manager',
        'calculate-account-health',
        [Cl.principal(wallet1)],
        wallet1
      );
      expect(healthRes.result).toEqual(Cl.ok(Cl.uint(12500)));

      // Step E: Attempting to borrow more to violate 50% collateral factor
      // Borrowing another 150 brings total debt to 550, which exceeds 500 collateral limit.
      const overBorrowRes = await simnet.callPublicFn(
        'lending-manager',
        'borrow',
        [asset, Cl.uint(150)],
        wallet1
      );
      expect(overBorrowRes.result).toEqual(Cl.error(Cl.uint(1003))); // ERR_INSUFFICIENT_COLLATERAL
    });
  });
});
