import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

const COLLECTOR = 'protocol-fee-collector';
const ASSET_KIND_STX = 2;
const ASSET_KIND_FT = 1;
const ROUTE_REVENUE_DISTRIBUTOR = 1;
const ERR_UNAUTHORIZED = 4100;
const ERR_PAUSED = 4101;
const ERR_SOURCE_NOT_AUTHORIZED = 4104;
const ERR_STREAM_INACTIVE = 4106;
const ERR_INVALID_ROUTE = 4107;
const ERR_INVALID_AMOUNT = 4109;
const ERR_SETTLEMENT_REPLAYED = 4110;

describe('Canonical protocol fee collector', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let collectorPrincipal: string;
  let revenueDistributor: string;
  let swapRouter: string;

  const settlementId = (fill: number) => Cl.buffer(Buffer.alloc(32, fill));

  const readUint = (functionName: string, args: any[] = []): bigint => {
    const result: any = simnet.callReadOnlyFn(COLLECTOR, functionName, args, deployer).result;
    expect(result.type).toBe('ok');
    return BigInt(result.value.value);
  };

  const readTuple = (functionName: string, args: any[] = []): Record<string, any> => {
    const result: any = simnet.callReadOnlyFn(COLLECTOR, functionName, args, deployer).result;
    expect(result.type).toBe('ok');
    expect(result.value.type).toBe('tuple');
    return result.value.value;
  };

  const readOptionalTuple = (functionName: string, args: any[] = []): Record<string, any> | null => {
    const result: any = simnet.callReadOnlyFn(COLLECTOR, functionName, args, deployer).result;
    expect(result.type).toBe('ok');
    if (result.value.type === 'none') return null;
    expect(result.value.type).toBe('some');
    expect(result.value.value.type).toBe('tuple');
    return result.value.value.value;
  };

  const stxBalance = (principal: string): bigint =>
    simnet.getAssetsMap().get('STX')?.get(principal) ?? 0n;

  const mockTokenBalance = (principal: string): bigint => {
    const result: any = simnet.callReadOnlyFn(
      'mock-token',
      'get-balance',
      [Cl.principal(principal)],
      deployer,
    ).result;
    expect(result.type).toBe('ok');
    return BigInt(result.value.value);
  };

  const registerStxStream = (source: string, streamId: number) => {
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-authorized-source',
      [Cl.principal(source), Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(
      COLLECTOR,
      'register-stx-stream',
      [Cl.principal(source), Cl.uint(streamId), Cl.uint(ROUTE_REVENUE_DISTRIBUTOR)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
  };

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
    collectorPrincipal = `${deployer}.${COLLECTOR}`;
    revenueDistributor = `${deployer}.revenue-distributor`;
    swapRouter = `${deployer}.swap-router`;
    simnet.mintSTX(wallet1, 10_000_000n);
  });

  it('resolves exact launch, growth, and mature boundaries and rounds positive fees up', () => {
    const schedule = readTuple('get-schedule');
    const activation = BigInt(schedule['activation-burn-height'].value);
    const growthBoundary = BigInt(schedule['growth-boundary-inclusive'].value);
    const matureBoundary = BigInt(schedule['mature-boundary-inclusive'].value);

    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'get-rate-at-burn-height',
      [Cl.uint(activation)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.tuple({ phase: Cl.uint(1), 'rate-bps': Cl.uint(200) })));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'get-rate-at-burn-height',
      [Cl.uint(growthBoundary - 1n)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.tuple({ phase: Cl.uint(1), 'rate-bps': Cl.uint(200) })));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'get-rate-at-burn-height',
      [Cl.uint(growthBoundary)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.tuple({ phase: Cl.uint(2), 'rate-bps': Cl.uint(150) })));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'get-rate-at-burn-height',
      [Cl.uint(matureBoundary - 1n)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.tuple({ phase: Cl.uint(2), 'rate-bps': Cl.uint(150) })));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'get-rate-at-burn-height',
      [Cl.uint(matureBoundary)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.tuple({ phase: Cl.uint(3), 'rate-bps': Cl.uint(100) })));

    // Ceiling rounding charges one native unit for every positive base that
    // produces a fractional fee, so splitting cannot silently reduce fees to 0.
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'calculate-fee-at',
      [Cl.uint(1), Cl.uint(activation)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(1)));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'calculate-fee-at',
      [Cl.uint(10_000), Cl.uint(activation)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(200)));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'calculate-fee-at',
      [Cl.uint(10_000), Cl.uint(growthBoundary)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(150)));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'calculate-fee-at',
      [Cl.uint(10_000), Cl.uint(matureBoundary)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(100)));
  });

  it('requires admin source registration, fixed routing, and pause controls', () => {
    const streamId = 1001;

    expect(simnet.callPublicFn(
      COLLECTOR,
      'pause',
      [],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'register-stx-stream',
      [Cl.principal(wallet2), Cl.uint(streamId), Cl.uint(ROUTE_REVENUE_DISTRIBUTOR)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_SOURCE_NOT_AUTHORIZED)));

    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-authorized-source',
      [Cl.principal(wallet1), Cl.bool(true)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));
    registerStxStream(wallet1, streamId);

    expect(simnet.callPublicFn(
      COLLECTOR,
      'register-stx-stream',
      [Cl.principal(wallet1), Cl.uint(streamId + 1), Cl.uint(2)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_INVALID_ROUTE)));

    const config = readOptionalTuple('get-stream-config', [
      Cl.principal(wallet1),
      Cl.uint(streamId),
      Cl.uint(ASSET_KIND_STX),
      Cl.none(),
    ]);
    expect(config?.active).toEqual(Cl.bool(true));
    expect(config?.route).toEqual(Cl.uint(ROUTE_REVENUE_DISTRIBUTOR));

    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-stream-active',
      [
        Cl.principal(wallet1),
        Cl.uint(streamId),
        Cl.uint(ASSET_KIND_STX),
        Cl.none(),
        Cl.bool(false),
      ],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(streamId), Cl.uint(10_000), settlementId(1)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_STREAM_INACTIVE)));

    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-stream-active',
      [
        Cl.principal(wallet1),
        Cl.uint(streamId),
        Cl.uint(ASSET_KIND_STX),
        Cl.none(),
        Cl.bool(true),
      ],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(COLLECTOR, 'pause', [], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(COLLECTOR, 'is-paused', [], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(streamId), Cl.uint(10_000), settlementId(2)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_PAUSED)));
    expect(simnet.callPublicFn(COLLECTOR, 'unpause', [], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(COLLECTOR, 'is-paused', [], deployer).result)
      .toEqual(Cl.ok(Cl.bool(false)));

    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(streamId), Cl.uint(0), settlementId(3)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_INVALID_AMOUNT)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(streamId), Cl.uint(10_000), settlementId(4)],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(ERR_SOURCE_NOT_AUTHORIZED)));
  });

  it('settles STX atomically, emits an indexed event, rejects replay, and accumulates native accounting', () => {
    const streamId = 1002;
    const idOne = settlementId(10);
    const idTwo = settlementId(11);
    registerStxStream(wallet1, streamId);

    const baseOne = 10_000n;
    const baseTwo = 5_000n;
    const feeOneResult: any = simnet.callReadOnlyFn(
      COLLECTOR,
      'calculate-current-fee',
      [Cl.uint(baseOne)],
      deployer,
    ).result;
    const feeTwoResult: any = simnet.callReadOnlyFn(
      COLLECTOR,
      'calculate-current-fee',
      [Cl.uint(baseTwo)],
      deployer,
    ).result;
    expect(feeOneResult.type).toBe('ok');
    expect(feeTwoResult.type).toBe('ok');
    const feeOne = BigInt(feeOneResult.value.value);
    const feeTwo = BigInt(feeTwoResult.value.value);

    const payerBefore = stxBalance(wallet1);
    const routerBefore = stxBalance(swapRouter);
    const collectorBefore = stxBalance(collectorPrincipal);
    const receipt: any = simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(streamId), Cl.uint(baseOne), idOne],
      wallet1,
    );
    expect(receipt.result).toEqual(Cl.ok(Cl.uint(feeOne)));
    expect(stxBalance(wallet1)).toBe(payerBefore - feeOne);
    expect(stxBalance(swapRouter)).toBe(routerBefore + feeOne);
    expect(stxBalance(collectorPrincipal)).toBe(collectorBefore);
    expect(JSON.stringify(receipt.events)).toContain('protocol-fee-settled');

    const accountingAfterOne = readOptionalTuple('get-accounting', [
      Cl.principal(wallet1),
      Cl.uint(streamId),
      Cl.uint(ASSET_KIND_STX),
      Cl.none(),
    ]);
    expect(accountingAfterOne?.['eligible-base']).toEqual(Cl.uint(baseOne));
    expect(accountingAfterOne?.['assessed-fees']).toEqual(Cl.uint(feeOne));
    expect(accountingAfterOne?.['settled-fees']).toEqual(Cl.uint(feeOne));
    expect(accountingAfterOne?.['settlement-count']).toEqual(Cl.uint(1));

    const settlement = readOptionalTuple('get-settlement', [idOne]);
    expect(settlement?.source).toEqual(Cl.principal(wallet1));
    expect(settlement?.['stream-id']).toEqual(Cl.uint(streamId));
    expect(settlement?.['asset-kind']).toEqual(Cl.uint(ASSET_KIND_STX));
    expect(settlement?.asset).toEqual(Cl.none());
    expect(settlement?.payer).toEqual(Cl.principal(wallet1));
    expect(settlement?.['eligible-base']).toEqual(Cl.uint(baseOne));
    expect(settlement?.['assessed-amount']).toEqual(Cl.uint(feeOne));
    expect(settlement?.['settled-amount']).toEqual(Cl.uint(feeOne));

    const payerBeforeReplay = stxBalance(wallet1);
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(streamId), Cl.uint(baseOne), idOne],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_SETTLEMENT_REPLAYED)));
    expect(stxBalance(wallet1)).toBe(payerBeforeReplay);

    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(streamId), Cl.uint(baseTwo), idTwo],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(feeTwo)));
    const accountingAfterTwo = readOptionalTuple('get-accounting', [
      Cl.principal(wallet1),
      Cl.uint(streamId),
      Cl.uint(ASSET_KIND_STX),
      Cl.none(),
    ]);
    expect(accountingAfterTwo?.['eligible-base']).toEqual(Cl.uint(baseOne + baseTwo));
    expect(accountingAfterTwo?.['assessed-fees']).toEqual(Cl.uint(feeOne + feeTwo));
    expect(accountingAfterTwo?.['settled-fees']).toEqual(Cl.uint(feeOne + feeTwo));
    expect(accountingAfterTwo?.['settlement-count']).toEqual(Cl.uint(2));
    expect(readUint('get-total-settlements')).toBe(2n);
  });

  it('fails closed and rolls back token state when the downstream FT route rejects settlement', () => {
    const streamId = 1003;
    const token = `${deployer}.mock-token`;
    registerStxStream(wallet1, streamId);
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-authorized-source',
      [Cl.principal(wallet1), Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'register-ft-stream',
      [Cl.principal(wallet1), Cl.uint(streamId), Cl.principal(token), Cl.uint(ROUTE_REVENUE_DISTRIBUTOR)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'mock-token',
      'mint',
      [Cl.uint(10_000), Cl.principal(wallet1)],
      deployer,
    ).result.type).toBe('ok');

    const payerBefore = mockTokenBalance(wallet1);
    const distributorBefore = mockTokenBalance(revenueDistributor);
    const collectorBefore = mockTokenBalance(collectorPrincipal);
    const receipt: any = simnet.callPublicFn(
      COLLECTOR,
      'settle-ft',
      // The existing non-CXD distributor path is intentionally not treated as
      // a successful generic-token route in phase 1. The collector must roll
      // back the payer transfer when that downstream path rejects.
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(streamId), Cl.uint(100_000), settlementId(20)],
      wallet1,
    );
    expect(receipt.result.type).toBe('err');
    expect(mockTokenBalance(wallet1)).toBe(payerBefore);
    expect(mockTokenBalance(revenueDistributor)).toBe(distributorBefore);
    expect(mockTokenBalance(collectorPrincipal)).toBe(collectorBefore);
    expect(readOptionalTuple('get-accounting', [
      Cl.principal(wallet1),
      Cl.uint(streamId),
      Cl.uint(ASSET_KIND_FT),
      Cl.some(Cl.principal(token)),
    ])).toBeNull();
  });
});
