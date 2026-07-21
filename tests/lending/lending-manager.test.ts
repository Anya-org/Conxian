import { describe, expect, it, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

describe('lending-orchestrator', () => {
  let deployer: string;
  let wallet1: string;

  beforeAll(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    // Mint mock tokens to deployer for testing
    simnet.callPublicFn('mock-token', 'mint', [Cl.uint(1000000), Cl.principal(deployer)], deployer);
    // Mint mock tokens to wallet1 for testing
    simnet.callPublicFn('mock-token', 'mint', [Cl.uint(1000000), Cl.principal(wallet1)], deployer);
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
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)],
      deployer,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
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
