import { describe, expect, it, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

describe('lending-orchestrator', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let managerPrincipal: string;
  let mockTokenPrincipal: string;

  const MAX_UINT = 340282366920938463463374607431768211455n;
  const ERR_PROTOCOL_FEE_ARITHMETIC_OVERFLOW = 5021;
  const ERR_PROTOCOL_FEE_STREAM_INVALID = 5022;
  const ERR_PROTOCOL_FEE_STREAM_ALREADY_SET = 5023;

  const tokenBalance = (token: string, principal: string): bigint => {
    const result: any = simnet.callReadOnlyFn(
      token,
      'get-balance',
      [Cl.principal(principal)],
      deployer,
    ).result;
    expect(result.type).toBe('ok');
    return BigInt(result.value.value);
  };

  const optionalTuple = (contract: string, functionName: string, args: any[]): any | null => {
    const result: any = simnet.callReadOnlyFn(contract, functionName, args, deployer).result;
    expect(result.type).toBe('ok');
    if (result.value.type === 'none') return null;
    expect(result.value.type).toBe('some');
    return result.value.value.value;
  };

  const printEvent = (receipt: any, eventName: string): any => {
    const event = receipt.events.find((candidate: any) =>
      candidate.event === 'print_event'
      && candidate.data?.value?.value?.event?.value === eventName,
    );
    expect(event).toBeDefined();
    return event.data.value;
  };

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
      'set-authorized-source',
      [Cl.principal(wallet1), Cl.bool(true)],
      deployer,
    );
    simnet.callPublicFn(
      'protocol-fee-collector',
      'register-ft-stream',
      [Cl.principal(wallet1), Cl.uint(70), Cl.principal(mockTokenPrincipal), Cl.uint(1)],
      deployer,
    );
    simnet.callPublicFn(
      'protocol-fee-collector',
      'register-ft-stream',
      [Cl.principal(managerPrincipal), Cl.uint(71), Cl.principal(`${deployer}.cxvg-token`), Cl.uint(1)],
      deployer,
    );
    simnet.callPublicFn(
      'protocol-fee-collector',
      'register-ft-stream',
      [Cl.principal(managerPrincipal), Cl.uint(72), Cl.principal(mockTokenPrincipal), Cl.uint(1)],
      deployer,
    );
    simnet.callPublicFn(
      'protocol-fee-collector',
      'set-stream-active',
      [Cl.principal(managerPrincipal), Cl.uint(72), Cl.uint(1), Cl.some(Cl.principal(mockTokenPrincipal)), Cl.bool(false)],
      deployer,
    );
    simnet.callPublicFn(
      'protocol-fee-collector',
      'register-ft-stream',
      [Cl.principal(managerPrincipal), Cl.uint(77), Cl.principal(mockTokenPrincipal), Cl.uint(1)],
      deployer,
    );
    expect(simnet.callPublicFn(
      'lending-manager',
      'set-protocol-fee-stream',
      [Cl.principal(mockTokenPrincipal), Cl.uint(0)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1004)));
    expect(simnet.callPublicFn(
      'lending-manager',
      'set-protocol-fee-stream',
      [Cl.principal(mockTokenPrincipal), Cl.uint(999)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_PROTOCOL_FEE_STREAM_INVALID)));
    expect(simnet.callPublicFn(
      'lending-manager',
      'set-protocol-fee-stream',
      [Cl.principal(mockTokenPrincipal), Cl.uint(70)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_PROTOCOL_FEE_STREAM_INVALID)));
    expect(simnet.callPublicFn(
      'lending-manager',
      'set-protocol-fee-stream',
      [Cl.principal(mockTokenPrincipal), Cl.uint(71)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_PROTOCOL_FEE_STREAM_INVALID)));
    expect(simnet.callPublicFn(
      'lending-manager',
      'set-protocol-fee-stream',
      [Cl.principal(mockTokenPrincipal), Cl.uint(72)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_PROTOCOL_FEE_STREAM_INVALID)));
    expect(simnet.callPublicFn(
      'lending-manager',
      'set-protocol-fee-stream',
      [Cl.principal(mockTokenPrincipal), Cl.uint(77)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(77)));
    expect(simnet.callReadOnlyFn(
      'lending-manager',
      'get-protocol-fee-stream',
      [Cl.principal(mockTokenPrincipal)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.some(Cl.uint(77))));
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
    const collectorPrincipal = `${deployer}.protocol-fee-collector`;
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
    const userBefore = tokenBalance('mock-token', wallet2);
    const collectorBefore = tokenBalance('mock-token', collectorPrincipal);
    const nonceBefore: any = simnet.callReadOnlyFn('lending-manager', 'get-protocol-fee-nonce', [], deployer).result;
    const pendingBefore: any = simnet.callReadOnlyFn(
      'lending-manager',
      'get-pending-protocol-fee',
      [Cl.principal(wallet2)],
      deployer,
    ).result;
    expect(pendingBefore).toEqual(Cl.ok(Cl.none()));
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
    const assetAccountingBefore = optionalTuple(
      'protocol-fee-collector',
      'get-asset-accounting',
      [Cl.uint(1), Cl.some(Cl.principal(mockTokenPrincipal))],
    );
    const totalSettlementsBefore: any = simnet.callReadOnlyFn(
      'protocol-fee-collector',
      'get-total-settlements',
      [],
      deployer,
    ).result;
    const collectedBefore: any = simnet.callReadOnlyFn(
      'protocol-fee-collector',
      'get-collected-ft',
      [Cl.principal(mockTokenPrincipal)],
      deployer,
    ).result;

    const receipt: any = await simnet.callPublicFn(
      'lending-manager',
      'repay',
      [asset, Cl.uint(1000), Cl.contractPrincipal(deployer, 'lending-manager')],
      wallet2,
    );
    expect(receipt.result).toEqual(Cl.ok(Cl.bool(true)));
    const feeEvent: any = printEvent(receipt, 'protocol-fee-collected');
    const settlementId = feeEvent.value['settlement-id'];

    const after: any = simnet.callReadOnlyFn('lending-manager', 'get-reserve-data', [asset], deployer).result;
    expect(after.type).toBe('some');
    const afterData: any = after.value.value;
    const beforeRepayData: any = beforeRepay.value.value;
    expect(BigInt(afterData['total-reserves'].value) - BigInt(beforeRepayData['total-reserves'].value)).toBe(98n);
    expect(BigInt(beforeRepayData['total-borrows'].value) - BigInt(afterData['total-borrows'].value)).toBe(900n);
    expect(tokenBalance('mock-token', wallet2)).toBe(userBefore - 1000n);
    expect(tokenBalance('mock-token', collectorPrincipal)).toBe(collectorBefore + 2n);

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
    expect(simnet.callReadOnlyFn('lending-manager', 'get-protocol-fee-nonce', [], deployer).result)
      .toEqual(Cl.ok(Cl.uint(BigInt(nonceBefore.value.value) + 1n)));
    expect(simnet.callReadOnlyFn(
      'lending-manager',
      'get-pending-protocol-fee',
      [Cl.principal(wallet2)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.none()));

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

    const settlement = optionalTuple(
      'protocol-fee-collector',
      'get-settlement',
      [Cl.principal(managerPrincipal), settlementId],
    );
    expect(settlement?.source).toEqual(Cl.principal(managerPrincipal));
    expect(settlement?.['stream-id']).toEqual(Cl.uint(77));
    expect(settlement?.['asset-kind']).toEqual(Cl.uint(1));
    expect(settlement?.asset).toEqual(Cl.some(Cl.principal(mockTokenPrincipal)));
    expect(settlement?.payer).toEqual(Cl.principal(wallet2));
    expect(settlement?.['eligible-base']).toEqual(Cl.uint(100));
    expect(settlement?.['assessed-amount']).toEqual(Cl.uint(2));
    expect(settlement?.['settled-amount']).toEqual(Cl.uint(2));
    expect(settlement?.recipient).toEqual(Cl.principal(collectorPrincipal));
    expect(simnet.callReadOnlyFn(
      'protocol-fee-collector',
      'get-total-settlements',
      [],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(BigInt(totalSettlementsBefore.value.value) + 1n)));
    expect(simnet.callReadOnlyFn(
      'protocol-fee-collector',
      'get-collected-ft',
      [Cl.principal(mockTokenPrincipal)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(BigInt(collectedBefore.value.value) + 2n)));
    const assetAccountingAfter = optionalTuple(
      'protocol-fee-collector',
      'get-asset-accounting',
      [Cl.uint(1), Cl.some(Cl.principal(mockTokenPrincipal))],
    );
    expect(BigInt(assetAccountingAfter?.['collected-fees'].value)
      - BigInt(assetAccountingBefore?.['collected-fees'].value)).toBe(2n);
    expect(assetAccountingAfter?.['routed-fees']).toEqual(assetAccountingBefore?.['routed-fees']);
  });

  it('rejects near-MAX repayment arithmetic without changing debt, custody, or fee state', async () => {
    const asset = Cl.contractPrincipal(deployer, 'mock-token');
    const source = Cl.contractPrincipal(deployer, 'lending-manager');
    const reserveBefore: any = simnet.callReadOnlyFn('lending-manager', 'get-reserve-data', [asset], deployer).result;
    const borrowBefore: any = simnet.callReadOnlyFn(
      'lending-manager',
      'get-user-borrow-balance',
      [Cl.principal(wallet2), Cl.principal(mockTokenPrincipal)],
      deployer,
    ).result;
    const userBefore = tokenBalance('mock-token', wallet2);
    const managerBefore = tokenBalance('mock-token', managerPrincipal);
    const collectorBefore = tokenBalance('mock-token', `${deployer}.protocol-fee-collector`);
    const nonceBefore: any = simnet.callReadOnlyFn('lending-manager', 'get-protocol-fee-nonce', [], deployer).result;
    const pendingBefore: any = simnet.callReadOnlyFn(
      'lending-manager',
      'get-pending-protocol-fee',
      [Cl.principal(wallet2)],
      deployer,
    ).result;
    const accountingBefore: any = simnet.callReadOnlyFn(
      'protocol-fee-collector',
      'get-accounting',
      [Cl.principal(managerPrincipal), Cl.uint(77), Cl.uint(1), Cl.some(Cl.principal(mockTokenPrincipal))],
      deployer,
    ).result;
    const assetAccountingBefore: any = simnet.callReadOnlyFn(
      'protocol-fee-collector',
      'get-asset-accounting',
      [Cl.uint(1), Cl.some(Cl.principal(mockTokenPrincipal))],
      deployer,
    ).result;
    const totalSettlementsBefore: any = simnet.callReadOnlyFn(
      'protocol-fee-collector',
      'get-total-settlements',
      [],
      deployer,
    ).result;

    const failed = await simnet.callPublicFn(
      'lending-manager',
      'repay',
      [asset, Cl.uint(MAX_UINT), source],
      wallet2,
    );
    expect(failed.result).toEqual(Cl.error(Cl.uint(ERR_PROTOCOL_FEE_ARITHMETIC_OVERFLOW)));
    expect(simnet.callReadOnlyFn('lending-manager', 'get-reserve-data', [asset], deployer).result)
      .toEqual(reserveBefore);
    expect(simnet.callReadOnlyFn(
      'lending-manager',
      'get-user-borrow-balance',
      [Cl.principal(wallet2), Cl.principal(mockTokenPrincipal)],
      deployer,
    ).result).toEqual(borrowBefore);
    expect(tokenBalance('mock-token', wallet2)).toBe(userBefore);
    expect(tokenBalance('mock-token', managerPrincipal)).toBe(managerBefore);
    expect(tokenBalance('mock-token', `${deployer}.protocol-fee-collector`)).toBe(collectorBefore);
    expect(simnet.callReadOnlyFn('lending-manager', 'get-protocol-fee-nonce', [], deployer).result)
      .toEqual(nonceBefore);
    expect(simnet.callReadOnlyFn(
      'lending-manager',
      'get-pending-protocol-fee',
      [Cl.principal(wallet2)],
      deployer,
    ).result).toEqual(pendingBefore);
    expect(simnet.callReadOnlyFn(
      'protocol-fee-collector',
      'get-accounting',
      [Cl.principal(managerPrincipal), Cl.uint(77), Cl.uint(1), Cl.some(Cl.principal(mockTokenPrincipal))],
      deployer,
    ).result).toEqual(accountingBefore);
    expect(simnet.callReadOnlyFn(
      'protocol-fee-collector',
      'get-asset-accounting',
      [Cl.uint(1), Cl.some(Cl.principal(mockTokenPrincipal))],
      deployer,
    ).result).toEqual(assetAccountingBefore);
    expect(simnet.callReadOnlyFn('protocol-fee-collector', 'get-total-settlements', [], deployer).result)
      .toEqual(totalSettlementsBefore);
  });

  it('fails closed for invalid stream bindings, missing mappings, and rebinding attempts', async () => {
    const asset = Cl.contractPrincipal(deployer, 'cxvg-token');
    const source = Cl.contractPrincipal(deployer, 'lending-manager');
    expect(simnet.callPublicFn(
      'lending-manager',
      'configure-asset-collateral',
      [asset, Cl.uint(7500), Cl.uint(8000)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'cxvg-token',
      'mint',
      [Cl.uint(1000), Cl.principal(wallet1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const beforeUser = tokenBalance('cxvg-token', wallet1);
    const beforeManager = tokenBalance('cxvg-token', managerPrincipal);
    const beforeReserve: any = simnet.callReadOnlyFn('lending-manager', 'get-reserve-data', [asset], deployer).result;
    const beforeNonce: any = simnet.callReadOnlyFn('lending-manager', 'get-protocol-fee-nonce', [], deployer).result;
    const beforePending: any = simnet.callReadOnlyFn(
      'lending-manager',
      'get-pending-protocol-fee',
      [Cl.principal(wallet1)],
      deployer,
    ).result;
    expect(simnet.callPublicFn(
      'lending-manager',
      'repay',
      [asset, Cl.uint(1000), source],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(5010)));
    expect(tokenBalance('cxvg-token', wallet1)).toBe(beforeUser);
    expect(tokenBalance('cxvg-token', managerPrincipal)).toBe(beforeManager);
    expect(simnet.callReadOnlyFn('lending-manager', 'get-reserve-data', [asset], deployer).result)
      .toEqual(beforeReserve);
    expect(simnet.callReadOnlyFn('lending-manager', 'get-protocol-fee-nonce', [], deployer).result)
      .toEqual(beforeNonce);
    expect(simnet.callReadOnlyFn(
      'lending-manager',
      'get-pending-protocol-fee',
      [Cl.principal(wallet1)],
      deployer,
    ).result).toEqual(beforePending);
    expect(simnet.callPublicFn(
      'lending-manager',
      'set-protocol-fee-stream',
      [Cl.principal(mockTokenPrincipal), Cl.uint(78)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_PROTOCOL_FEE_STREAM_ALREADY_SET)));
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
