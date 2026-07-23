import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

const COLLECTOR = 'protocol-fee-collector';
const ASSET_KIND_STX = 2;
const ASSET_KIND_FT = 1;
const ROUTE_PROTOCOL_INGRESS = 1;
const ERR_UNAUTHORIZED = 4100;
const ERR_PAUSED = 4101;
const ERR_NOT_ACTIVE = 4102;
const ERR_SOURCE_NOT_AUTHORIZED = 4104;
const ERR_STREAM_INACTIVE = 4106;
const ERR_INVALID_ROUTE = 4107;
const ERR_INVALID_AMOUNT = 4109;
const ERR_SETTLEMENT_REPLAYED = 4110;
const ERR_STREAM_ALREADY_REGISTERED = 4117;
const ERR_EXCESS_RECOVERY_EXCEEDS_AVAILABLE = 4122;
const MODE_EXACT = 0;
const MODE_UNDERPAY = 1;
const MODE_OVERPAY = 2;
const MODE_NO_TRANSFER = 3;
const MODE_WRONG_DESTINATION = 4;
const MODE_WRONG_ASSET = 5;

describe('Canonical protocol fee collector', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let collectorPrincipal: string;
  let operationalTreasury: string;
  let governanceProxy: string;
  let mockToken: string;
  let mockFeeSource: string;
  let cxvgToken: string;

  const settlementId = (fill: number) => Cl.buffer(Buffer.alloc(32, fill));

  const readUint = (functionName: string, args: any[] = []): bigint => {
    const result: any = simnet.callReadOnlyFn(COLLECTOR, functionName, args, deployer).result;
    expect(result.type).toBe('ok');
    return BigInt(result.value.value);
  };

  const readMockUint = (functionName: string): bigint => {
    const result: any = simnet.callReadOnlyFn('mock-fee-source', functionName, [], deployer).result;
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

  const printEvent = (receipt: any): any => {
    const event = receipt.events.find((candidate: any) => candidate.event === 'print_event');
    expect(event).toBeDefined();
    return event.data.value;
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
      [Cl.principal(source), Cl.uint(streamId), Cl.uint(ROUTE_PROTOCOL_INGRESS)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
  };

  const registerFtStream = (source: string, streamId: number) => {
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-authorized-source',
      [Cl.principal(source), Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(
      COLLECTOR,
      'register-ft-stream',
      [
        Cl.principal(source),
        Cl.uint(streamId),
        Cl.principal(mockToken),
        Cl.uint(ROUTE_PROTOCOL_INGRESS),
      ],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
  };

  const registerSourceFtStream = (streamId: number, token: string) => {
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-authorized-source',
      [Cl.principal(mockFeeSource), Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'register-ft-stream',
      [Cl.principal(mockFeeSource), Cl.uint(streamId), Cl.principal(token), Cl.uint(ROUTE_PROTOCOL_INGRESS)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
  };

  const registerSourceStxStream = (streamId: number) => {
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-authorized-source',
      [Cl.principal(mockFeeSource), Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'register-stx-stream',
      [Cl.principal(mockFeeSource), Cl.uint(streamId), Cl.uint(ROUTE_PROTOCOL_INGRESS)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
  };

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
    collectorPrincipal = `${deployer}.${COLLECTOR}`;
    operationalTreasury = `${deployer}.operational-treasury`;
    governanceProxy = `${deployer}.test-c4-helper`;
    mockToken = `${deployer}.mock-token`;
    mockFeeSource = `${deployer}.mock-fee-source`;
    cxvgToken = `${deployer}.cxvg-token`;
    simnet.mintSTX(wallet1, 100_000_000n);
    simnet.mintSTX(wallet2, 100_000_000n);
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'fund-stx',
      [Cl.uint(1_000_000)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('uses exact burn-block boundaries, future activation errors, and residual-free read-only arithmetic', () => {
    const schedule = readTuple('get-schedule');
    const activation = BigInt(schedule['activation-burn-height'].value);
    const growthBoundary = BigInt(schedule['growth-boundary-inclusive'].value);
    const matureBoundary = BigInt(schedule['mature-boundary-inclusive'].value);

    expect(growthBoundary - activation).toBe(52_560n);
    expect(matureBoundary - activation).toBe(157_680n);
    expect(schedule['burn-blocks-per-year']).toEqual(Cl.uint(52_560));
    expect(schedule['growth-phase-years']).toEqual(Cl.uint(1));
    expect(schedule['mature-phase-years']).toEqual(Cl.uint(3));

    if (activation > 0n) {
      expect(simnet.callReadOnlyFn(
        COLLECTOR,
        'get-rate-at-burn-height',
        [Cl.uint(activation - 1n)],
        deployer,
      ).result).toEqual(Cl.error(Cl.uint(ERR_NOT_ACTIVE)));
    }
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

    // Read-only arithmetic starts with zero residual: 49 * 200 / 10,000 is
    // zero, while 50 * 200 / 10,000 is one. Settlement calls carry the
    // remainder across splits.
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'calculate-fee-at',
      [Cl.uint(49), Cl.uint(activation)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(0)));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'calculate-fee-at',
      [Cl.uint(50), Cl.uint(activation)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(1)));
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

    const currentHeight = BigInt(simnet.mineEmptyBlocks(0));
    const futureActivation = currentHeight + 100n;
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-activation-burn-height',
      [Cl.uint(futureActivation)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(futureActivation)));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'get-rate-at-burn-height',
      [Cl.uint(futureActivation - 1n)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_NOT_ACTIVE)));
    // Restore a launchable anchor before any settlement is accepted.
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-activation-burn-height',
      [Cl.uint(currentHeight)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(currentHeight)));
  });

  it('uses fixed collector custody and separates admin from contract-only governance authority', () => {
    expect(simnet.callReadOnlyFn(COLLECTOR, 'get-collector-ingress', [], deployer).result)
      .toEqual(Cl.ok(Cl.principal(collectorPrincipal)));

    expect(simnet.callPublicFn(
      COLLECTOR,
      'pause',
      [],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));
    // The governance slot is tested with a contract stand-in. Production
    // deployment must use the approved DAO/timelock contract, never a wallet.
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-governance',
      [Cl.principal(wallet2)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'pause',
      [],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-governance',
      [Cl.principal(governanceProxy)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-authorized-source',
      [Cl.principal(wallet2), Cl.bool(true)],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'pause',
      [],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'route-stx',
      [Cl.uint(1)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));
    expect(simnet.callReadOnlyFn(COLLECTOR, 'get-governance', [], deployer).result)
      .toEqual(Cl.ok(Cl.principal(governanceProxy)));

    expect(simnet.callPublicFn('test-c4-helper', 'collector-pause', [], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn('test-c4-helper', 'collector-unpause', [], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(
      COLLECTOR,
      'register-stx-stream',
      [Cl.principal(wallet1), Cl.uint(1001), Cl.uint(ROUTE_PROTOCOL_INGRESS)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_SOURCE_NOT_AUTHORIZED)));
    registerStxStream(wallet1, 1001);

    expect(simnet.callPublicFn(
      COLLECTOR,
      'register-stx-stream',
      [Cl.principal(wallet1), Cl.uint(1002), Cl.uint(2)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_INVALID_ROUTE)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'register-ft-stream',
      [Cl.principal(wallet1), Cl.uint(1001), Cl.principal(mockToken), Cl.uint(ROUTE_PROTOCOL_INGRESS)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_STREAM_ALREADY_REGISTERED)));

    const config = readOptionalTuple('get-stream-config', [
      Cl.principal(wallet1),
      Cl.uint(1001),
      Cl.uint(ASSET_KIND_STX),
      Cl.none(),
    ]);
    expect(config?.['asset-kind']).toEqual(Cl.uint(ASSET_KIND_STX));
    expect(config?.asset).toEqual(Cl.none());
    expect(config?.active).toEqual(Cl.bool(true));
    expect(config?.route).toEqual(Cl.uint(ROUTE_PROTOCOL_INGRESS));

    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-stream-active',
      [Cl.principal(wallet1), Cl.uint(1001), Cl.uint(ASSET_KIND_STX), Cl.none(), Cl.bool(false)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(1001), Cl.uint(10_000), settlementId(1)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_STREAM_INACTIVE)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-stream-active',
      [Cl.principal(wallet1), Cl.uint(1001), Cl.uint(ASSET_KIND_STX), Cl.none(), Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(COLLECTOR, 'pause', [], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(1001), Cl.uint(10_000), settlementId(2)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_PAUSED)));
    expect(simnet.callPublicFn(COLLECTOR, 'unpause', [], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(1001), Cl.uint(0), settlementId(3)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_INVALID_AMOUNT)));
  });

  it('settles STX to collector custody, routes explicitly, and scopes replay by source', () => {
    const streamId = 1003;
    const id = settlementId(10);
    const base = 10_000n;
    registerStxStream(wallet1, streamId);

    const fee = readUint('calculate-current-fee', [Cl.uint(base)]);
    const payerBefore = stxBalance(wallet1);
    const treasuryBefore = stxBalance(operationalTreasury);
    const collectorBefore = stxBalance(collectorPrincipal);
    const receipt: any = simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(streamId), Cl.uint(base), id],
      wallet1,
    );
    expect(receipt.result).toEqual(Cl.ok(Cl.uint(fee)));
    expect(stxBalance(wallet1)).toBe(payerBefore - fee);
    expect(stxBalance(operationalTreasury)).toBe(treasuryBefore);
    expect(stxBalance(collectorPrincipal)).toBe(collectorBefore + fee);

    const accounting = readOptionalTuple('get-accounting', [
      Cl.principal(wallet1),
      Cl.uint(streamId),
      Cl.uint(ASSET_KIND_STX),
      Cl.none(),
    ]);
    expect(accounting?.['eligible-base']).toEqual(Cl.uint(base));
    expect(accounting?.['assessed-fees']).toEqual(Cl.uint(fee));
    expect(accounting?.['settled-fees']).toEqual(Cl.uint(fee));
    expect(accounting?.['settlement-count']).toEqual(Cl.uint(1));
    expect(accounting?.['fee-remainder']).toEqual(Cl.uint(0));

    const settlement = readOptionalTuple('get-settlement', [Cl.principal(wallet1), id]);
    expect(settlement?.['settlement-id']).toEqual(id);
    expect(settlement?.source).toEqual(Cl.principal(wallet1));
    expect(settlement?.['stream-id']).toEqual(Cl.uint(streamId));
    expect(settlement?.['asset-kind']).toEqual(Cl.uint(ASSET_KIND_STX));
    expect(settlement?.asset).toEqual(Cl.none());
    expect(settlement?.payer).toEqual(Cl.principal(wallet1));
    expect(settlement?.['eligible-base']).toEqual(Cl.uint(base));
    expect(settlement?.['rate-bps']).toEqual(Cl.uint(200));
    expect(settlement?.phase).toEqual(Cl.uint(1));
    expect(settlement?.['assessed-amount']).toEqual(Cl.uint(fee));
    expect(settlement?.['settled-amount']).toEqual(Cl.uint(fee));
    expect(settlement?.recipient).toEqual(Cl.principal(collectorPrincipal));
    expect(settlement?.['burn-height']).toBeDefined();
    expect(settlement?.['stacks-height']).toBeDefined();

    expect(printEvent(receipt)).toEqual(Cl.tuple({
      event: Cl.stringAscii('protocol-fee-collected'),
      'settlement-id': id,
      source: Cl.principal(wallet1),
      'stream-id': Cl.uint(streamId),
      payer: Cl.principal(wallet1),
      'asset-kind': Cl.uint(ASSET_KIND_STX),
      asset: Cl.none(),
      'eligible-fee-base': Cl.uint(base),
      'rate-bps': Cl.uint(200),
      phase: Cl.uint(1),
      'assessed-amount': Cl.uint(fee),
      'settled-amount': Cl.uint(fee),
      recipient: Cl.principal(collectorPrincipal),
      'burn-height': settlement?.['burn-height'],
      'stacks-height': settlement?.['stacks-height'],
    }));

    const failedRouteCollector = stxBalance(collectorPrincipal);
    const failedRouteTreasury = stxBalance(operationalTreasury);
    const failedRoute: any = simnet.callPublicFn(
      COLLECTOR,
      'route-stx',
      [Cl.uint(fee + 1n)],
      deployer,
    );
    expect(failedRoute.result.type).toBe('err');
    expect(stxBalance(collectorPrincipal)).toBe(failedRouteCollector);
    expect(stxBalance(operationalTreasury)).toBe(failedRouteTreasury);
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'get-total-routed-stx',
      [],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(0)));

    const routeCollectorBefore = stxBalance(collectorPrincipal);
    const routeTreasuryBefore = stxBalance(operationalTreasury);
    const routeReceipt: any = simnet.callPublicFn(
      'test-c4-helper',
      'collector-route-stx',
      [Cl.uint(fee)],
      deployer,
    );
    expect(routeReceipt.result).toEqual(Cl.ok(Cl.uint(fee)));
    expect(stxBalance(collectorPrincipal)).toBe(routeCollectorBefore - fee);
    expect(stxBalance(operationalTreasury)).toBe(routeTreasuryBefore + fee);
    const routeEvent: any = printEvent(routeReceipt);
    expect(routeEvent.value.event).toEqual(Cl.stringAscii('protocol-fee-routed-to-operational-treasury'));
    expect(routeEvent.value['asset-kind']).toEqual(Cl.uint(ASSET_KIND_STX));
    expect(routeEvent.value.asset).toEqual(Cl.none());
    expect(routeEvent.value.amount).toEqual(Cl.uint(fee));
    expect(routeEvent.value.collector).toEqual(Cl.principal(collectorPrincipal));
    expect(routeEvent.value.destination).toEqual(Cl.principal(operationalTreasury));
    expect(routeEvent.value['collected-total']).toEqual(Cl.uint(fee));
    expect(routeEvent.value['routed-total']).toEqual(Cl.uint(fee));
    expect(routeEvent.value['route-count']).toEqual(Cl.uint(1));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'get-total-collected-stx',
      [],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(fee)));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'get-total-routed-stx',
      [],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(fee)));

    const payerBeforeReplay = stxBalance(wallet1);
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(streamId), Cl.uint(base), id],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_SETTLEMENT_REPLAYED)));
    expect(stxBalance(wallet1)).toBe(payerBeforeReplay);

    // The same local ID is valid for a distinct authorized source because the
    // replay key is (source, settlement-id), not settlement-id alone.
    registerStxStream(wallet2, 1004);
    const wallet2Before = stxBalance(wallet2);
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(1004), Cl.uint(base), id],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.uint(fee)));
    expect(stxBalance(wallet2)).toBe(wallet2Before - fee);
    expect(readOptionalTuple('get-settlement', [Cl.principal(wallet2), id])?.source)
      .toEqual(Cl.principal(wallet2));
  });

  it('settles SIP-010 tokens to collector custody, routes them explicitly, and rolls back failures', () => {
    const streamId = 1005;
    registerFtStream(wallet1, streamId);
    expect(simnet.callPublicFn(
      'mock-token',
      'mint',
      [Cl.uint(10_000), Cl.principal(wallet1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const base = 10_000n;
    const fee = 200n;
    const id = settlementId(20);
    const payerBefore = mockTokenBalance(wallet1);
    const recipientBefore = mockTokenBalance(operationalTreasury);
    const collectorBefore = mockTokenBalance(collectorPrincipal);
    const receipt: any = simnet.callPublicFn(
      COLLECTOR,
      'settle-ft',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(streamId), Cl.uint(base), id],
      wallet1,
    );
    expect(receipt.result).toEqual(Cl.ok(Cl.uint(fee)));
    expect(mockTokenBalance(wallet1)).toBe(payerBefore - fee);
    expect(mockTokenBalance(operationalTreasury)).toBe(recipientBefore);
    expect(mockTokenBalance(collectorPrincipal)).toBe(collectorBefore + fee);

    const settlement = readOptionalTuple('get-settlement', [Cl.principal(wallet1), id]);
    expect(settlement?.source).toEqual(Cl.principal(wallet1));
    expect(settlement?.['asset-kind']).toEqual(Cl.uint(ASSET_KIND_FT));
    expect(settlement?.asset).toEqual(Cl.some(Cl.principal(mockToken)));
    expect(settlement?.recipient).toEqual(Cl.principal(collectorPrincipal));
    expect(printEvent(receipt)).toEqual(Cl.tuple({
      event: Cl.stringAscii('protocol-fee-collected'),
      'settlement-id': id,
      source: Cl.principal(wallet1),
      'stream-id': Cl.uint(streamId),
      payer: Cl.principal(wallet1),
      'asset-kind': Cl.uint(ASSET_KIND_FT),
      asset: Cl.some(Cl.principal(mockToken)),
      'eligible-fee-base': Cl.uint(base),
      'rate-bps': Cl.uint(200),
      phase: Cl.uint(1),
      'assessed-amount': Cl.uint(fee),
      'settled-amount': Cl.uint(fee),
      recipient: Cl.principal(collectorPrincipal),
      'burn-height': settlement?.['burn-height'],
      'stacks-height': settlement?.['stacks-height'],
    }));

    const routeReceipt: any = simnet.callPublicFn(
      'test-c4-helper',
      'collector-route-ft',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(fee)],
      deployer,
    );
    expect(routeReceipt.result).toEqual(Cl.ok(Cl.uint(fee)));
    expect(mockTokenBalance(collectorPrincipal)).toBe(collectorBefore);
    expect(mockTokenBalance(operationalTreasury)).toBe(recipientBefore + fee);
    const routeEvent: any = printEvent(routeReceipt);
    expect(routeEvent.value.event).toEqual(Cl.stringAscii('protocol-fee-routed-to-operational-treasury'));
    expect(routeEvent.value['asset-kind']).toEqual(Cl.uint(ASSET_KIND_FT));
    expect(routeEvent.value.asset).toEqual(Cl.some(Cl.principal(mockToken)));
    expect(routeEvent.value.amount).toEqual(Cl.uint(fee));
    expect(routeEvent.value.collector).toEqual(Cl.principal(collectorPrincipal));
    expect(routeEvent.value.destination).toEqual(Cl.principal(operationalTreasury));
    expect(routeEvent.value['collected-total']).toEqual(Cl.uint(fee));
    expect(routeEvent.value['routed-total']).toEqual(Cl.uint(fee));
    expect(routeEvent.value['route-count']).toEqual(Cl.uint(1));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'get-collected-ft',
      [Cl.principal(mockToken)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(fee)));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'get-routed-ft',
      [Cl.principal(mockToken)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(fee)));

    const failedRouteCollector = mockTokenBalance(collectorPrincipal);
    const failedRouteTreasury = mockTokenBalance(operationalTreasury);
    const failedRoute: any = simnet.callPublicFn(
      COLLECTOR,
      'route-ft',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(1)],
      deployer,
    );
    expect(failedRoute.result.type).toBe('err');
    expect(mockTokenBalance(collectorPrincipal)).toBe(failedRouteCollector);
    expect(mockTokenBalance(operationalTreasury)).toBe(failedRouteTreasury);
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'get-routed-ft',
      [Cl.principal(mockToken)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(fee)));

    const failedStream = 1006;
    registerFtStream(wallet1, failedStream);
    const failedId = settlementId(21);
    const failedPayerBefore = mockTokenBalance(wallet1);
    const failedRecipientBefore = mockTokenBalance(operationalTreasury);
    const failedCollectorBefore = mockTokenBalance(collectorPrincipal);
    const failedReceipt: any = simnet.callPublicFn(
      COLLECTOR,
      'settle-ft',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(failedStream), Cl.uint(500_000), failedId],
      wallet1,
    );
    expect(failedReceipt.result.type).toBe('err');
    expect(mockTokenBalance(wallet1)).toBe(failedPayerBefore);
    expect(mockTokenBalance(operationalTreasury)).toBe(failedRecipientBefore);
    expect(mockTokenBalance(collectorPrincipal)).toBe(failedCollectorBefore);
    expect(readOptionalTuple('get-accounting', [
      Cl.principal(wallet1),
      Cl.uint(failedStream),
      Cl.uint(ASSET_KIND_FT),
      Cl.some(Cl.principal(mockToken)),
    ])).toBeNull();
    expect(readOptionalTuple('get-settlement', [Cl.principal(wallet1), failedId])).toBeNull();
  });

  it('preserves residuals across split settlements, audits zero-fee bases, and prevents stream identity replacement', () => {
    const splitStream = 1007;
    registerStxStream(wallet1, splitStream);
    const zeroFeeId = settlementId(30);
    const oneFeeId = settlementId(31);
    const payerBefore = stxBalance(wallet1);

    const zeroFeeReceipt: any = simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(splitStream), Cl.uint(49), zeroFeeId],
      wallet1,
    );
    expect(zeroFeeReceipt.result).toEqual(Cl.ok(Cl.uint(0)));
    expect(stxBalance(wallet1)).toBe(payerBefore);
    const afterZero = readOptionalTuple('get-accounting', [
      Cl.principal(wallet1),
      Cl.uint(splitStream),
      Cl.uint(ASSET_KIND_STX),
      Cl.none(),
    ]);
    expect(afterZero?.['eligible-base']).toEqual(Cl.uint(49));
    expect(afterZero?.['assessed-fees']).toEqual(Cl.uint(0));
    expect(afterZero?.['settled-fees']).toEqual(Cl.uint(0));
    expect(afterZero?.['settlement-count']).toEqual(Cl.uint(1));
    expect(afterZero?.['fee-remainder']).toEqual(Cl.uint(9_800));
    expect(printEvent(zeroFeeReceipt)).toEqual(Cl.tuple({
      event: Cl.stringAscii('protocol-fee-collected'),
      'settlement-id': zeroFeeId,
      source: Cl.principal(wallet1),
      'stream-id': Cl.uint(splitStream),
      payer: Cl.principal(wallet1),
      'asset-kind': Cl.uint(ASSET_KIND_STX),
      asset: Cl.none(),
      'eligible-fee-base': Cl.uint(49),
      'rate-bps': Cl.uint(200),
      phase: Cl.uint(1),
      'assessed-amount': Cl.uint(0),
      'settled-amount': Cl.uint(0),
      recipient: Cl.principal(collectorPrincipal),
      'burn-height': afterZero?.['last-settled-burn-height'],
      'stacks-height': afterZero?.['last-settled-stacks-height'],
    }));

    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(splitStream), Cl.uint(1), oneFeeId],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(1)));
    expect(stxBalance(wallet1)).toBe(payerBefore - 1n);
    const afterSplit = readOptionalTuple('get-accounting', [
      Cl.principal(wallet1),
      Cl.uint(splitStream),
      Cl.uint(ASSET_KIND_STX),
      Cl.none(),
    ]);
    expect(afterSplit?.['eligible-base']).toEqual(Cl.uint(50));
    expect(afterSplit?.['assessed-fees']).toEqual(Cl.uint(1));
    expect(afterSplit?.['settled-fees']).toEqual(Cl.uint(1));
    expect(afterSplit?.['fee-remainder']).toEqual(Cl.uint(0));

    const aggregateStream = 1008;
    registerStxStream(wallet1, aggregateStream);
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(aggregateStream), Cl.uint(50), settlementId(32)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(1)));
    expect(readOptionalTuple('get-accounting', [
      Cl.principal(wallet1),
      Cl.uint(aggregateStream),
      Cl.uint(ASSET_KIND_STX),
      Cl.none(),
    ])?.['assessed-fees']).toEqual(Cl.uint(1));

    // A used stream cannot be re-registered under a different asset or route;
    // registration is immutable and active state is the only mutable control.
    expect(simnet.callPublicFn(
      COLLECTOR,
      'register-stx-stream',
      [Cl.principal(wallet1), Cl.uint(splitStream), Cl.uint(ROUTE_PROTOCOL_INGRESS)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_STREAM_ALREADY_REGISTERED)));
  });

  it('carries a remainder through the exact launch-to-growth boundary', () => {
    const streamId = 1009;
    registerStxStream(wallet1, streamId);
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(streamId), Cl.uint(49), settlementId(40)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(0)));

    const schedule = readTuple('get-schedule');
    const growthBoundary = BigInt(schedule['growth-boundary-inclusive'].value);
    const currentHeight = BigInt(simnet.mineEmptyBlocks(0));
    if (growthBoundary > currentHeight) {
      simnet.mineEmptyBlocks(Number(growthBoundary - currentHeight));
    }

    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'get-current-rate',
      [],
      deployer,
    ).result).toEqual(Cl.ok(Cl.tuple({ phase: Cl.uint(2), 'rate-bps': Cl.uint(150) })));

    // The launch remainder is 9,800. At growth rate, base 2 contributes 300,
    // so the carried numerator reaches 10,100 and settles one native unit.
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(streamId), Cl.uint(2), settlementId(41)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(1)));
    const accounting = readOptionalTuple('get-accounting', [
      Cl.principal(wallet1),
      Cl.uint(streamId),
      Cl.uint(ASSET_KIND_STX),
      Cl.none(),
    ]);
    expect(accounting?.['eligible-base']).toEqual(Cl.uint(51));
    expect(accounting?.['assessed-fees']).toEqual(Cl.uint(1));
    expect(accounting?.['fee-remainder']).toEqual(Cl.uint(100));
    expect(accounting?.['last-rate-bps']).toEqual(Cl.uint(150));
    expect(accounting?.['last-phase']).toEqual(Cl.uint(2));
  });

  it('recovers only excess direct STX deposits to operational treasury', () => {
    const streamId = 1010;
    registerStxStream(wallet1, streamId);
    const fee = readUint('calculate-current-fee', [Cl.uint(10_000)]);
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-stx',
      [Cl.uint(streamId), Cl.uint(10_000), settlementId(50)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(fee)));

    const directDeposit = 50n;
    const directDepositorBefore = stxBalance(wallet1);
    const collectorBeforeDeposit = stxBalance(collectorPrincipal);
    expect(simnet.callPublicFn(
      'test-c4-helper',
      'deposit-stx-to-collector',
      [Cl.uint(directDeposit)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(stxBalance(wallet1)).toBe(directDepositorBefore - directDeposit);
    expect(stxBalance(collectorPrincipal)).toBe(collectorBeforeDeposit + directDeposit);

    const routedBefore = readUint('get-total-routed-stx');
    const routesBefore = readUint('get-total-routes');
    const recoveredBefore = readUint('get-excess-recovered-stx');
    const collectorBeforeRejectedRecovery = stxBalance(collectorPrincipal);
    const treasuryBeforeRejectedRecovery = stxBalance(operationalTreasury);
    expect(simnet.callPublicFn(
      COLLECTOR,
      'recover-excess-stx',
      [Cl.uint(directDeposit + 1n)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_EXCESS_RECOVERY_EXCEEDS_AVAILABLE)));
    expect(stxBalance(collectorPrincipal)).toBe(collectorBeforeRejectedRecovery);
    expect(stxBalance(operationalTreasury)).toBe(treasuryBeforeRejectedRecovery);
    expect(readUint('get-excess-recovered-stx')).toBe(recoveredBefore);

    expect(simnet.callPublicFn(
      COLLECTOR,
      'recover-excess-stx',
      [Cl.uint(directDeposit)],
      wallet1,
    ).result.type).toBe('err');
    expect(stxBalance(collectorPrincipal)).toBe(collectorBeforeRejectedRecovery);
    expect(stxBalance(operationalTreasury)).toBe(treasuryBeforeRejectedRecovery);

    const collectorBeforeRecovery = stxBalance(collectorPrincipal);
    const treasuryBeforeRecovery = stxBalance(operationalTreasury);
    const recoveryReceipt: any = simnet.callPublicFn(
      'test-c4-helper',
      'collector-recover-excess-stx',
      [Cl.uint(directDeposit)],
      deployer,
    );
    expect(recoveryReceipt.result).toEqual(Cl.ok(Cl.uint(directDeposit)));
    expect(stxBalance(collectorPrincipal)).toBe(collectorBeforeRecovery - directDeposit);
    expect(stxBalance(operationalTreasury)).toBe(treasuryBeforeRecovery + directDeposit);
    expect(readUint('get-total-routed-stx')).toBe(routedBefore);
    expect(readUint('get-total-routes')).toBe(routesBefore);
    expect(readUint('get-excess-recovered-stx')).toBe(recoveredBefore + directDeposit);
    expect(readUint('get-total-recovered-excess-stx')).toBe(recoveredBefore + directDeposit);

    const recoveryEvent: any = printEvent(recoveryReceipt);
    expect(recoveryEvent.value.event).toEqual(Cl.stringAscii('protocol-fee-excess-recovered'));
    expect(recoveryEvent.value['asset-kind']).toEqual(Cl.uint(ASSET_KIND_STX));
    expect(recoveryEvent.value.asset).toEqual(Cl.none());
    expect(recoveryEvent.value.amount).toEqual(Cl.uint(directDeposit));
    expect(recoveryEvent.value.collector).toEqual(Cl.principal(collectorPrincipal));
    expect(recoveryEvent.value.destination).toEqual(Cl.principal(operationalTreasury));
    expect(recoveryEvent.value['tracked-outstanding-custody']).toEqual(Cl.uint(
      BigInt(recoveryEvent.value['tracked-outstanding-custody'].value),
    ));
    expect(recoveryEvent.value['excess-before-recovery']).toEqual(Cl.uint(directDeposit));
    expect(recoveryEvent.value['recovered-total']).toEqual(Cl.uint(recoveredBefore + directDeposit));

    // The remaining collector balance is accounted fee custody, not recoverable
    // excess. A direct recovery attempt cannot consume it.
    expect(simnet.callPublicFn(
      COLLECTOR,
      'recover-excess-stx',
      [Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_EXCESS_RECOVERY_EXCEEDS_AVAILABLE)));
  });

  it('recovers only excess direct FT deposits and rolls back failed token transfers', () => {
    const streamId = 1011;
    registerFtStream(wallet1, streamId);
    const directDeposit = 75n;
    expect(simnet.callPublicFn(
      'mock-token',
      'mint',
      [Cl.uint(10_000), Cl.principal(wallet1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const fee = readUint('calculate-current-fee', [Cl.uint(10_000)]);
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-ft',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(streamId), Cl.uint(10_000), settlementId(51)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(fee)));
    expect(simnet.callPublicFn(
      'mock-token',
      'transfer',
      [Cl.uint(directDeposit), Cl.principal(wallet1), Cl.principal(collectorPrincipal), Cl.none()],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const routedBefore = readUint('get-routed-ft', [Cl.principal(mockToken)]);
    const routesBefore = readUint('get-total-routes');
    const recoveredBefore = readUint('get-excess-recovered-ft', [Cl.principal(mockToken)]);
    const collectorBeforeFailure = mockTokenBalance(collectorPrincipal);
    const treasuryBeforeFailure = mockTokenBalance(operationalTreasury);

    expect(simnet.callPublicFn(
      COLLECTOR,
      'recover-excess-ft',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(directDeposit)],
      wallet1,
    ).result.type).toBe('err');
    expect(mockTokenBalance(collectorPrincipal)).toBe(collectorBeforeFailure);
    expect(mockTokenBalance(operationalTreasury)).toBe(treasuryBeforeFailure);

    expect(simnet.callPublicFn(
      'mock-token',
      'set-transfer-failure',
      [Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const failedRecovery: any = simnet.callPublicFn(
      COLLECTOR,
      'recover-excess-ft',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(directDeposit)],
      deployer,
    );
    expect(failedRecovery.result).toEqual(Cl.error(Cl.uint(2)));
    expect(mockTokenBalance(collectorPrincipal)).toBe(collectorBeforeFailure);
    expect(mockTokenBalance(operationalTreasury)).toBe(treasuryBeforeFailure);
    expect(readUint('get-excess-recovered-ft', [Cl.principal(mockToken)])).toBe(recoveredBefore);
    expect(readUint('get-routed-ft', [Cl.principal(mockToken)])).toBe(routedBefore);
    expect(readUint('get-total-routes')).toBe(routesBefore);
    expect(simnet.callPublicFn(
      'mock-token',
      'set-transfer-failure',
      [Cl.bool(false)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));

    const collectorBeforeRecovery = mockTokenBalance(collectorPrincipal);
    const treasuryBeforeRecovery = mockTokenBalance(operationalTreasury);
    const recoveryReceipt: any = simnet.callPublicFn(
      COLLECTOR,
      'recover-excess-ft',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(directDeposit)],
      deployer,
    );
    expect(recoveryReceipt.result).toEqual(Cl.ok(Cl.uint(directDeposit)));
    expect(mockTokenBalance(collectorPrincipal)).toBe(collectorBeforeRecovery - directDeposit);
    expect(mockTokenBalance(operationalTreasury)).toBe(treasuryBeforeRecovery + directDeposit);
    expect(readUint('get-routed-ft', [Cl.principal(mockToken)])).toBe(routedBefore);
    expect(readUint('get-total-routes')).toBe(routesBefore);
    expect(readUint('get-excess-recovered-ft', [Cl.principal(mockToken)])).toBe(recoveredBefore + directDeposit);

    const recoveryEvent: any = printEvent(recoveryReceipt);
    expect(recoveryEvent.value.event).toEqual(Cl.stringAscii('protocol-fee-excess-recovered'));
    expect(recoveryEvent.value['asset-kind']).toEqual(Cl.uint(ASSET_KIND_FT));
    expect(recoveryEvent.value.asset).toEqual(Cl.some(Cl.principal(mockToken)));
    expect(recoveryEvent.value.amount).toEqual(Cl.uint(directDeposit));
    expect(recoveryEvent.value.collector).toEqual(Cl.principal(collectorPrincipal));
    expect(recoveryEvent.value.destination).toEqual(Cl.principal(operationalTreasury));
    expect(recoveryEvent.value['excess-before-recovery']).toEqual(Cl.uint(directDeposit));
    expect(recoveryEvent.value['recovered-total']).toEqual(Cl.uint(recoveredBefore + directDeposit));

    expect(simnet.callPublicFn(
      COLLECTOR,
      'recover-excess-ft',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_EXCESS_RECOVERY_EXCEEDS_AVAILABLE)));
  });

  it('supports immediate-caller admin handoff to an approved governance contract', () => {
    expect(simnet.callReadOnlyFn(COLLECTOR, 'get-admin', [], deployer).result)
      .toEqual(Cl.ok(Cl.principal(deployer)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-admin',
      [Cl.principal(governanceProxy)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(COLLECTOR, 'get-admin', [], deployer).result)
      .toEqual(Cl.ok(Cl.principal(governanceProxy)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-authorized-source',
      [Cl.principal(wallet2), Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(ERR_UNAUTHORIZED)));
    expect(simnet.callPublicFn(
      'test-c4-helper',
      'collector-set-authorized-source',
      [Cl.principal(wallet2), Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'is-authorized-source',
      [Cl.principal(wallet2)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'test-c4-helper',
      'collector-set-admin',
      [Cl.principal(deployer)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(COLLECTOR, 'get-admin', [], deployer).result)
      .toEqual(Cl.ok(Cl.principal(deployer)));
    expect(simnet.callPublicFn(
      COLLECTOR,
      'set-authorized-source',
      [Cl.principal(wallet2), Cl.bool(false)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));
  });

  it('settles source-custody STX and FT with exact deltas, excess preservation, and residual accounting', () => {
    const sourceTrait = Cl.contractPrincipal(deployer, 'mock-fee-source');
    const tokenTrait = Cl.contractPrincipal(deployer, 'mock-token');

    const stxStream = 1100;
    const stxBase = 10_000n;
    registerSourceStxStream(stxStream);
    const stxPreview: any = simnet.callReadOnlyFn(
      COLLECTOR,
      'preview-source-stx',
      [Cl.principal(mockFeeSource), Cl.uint(stxStream), Cl.uint(stxBase)],
      deployer,
    ).result;
    expect(stxPreview.type).toBe('ok');
    const stxFee = BigInt(stxPreview.value.value['assessed-amount'].value);
    const stxSourceBefore = stxBalance(mockFeeSource);
    const stxCollectorBefore = stxBalance(collectorPrincipal);
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'settle-stx',
      [sourceTrait, Cl.uint(stxStream), Cl.uint(stxBase), settlementId(60), Cl.uint(MODE_EXACT)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(stxFee)));
    expect(stxBalance(mockFeeSource)).toBe(stxSourceBefore - stxFee);
    expect(stxBalance(collectorPrincipal)).toBe(stxCollectorBefore + stxFee);
    const stxAccounting = readOptionalTuple('get-accounting', [
      Cl.principal(mockFeeSource),
      Cl.uint(stxStream),
      Cl.uint(ASSET_KIND_STX),
      Cl.none(),
    ]);
    expect(stxAccounting?.['eligible-base']).toEqual(Cl.uint(stxBase));
    expect(stxAccounting?.['settled-fees']).toEqual(Cl.uint(stxFee));

    expect(simnet.callPublicFn(
      'mock-token',
      'mint',
      [Cl.uint(1_000_000), Cl.principal(mockFeeSource)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const ftStream = 1101;
    const ftBase = 10_000n;
    registerSourceFtStream(ftStream, mockToken);
    const ftPreview: any = simnet.callReadOnlyFn(
      COLLECTOR,
      'preview-source-ft',
      [Cl.principal(mockFeeSource), Cl.uint(ftStream), Cl.principal(mockToken), Cl.uint(ftBase)],
      deployer,
    ).result;
    expect(ftPreview.type).toBe('ok');
    const ftFee = BigInt(ftPreview.value.value['assessed-amount'].value);
    expect(ftFee).toBeGreaterThan(0n);

    const ftSourceBefore = mockTokenBalance(mockFeeSource);
    const ftCollectorBefore = mockTokenBalance(collectorPrincipal);
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'settle-ft',
      [sourceTrait, tokenTrait, Cl.uint(ftStream), Cl.uint(ftBase), settlementId(61), Cl.uint(MODE_EXACT)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(ftFee)));
    expect(mockTokenBalance(mockFeeSource)).toBe(ftSourceBefore - ftFee);
    expect(mockTokenBalance(collectorPrincipal)).toBe(ftCollectorBefore + ftFee);

    // A direct collector deposit is intentionally untracked. The source
    // settlement delta must add only the assessed debit and leave that excess
    // in collector custody.
    const untrackedExcess = 123n;
    expect(simnet.callPublicFn(
      'mock-token',
      'mint',
      [Cl.uint(untrackedExcess), Cl.principal(collectorPrincipal)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const excessCollectorBefore = mockTokenBalance(collectorPrincipal);
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'settle-ft',
      [sourceTrait, tokenTrait, Cl.uint(ftStream), Cl.uint(ftBase), settlementId(62), Cl.uint(MODE_EXACT)],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.uint(ftFee)));
    expect(mockTokenBalance(collectorPrincipal)).toBe(excessCollectorBefore + ftFee);

    // A positive base may assess to zero. The callback consumes the pending
    // record without attempting a zero transfer, and the residual is retained
    // for the next settlement on the same source/stream/asset key.
    const residualStream = 1102;
    registerSourceFtStream(residualStream, mockToken);
    const zeroBase = 1n;
    const zeroPreview: any = simnet.callReadOnlyFn(
      COLLECTOR,
      'preview-source-ft',
      [Cl.principal(mockFeeSource), Cl.uint(residualStream), Cl.principal(mockToken), Cl.uint(zeroBase)],
      deployer,
    ).result;
    expect(zeroPreview.type).toBe('ok');
    const rate = BigInt(zeroPreview.value.value['rate-bps'].value);
    expect(zeroPreview.value.value['assessed-amount']).toEqual(Cl.uint(0));
    const zeroCollectorBefore = mockTokenBalance(collectorPrincipal);
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'settle-ft',
      [sourceTrait, tokenTrait, Cl.uint(residualStream), Cl.uint(zeroBase), settlementId(63), Cl.uint(MODE_EXACT)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(0)));
    expect(mockTokenBalance(collectorPrincipal)).toBe(zeroCollectorBefore);
    const afterZero = readOptionalTuple('get-accounting', [
      Cl.principal(mockFeeSource),
      Cl.uint(residualStream),
      Cl.uint(ASSET_KIND_FT),
      Cl.some(Cl.principal(mockToken)),
    ]);
    expect(afterZero?.['fee-remainder']).toEqual(Cl.uint(rate));

    const secondBase = ((10_000n - rate) + rate - 1n) / rate;
    const secondPreview: any = simnet.callReadOnlyFn(
      COLLECTOR,
      'preview-source-ft',
      [Cl.principal(mockFeeSource), Cl.uint(residualStream), Cl.principal(mockToken), Cl.uint(secondBase)],
      deployer,
    ).result;
    expect(secondPreview.type).toBe('ok');
    const secondFee = BigInt(secondPreview.value.value['assessed-amount'].value);
    expect(secondFee).toBe(1n);
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'settle-ft',
      [sourceTrait, tokenTrait, Cl.uint(residualStream), Cl.uint(secondBase), settlementId(64), Cl.uint(MODE_EXACT)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(secondFee)));
    const afterResidual = readOptionalTuple('get-accounting', [
      Cl.principal(mockFeeSource),
      Cl.uint(residualStream),
      Cl.uint(ASSET_KIND_FT),
      Cl.some(Cl.principal(mockToken)),
    ]);
    expect(afterResidual?.['eligible-base']).toEqual(Cl.uint(zeroBase + secondBase));
    expect(afterResidual?.['assessed-fees']).toEqual(Cl.uint(secondFee));
  });

  it('rejects unauthorized, underpaid, overpaid, misrouted, wrong-token, paused, replayed, and failed source callbacks atomically', () => {
    const sourceTrait = Cl.contractPrincipal(deployer, 'mock-fee-source');
    const tokenTrait = Cl.contractPrincipal(deployer, 'mock-token');
    const base = 10_000n;
    const streamId = 1103;
    registerSourceFtStream(streamId, mockToken);
    const preview: any = simnet.callReadOnlyFn(
      COLLECTOR,
      'preview-source-ft',
      [Cl.principal(mockFeeSource), Cl.uint(streamId), Cl.principal(mockToken), Cl.uint(base)],
      deployer,
    ).result;
    expect(preview.type).toBe('ok');
    const fee = BigInt(preview.value.value['assessed-amount'].value);
    expect(fee).toBeGreaterThan(0n);

    const expectModeRollback = (payer: string, mode: number, id: number) => {
      const sourceBefore = mockTokenBalance(mockFeeSource);
      const collectorBefore = mockTokenBalance(collectorPrincipal);
      const callbacksBefore = readMockUint('get-ft-callback-invocations');
      const receipt: any = simnet.callPublicFn(
        'mock-fee-source',
        'settle-ft',
        [sourceTrait, tokenTrait, Cl.uint(streamId), Cl.uint(base), settlementId(id), Cl.uint(mode)],
        payer,
      );
      expect(receipt.result).toEqual(Cl.error(Cl.uint(4125)));
      expect(mockTokenBalance(mockFeeSource)).toBe(sourceBefore);
      expect(mockTokenBalance(collectorPrincipal)).toBe(collectorBefore);
      expect(readMockUint('get-ft-callback-invocations')).toBe(callbacksBefore);
      const pending: any = simnet.callReadOnlyFn(
        'mock-fee-source',
        'get-pending-ft',
        [Cl.principal(payer)],
        deployer,
      ).result;
      expect(pending.type).toBe('ok');
      expect(pending.value.type).toBe('none');
      expect(simnet.callReadOnlyFn(
        COLLECTOR,
        'is-settlement-in-progress',
        [Cl.principal(mockFeeSource), settlementId(id)],
        deployer,
      ).result).toEqual(Cl.ok(Cl.bool(false)));
    };

    expectModeRollback(wallet1, 1, 65);
    expectModeRollback(wallet1, 2, 66);
    expectModeRollback(wallet1, 3, 67);
    expectModeRollback(wallet1, 4, 68);

    // The collector source API itself rejects a direct wallet caller before it
    // can invoke the source callback.
    expect(simnet.callPublicFn(
      COLLECTOR,
      'settle-source-ft',
      [sourceTrait, tokenTrait, Cl.uint(streamId), Cl.uint(base), settlementId(69)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(4124)));

    // Pending source state is not externally preparable; direct callback calls
    // fail closed without a private record.
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'prepay-ft-fee',
      [tokenTrait, Cl.uint(fee), Cl.principal(collectorPrincipal)],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(6001)));

    const wrongTokenStream = 1104;
    registerSourceFtStream(wrongTokenStream, cxvgToken);
    const wrongTokenPreview: any = simnet.callReadOnlyFn(
      COLLECTOR,
      'preview-source-ft',
      [Cl.principal(mockFeeSource), Cl.uint(wrongTokenStream), Cl.principal(cxvgToken), Cl.uint(base)],
      deployer,
    ).result;
    expect(wrongTokenPreview.type).toBe('ok');
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'settle-ft',
      [sourceTrait, Cl.contractPrincipal(deployer, 'cxvg-token'), Cl.uint(wrongTokenStream), Cl.uint(base), settlementId(70), Cl.uint(MODE_WRONG_ASSET)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(6004)));

    const pausedStream = 1105;
    registerSourceFtStream(pausedStream, mockToken);
    expect(simnet.callPublicFn(COLLECTOR, 'pause', [], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'settle-ft',
      [sourceTrait, tokenTrait, Cl.uint(pausedStream), Cl.uint(base), settlementId(71), Cl.uint(MODE_EXACT)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_PAUSED)));
    expect(simnet.callPublicFn(COLLECTOR, 'unpause', [], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    const replayStream = 1106;
    registerSourceFtStream(replayStream, mockToken);
    const replayId = settlementId(72);
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'settle-ft',
      [sourceTrait, tokenTrait, Cl.uint(replayStream), Cl.uint(base), replayId, Cl.uint(MODE_EXACT)],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.uint(fee)));
    const replaySourceBefore = mockTokenBalance(mockFeeSource);
    const replayCollectorBefore = mockTokenBalance(collectorPrincipal);
    const replayCallbacksBefore = readMockUint('get-ft-callback-invocations');
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'settle-ft',
      [sourceTrait, tokenTrait, Cl.uint(replayStream), Cl.uint(base), replayId, Cl.uint(MODE_EXACT)],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(ERR_SETTLEMENT_REPLAYED)));
    expect(mockTokenBalance(mockFeeSource)).toBe(replaySourceBefore);
    expect(mockTokenBalance(collectorPrincipal)).toBe(replayCollectorBefore);
    expect(readMockUint('get-ft-callback-invocations')).toBe(replayCallbacksBefore);
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'is-settlement-in-progress',
      [Cl.principal(mockFeeSource), replayId],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));

    const failedStream = 1107;
    registerSourceFtStream(failedStream, mockToken);
    expect(simnet.callPublicFn(
      'mock-token',
      'set-transfer-failure',
      [Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const failedSourceBefore = mockTokenBalance(mockFeeSource);
    const failedCollectorBefore = mockTokenBalance(collectorPrincipal);
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'settle-ft',
      [sourceTrait, tokenTrait, Cl.uint(failedStream), Cl.uint(base), settlementId(73), Cl.uint(MODE_EXACT)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(2)));
    expect(mockTokenBalance(mockFeeSource)).toBe(failedSourceBefore);
    expect(mockTokenBalance(collectorPrincipal)).toBe(failedCollectorBefore);
    expect(simnet.callPublicFn(
      'mock-token',
      'set-transfer-failure',
      [Cl.bool(false)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));
  });

  it('keeps STX source custody atomic across underpay, overpay, no-transfer, wrong-destination, callback failure, and replay', () => {
    const sourceTrait = Cl.contractPrincipal(deployer, 'mock-fee-source');
    const streamId = 1110;
    const base = 10_000n;
    registerSourceStxStream(streamId);

    const preview: any = simnet.callReadOnlyFn(
      COLLECTOR,
      'preview-source-stx',
      [Cl.principal(mockFeeSource), Cl.uint(streamId), Cl.uint(base)],
      deployer,
    ).result;
    expect(preview.type).toBe('ok');
    const fee = BigInt(preview.value.value['assessed-amount'].value);
    expect(fee).toBeGreaterThan(0n);

    const expectModeRollback = (mode: number, id: number) => {
      const sourceBefore = stxBalance(mockFeeSource);
      const collectorBefore = stxBalance(collectorPrincipal);
      const callbacksBefore = readMockUint('get-stx-callback-invocations');
      const receipt: any = simnet.callPublicFn(
        'mock-fee-source',
        'settle-stx',
        [sourceTrait, Cl.uint(streamId), Cl.uint(base), settlementId(id), Cl.uint(mode)],
        wallet1,
      );
      expect(receipt.result).toEqual(Cl.error(Cl.uint(4125)));
      expect(stxBalance(mockFeeSource)).toBe(sourceBefore);
      expect(stxBalance(collectorPrincipal)).toBe(collectorBefore);
      expect(readMockUint('get-stx-callback-invocations')).toBe(callbacksBefore);
      expect(simnet.callReadOnlyFn(
        'mock-fee-source',
        'get-pending-stx',
        [Cl.principal(wallet1)],
        deployer,
      ).result).toEqual(Cl.ok(Cl.none()));
      expect(readOptionalTuple('get-accounting', [
        Cl.principal(mockFeeSource),
        Cl.uint(streamId),
        Cl.uint(ASSET_KIND_STX),
        Cl.none(),
      ])).toBeNull();
      expect(simnet.callReadOnlyFn(
        COLLECTOR,
        'is-settlement-in-progress',
        [Cl.principal(mockFeeSource), settlementId(id)],
        deployer,
      ).result).toEqual(Cl.ok(Cl.bool(false)));
    };

    expectModeRollback(MODE_UNDERPAY, 80);
    expectModeRollback(MODE_OVERPAY, 81);
    expectModeRollback(MODE_NO_TRANSFER, 82);
    expectModeRollback(MODE_WRONG_DESTINATION, 83);

    expect(simnet.callPublicFn(
      'mock-fee-source',
      'set-stx-transfer-failure',
      [Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const failedSourceBefore = stxBalance(mockFeeSource);
    const failedCollectorBefore = stxBalance(collectorPrincipal);
    const failedCallbacksBefore = readMockUint('get-stx-callback-invocations');
    const failedReceipt: any = simnet.callPublicFn(
      'mock-fee-source',
      'settle-stx',
      [sourceTrait, Cl.uint(streamId), Cl.uint(base), settlementId(84), Cl.uint(MODE_EXACT)],
      wallet1,
    );
    expect(failedReceipt.result.type).toBe('err');
    expect(stxBalance(mockFeeSource)).toBe(failedSourceBefore);
    expect(stxBalance(collectorPrincipal)).toBe(failedCollectorBefore);
    expect(readMockUint('get-stx-callback-invocations')).toBe(failedCallbacksBefore);
    expect(simnet.callReadOnlyFn(
      'mock-fee-source',
      'get-pending-stx',
      [Cl.principal(wallet1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.none()));
    expect(readOptionalTuple('get-accounting', [
      Cl.principal(mockFeeSource),
      Cl.uint(streamId),
      Cl.uint(ASSET_KIND_STX),
      Cl.none(),
    ])).toBeNull();
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'is-settlement-in-progress',
      [Cl.principal(mockFeeSource), settlementId(84)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'set-stx-transfer-failure',
      [Cl.bool(false)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));

    const replayId = settlementId(85);
    const firstSourceBefore = stxBalance(mockFeeSource);
    const firstCollectorBefore = stxBalance(collectorPrincipal);
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'settle-stx',
      [sourceTrait, Cl.uint(streamId), Cl.uint(base), replayId, Cl.uint(MODE_EXACT)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(fee)));
    expect(stxBalance(mockFeeSource)).toBe(firstSourceBefore - fee);
    expect(stxBalance(collectorPrincipal)).toBe(firstCollectorBefore + fee);
    const replayCallbacksBefore = readMockUint('get-stx-callback-invocations');
    const replaySourceBefore = stxBalance(mockFeeSource);
    const replayCollectorBefore = stxBalance(collectorPrincipal);
    expect(simnet.callPublicFn(
      'mock-fee-source',
      'settle-stx',
      [sourceTrait, Cl.uint(streamId), Cl.uint(base), replayId, Cl.uint(MODE_EXACT)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(ERR_SETTLEMENT_REPLAYED)));
    expect(stxBalance(mockFeeSource)).toBe(replaySourceBefore);
    expect(stxBalance(collectorPrincipal)).toBe(replayCollectorBefore);
    expect(readMockUint('get-stx-callback-invocations')).toBe(replayCallbacksBefore);
    expect(simnet.callReadOnlyFn(
      COLLECTOR,
      'is-settlement-in-progress',
      [Cl.principal(mockFeeSource), replayId],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));
    const settlement = readOptionalTuple('get-settlement', [Cl.principal(mockFeeSource), replayId]);
    expect(settlement?.['asset-kind']).toEqual(Cl.uint(ASSET_KIND_STX));
    expect(settlement?.asset).toEqual(Cl.none());
    expect(settlement?.['settled-amount']).toEqual(Cl.uint(fee));
  });
});
