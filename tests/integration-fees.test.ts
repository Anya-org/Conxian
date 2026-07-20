import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

const MAX_UINT = 340282366920938463463374607431768211455n;

type Fixture = {
  integration: string;
  owner: string;
  payer: string;
  reporter: string;
  billingMode: number;
  feeAmount: bigint;
  keyFill: number;
};

describe('Integration fee registry and STX settlement', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;
  let fillCounter = 10;

  const keyHash = (fill: number) => Cl.buffer(Buffer.alloc(32, fill));
  const usageId = (fill: number) => Cl.buffer(Buffer.alloc(32, fill));
  const principal = (address: string) => Cl.principal(address);
  const contractPrincipal = (name: string) => `${deployer}.${name}`;

  const nextFill = () => {
    const fill = fillCounter;
    fillCounter += 1;
    return fill;
  };

  const createFixture = (
    billingMode: number,
    feeAmount: bigint | number,
    overrides: Partial<Pick<Fixture, 'owner' | 'payer' | 'reporter'>> = {},
  ): Fixture => ({
    integration: `${deployer}.integration-fee-${nextFill()}`,
    owner: overrides.owner ?? wallet1,
    payer: overrides.payer ?? wallet2,
    reporter: overrides.reporter ?? wallet3,
    billingMode,
    feeAmount: BigInt(feeAmount),
    keyFill: nextFill(),
  });

  const registerIntegration = (fixture: Fixture, sender = deployer) => simnet.callPublicFn(
    'integration-registry',
    'register-integration',
    [
      principal(fixture.integration),
      principal(fixture.owner),
      principal(fixture.payer),
      principal(fixture.reporter),
      Cl.stringAscii('Conxian integration'),
      Cl.stringAscii('https://example.invalid/integration'),
      Cl.uint(fixture.billingMode),
      Cl.uint(fixture.feeAmount),
      keyHash(fixture.keyFill),
    ],
    sender,
  );

  const registerFixture = (fixture: Fixture) => {
    expect(registerIntegration(fixture).result).toEqual(Cl.ok(Cl.bool(true)));
    simnet.mintSTX(fixture.payer, 1_000_000n);
  };

  const setConfig = (fixture: Fixture, billingMode: number, feeAmount: bigint | number) =>
    simnet.callPublicFn(
      'integration-registry',
      'set-integration-config',
      [
        principal(fixture.integration),
        Cl.stringAscii('Updated integration'),
        Cl.stringAscii('https://example.invalid/updated'),
        Cl.uint(billingMode),
        Cl.uint(feeAmount),
      ],
      deployer,
    );

  const setStatus = (fixture: Fixture, active: boolean) => simnet.callPublicFn(
    'integration-registry',
    'set-integration-status',
    [principal(fixture.integration), Cl.bool(active)],
    deployer,
  );

  const recordUsage = (fixture: Fixture, fill: number, units: bigint | number, sender = wallet3) =>
    simnet.callPublicFn(
      'integration-fee-collector',
      'record-usage',
      [principal(fixture.integration), usageId(fill), Cl.uint(units)],
      sender,
    );

  const readUint = (contractName: string, functionName: string, args: any[], sender = deployer): bigint => {
    const response: any = simnet.callReadOnlyFn(contractName, functionName, args, sender).result;
    expect(response.type).toBe('ok');
    return BigInt(response.value.value);
  };

  const readLedger = (fixture: Fixture, period: bigint) => simnet.callReadOnlyFn(
    'integration-fee-collector',
    'get-period-ledger',
    [principal(fixture.integration), Cl.uint(period)],
    deployer,
  ).result as any;

  const readTuple = (result: any): Record<string, any> => {
    expect(result.type).toBe('ok');
    expect(result.value.type).toBe('some');
    expect(result.value.value.type).toBe('tuple');
    return result.value.value.value;
  };

  const expectLedgerSnapshot = (result: any, billingMode: number, feeAmount: bigint | number) => {
    const tuple = readTuple(result);
    const fee = Cl.uint(feeAmount);
    expect(tuple['billing-mode']).toEqual(Cl.uint(billingMode));
    expect(tuple['fee-per-unit']).toEqual(fee);
    expect(tuple['monthly-fee']).toEqual(fee);
    expect(tuple['last-updated'].type).toBe('uint');
    return tuple;
  };

  const stxBalance = (address: string): bigint =>
    simnet.getAssetsMap().get('STX')?.get(address) ?? 0n;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
    wallet3 = accounts.get('wallet_3')!;
  });

  it('enforces admin registration, billing validation, duplicate keys, and reporter authorization', () => {
    const fixture = createFixture(1, 50);
    registerFixture(fixture);

    const unauthorized = createFixture(1, 50);
    expect(registerIntegration(unauthorized, wallet1).result).toEqual(Cl.error(Cl.uint(1000)));

    expect(setConfig(fixture, 3, 50).result).toEqual(Cl.error(Cl.uint(1003)));
    expect(setConfig(fixture, 1, 0).result).toEqual(Cl.error(Cl.uint(1004)));

    const duplicateKey = createFixture(1, 10);
    duplicateKey.keyFill = fixture.keyFill;
    expect(registerIntegration(duplicateKey).result).toEqual(Cl.error(Cl.uint(1005)));

    expect(registerIntegration(fixture).result).toEqual(Cl.error(Cl.uint(1001)));
    expect(simnet.callPublicFn(
      'integration-registry',
      'set-integration-reporter',
      [principal(fixture.integration), principal(wallet1)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1000)));
  });

  it('allows owner-or-payer key rotation and permanently deactivates old hashes', () => {
    const fixture = createFixture(1, 50);
    registerFixture(fixture);
    const firstRotation = nextFill();
    const secondRotation = nextFill();

    expect(simnet.callPublicFn(
      'integration-registry',
      'rotate-api-key',
      [principal(fixture.integration), keyHash(firstRotation)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1008)));

    expect(simnet.callPublicFn(
      'integration-registry',
      'rotate-api-key',
      [principal(fixture.integration), keyHash(firstRotation)],
      fixture.owner,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(
      'integration-registry',
      'is-api-key-active',
      [keyHash(fixture.keyFill)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(simnet.callReadOnlyFn(
      'integration-registry',
      'is-api-key-active',
      [keyHash(firstRotation)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(
      'integration-registry',
      'rotate-api-key',
      [principal(fixture.integration), keyHash(secondRotation)],
      fixture.payer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(
      'integration-registry',
      'is-api-key-active',
      [keyHash(firstRotation)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(simnet.callReadOnlyFn(
      'integration-registry',
      'is-api-key-active',
      [keyHash(secondRotation)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const reusedHash = createFixture(1, 10);
    reusedHash.keyFill = firstRotation;
    expect(registerIntegration(reusedHash).result).toEqual(Cl.error(Cl.uint(1005)));
  });

  it('rejects inactive integrations and unauthorized or replayed usage with snapshotted ledger fields', () => {
    const inactive = createFixture(1, 25);
    registerFixture(inactive);
    expect(setStatus(inactive, false).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(recordUsage(inactive, nextFill(), 1).result).toEqual(Cl.error(Cl.uint(2003)));

    const fixture = createFixture(1, 100);
    registerFixture(fixture);
    const firstId = nextFill();
    expect(recordUsage(fixture, firstId, 2, wallet1).result).toEqual(Cl.error(Cl.uint(2000)));
    expect(recordUsage(fixture, firstId, 2).result).toEqual(Cl.ok(Cl.uint(200)));
    expect(recordUsage(fixture, firstId, 2).result).toEqual(Cl.error(Cl.uint(2006)));
    expect(recordUsage(fixture, nextFill(), 3).result).toEqual(Cl.ok(Cl.uint(300)));

    const period = readUint('integration-fee-collector', 'get-current-period', []);
    const tuple = expectLedgerSnapshot(readLedger(fixture, period), 1, 100);
    expect(tuple['usage-count']).toEqual(Cl.uint(2));
    expect(tuple['usage-units']).toEqual(Cl.uint(5));
    expect(tuple['accrued-fees']).toEqual(Cl.uint(500));
    expect(tuple['settled-fees']).toEqual(Cl.uint(0));
  });

  it('enforces exact payer settlement, rolls back insufficient routes, and supports the settle-fees alias', () => {
    const fixture = createFixture(1, 100);
    registerFixture(fixture);
    const period = readUint('integration-fee-collector', 'get-current-period', []);
    expect(recordUsage(fixture, nextFill(), 5).result).toEqual(Cl.ok(Cl.uint(500)));

    expect(simnet.callPublicFn(
      'integration-fee-collector',
      'settle-period',
      [principal(fixture.integration), Cl.uint(period), Cl.uint(500), usageId(nextFill())],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(2000)));
    expect(simnet.callPublicFn(
      'integration-fee-collector',
      'settle-period',
      [principal(fixture.integration), Cl.uint(period), Cl.uint(499), usageId(nextFill())],
      fixture.payer,
    ).result).toEqual(Cl.error(Cl.uint(2012)));

    const insufficient = createFixture(1, MAX_UINT, { payer: wallet1 });
    registerFixture(insufficient);
    const insufficientPeriod = readUint('integration-fee-collector', 'get-current-period', []);
    expect(recordUsage(insufficient, nextFill(), 1).result).toEqual(Cl.ok(Cl.uint(MAX_UINT)));
    const router = contractPrincipal('swap-router');
    const collector = contractPrincipal('integration-fee-collector');
    const payerBeforeFailure = stxBalance(insufficient.payer);
    const collectorBeforeFailure = stxBalance(collector);
    const routerBeforeFailure = stxBalance(router);

    // The existing distributor route has no injected collector setter. A
    // direct transfer with an unfunded sender is the route-failure case.
    const directRouteFailure = simnet.callPublicFn(
      'revenue-distributor',
      'distribute-stx',
      [Cl.uint(MAX_UINT)],
      wallet1,
    );
    expect(directRouteFailure.result.type).toBe('err');
    expect(stxBalance(wallet1)).toBe(payerBeforeFailure);
    expect(stxBalance(router)).toBe(routerBeforeFailure);

    const settlementFailure = simnet.callPublicFn(
      'integration-fee-collector',
      'settle-period',
      [principal(insufficient.integration), Cl.uint(insufficientPeriod), Cl.uint(MAX_UINT), usageId(nextFill())],
      insufficient.payer,
    );
    expect(settlementFailure.result.type).toBe('err');
    expect(stxBalance(insufficient.payer)).toBe(payerBeforeFailure);
    expect(stxBalance(collector)).toBe(collectorBeforeFailure);
    expect(stxBalance(router)).toBe(routerBeforeFailure);
    expect(readUint(
      'integration-fee-collector',
      'get-outstanding-fee',
      [principal(insufficient.integration), Cl.uint(insufficientPeriod)],
    )).toBe(MAX_UINT);
    expect(readLedger(insufficient, insufficientPeriod).value.value.value['settled-fees'])
      .toEqual(Cl.uint(0));

    const payerBeforeSettlement = stxBalance(fixture.payer);
    const collectorBeforeSettlement = stxBalance(collector);
    const routerBeforeSettlement = stxBalance(router);
    expect(simnet.callPublicFn(
      'integration-fee-collector',
      'settle-period',
      [principal(fixture.integration), Cl.uint(period), Cl.uint(500), usageId(nextFill())],
      fixture.payer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(stxBalance(fixture.payer)).toBe(payerBeforeSettlement - 500n);
    expect(stxBalance(collector)).toBe(collectorBeforeSettlement);
    expect(stxBalance(router)).toBe(routerBeforeSettlement + 500n);
    expect(readUint(
      'integration-fee-collector',
      'get-outstanding-fee',
      [principal(fixture.integration), Cl.uint(period)],
    )).toBe(0n);

    const aliasFixture = createFixture(1, 75);
    registerFixture(aliasFixture);
    const aliasPeriod = readUint('integration-fee-collector', 'get-current-period', []);
    expect(recordUsage(aliasFixture, nextFill(), 2).result).toEqual(Cl.ok(Cl.uint(150)));
    expect(simnet.callPublicFn(
      'integration-fee-collector',
      'settle-fees',
      [principal(aliasFixture.integration), Cl.uint(aliasPeriod), Cl.uint(150), usageId(nextFill())],
      aliasFixture.payer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(readUint(
      'integration-fee-collector',
      'get-outstanding-fee',
      [principal(aliasFixture.integration), Cl.uint(aliasPeriod)],
    )).toBe(0n);
  });

  it('uses the monthly ledger snapshot and only settles after the snapshotted period closes', () => {
    const fixture = createFixture(2, 1000);
    registerFixture(fixture);
    const period = readUint('integration-fee-collector', 'get-current-period', []);
    expect(readUint('integration-fee-collector', 'get-monthly-period-burn-blocks', [])).toBe(4320n);

    expect(recordUsage(fixture, nextFill(), 1).result).toEqual(Cl.ok(Cl.uint(1000)));
    expect(recordUsage(fixture, nextFill(), 2).result).toEqual(Cl.ok(Cl.uint(0)));
    const tuple = expectLedgerSnapshot(readLedger(fixture, period), 2, 1000);
    expect(tuple['usage-count']).toEqual(Cl.uint(2));
    expect(tuple['usage-units']).toEqual(Cl.uint(3));
    expect(tuple['accrued-fees']).toEqual(Cl.uint(1000));

    expect(simnet.callPublicFn(
      'integration-fee-collector',
      'settle-period',
      [principal(fixture.integration), Cl.uint(period), Cl.uint(1000), usageId(nextFill())],
      fixture.payer,
    ).result).toEqual(Cl.error(Cl.uint(2009)));

    simnet.mineEmptyBlocks(4320);
    expect(readUint('integration-fee-collector', 'get-current-period', [])).toBeGreaterThan(period);
    expect(simnet.callPublicFn(
      'integration-fee-collector',
      'settle-period',
      [principal(fixture.integration), Cl.uint(period), Cl.uint(1000), usageId(nextFill())],
      fixture.payer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('does not let a monthly-to-per-use change reinterpret an open monthly ledger', () => {
    const fixture = createFixture(2, 1000);
    registerFixture(fixture);
    const period = readUint('integration-fee-collector', 'get-current-period', []);
    expect(recordUsage(fixture, nextFill(), 1).result).toEqual(Cl.ok(Cl.uint(1000)));
    expect(setConfig(fixture, 1, 5).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(recordUsage(fixture, nextFill(), 7).result).toEqual(Cl.ok(Cl.uint(0)));

    const tuple = expectLedgerSnapshot(readLedger(fixture, period), 2, 1000);
    expect(tuple['usage-count']).toEqual(Cl.uint(2));
    expect(tuple['usage-units']).toEqual(Cl.uint(8));
    expect(tuple['accrued-fees']).toEqual(Cl.uint(1000));
    expect(simnet.callPublicFn(
      'integration-fee-collector',
      'settle-period',
      [principal(fixture.integration), Cl.uint(period), Cl.uint(1000), usageId(nextFill())],
      fixture.payer,
    ).result).toEqual(Cl.error(Cl.uint(2009)));
  });

  it('does not let per-use mode or fee changes reinterpret an old ledger, while a future period uses new config', () => {
    const fixture = createFixture(1, 100);
    registerFixture(fixture);
    const period = readUint('integration-fee-collector', 'get-current-period', []);
    expect(recordUsage(fixture, nextFill(), 2).result).toEqual(Cl.ok(Cl.uint(200)));
    expect(setConfig(fixture, 2, 1000).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(recordUsage(fixture, nextFill(), 3).result).toEqual(Cl.ok(Cl.uint(300)));
    expect(setConfig(fixture, 2, 2000).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(recordUsage(fixture, nextFill(), 1).result).toEqual(Cl.ok(Cl.uint(100)));

    const oldTuple = expectLedgerSnapshot(readLedger(fixture, period), 1, 100);
    expect(oldTuple['usage-count']).toEqual(Cl.uint(3));
    expect(oldTuple['usage-units']).toEqual(Cl.uint(6));
    expect(oldTuple['accrued-fees']).toEqual(Cl.uint(600));

    simnet.mineEmptyBlocks(4320);
    const futurePeriod = readUint('integration-fee-collector', 'get-current-period', []);
    expect(futurePeriod).toBeGreaterThan(period);
    expect(recordUsage(fixture, nextFill(), 1).result).toEqual(Cl.ok(Cl.uint(2000)));
    expect(recordUsage(fixture, nextFill(), 4).result).toEqual(Cl.ok(Cl.uint(0)));
    const futureTuple = expectLedgerSnapshot(readLedger(fixture, futurePeriod), 2, 2000);
    expect(futureTuple['usage-count']).toEqual(Cl.uint(2));
    expect(futureTuple['usage-units']).toEqual(Cl.uint(5));
    expect(futureTuple['accrued-fees']).toEqual(Cl.uint(2000));
  });

  it('allows deactivated integrations to settle existing per-use debt but rejects new usage', () => {
    const fixture = createFixture(1, 100);
    registerFixture(fixture);
    const period = readUint('integration-fee-collector', 'get-current-period', []);
    expect(recordUsage(fixture, nextFill(), 3).result).toEqual(Cl.ok(Cl.uint(300)));
    expect(setStatus(fixture, false).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(recordUsage(fixture, nextFill(), 1).result).toEqual(Cl.error(Cl.uint(2003)));
    expect(simnet.callPublicFn(
      'integration-fee-collector',
      'settle-period',
      [principal(fixture.integration), Cl.uint(period), Cl.uint(300), usageId(nextFill())],
      fixture.payer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(readUint(
      'integration-fee-collector',
      'get-outstanding-fee',
      [principal(fixture.integration), Cl.uint(period)],
    )).toBe(0n);
  });

  it('allows a deactivated monthly integration to settle after close but not record new usage', () => {
    const fixture = createFixture(2, 500);
    registerFixture(fixture);
    const period = readUint('integration-fee-collector', 'get-current-period', []);
    expect(recordUsage(fixture, nextFill(), 1).result).toEqual(Cl.ok(Cl.uint(500)));
    expect(setStatus(fixture, false).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(recordUsage(fixture, nextFill(), 1).result).toEqual(Cl.error(Cl.uint(2003)));
    expect(simnet.callPublicFn(
      'integration-fee-collector',
      'settle-period',
      [principal(fixture.integration), Cl.uint(period), Cl.uint(500), usageId(nextFill())],
      fixture.payer,
    ).result).toEqual(Cl.error(Cl.uint(2009)));

    simnet.mineEmptyBlocks(4320);
    expect(simnet.callPublicFn(
      'integration-fee-collector',
      'settle-period',
      [principal(fixture.integration), Cl.uint(period), Cl.uint(500), usageId(nextFill())],
      fixture.payer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('rejects zero units and guards multiplication and accumulation overflow without partial ledgers', () => {
    const zeroUnits = createFixture(1, 1);
    registerFixture(zeroUnits);
    expect(recordUsage(zeroUnits, nextFill(), 0).result).toEqual(Cl.error(Cl.uint(2005)));
    const zeroPeriod = readUint('integration-fee-collector', 'get-current-period', []);
    expect(readLedger(zeroUnits, zeroPeriod)).toEqual(Cl.ok(Cl.none()));

    const multiplicationOverflow = createFixture(1, MAX_UINT);
    registerFixture(multiplicationOverflow);
    expect(recordUsage(multiplicationOverflow, nextFill(), 2).result)
      .toEqual(Cl.error(Cl.uint(2007)));
    expect(readLedger(multiplicationOverflow, zeroPeriod)).toEqual(Cl.ok(Cl.none()));

    const accumulationOverflow = createFixture(1, 1);
    registerFixture(accumulationOverflow);
    expect(recordUsage(accumulationOverflow, nextFill(), MAX_UINT).result)
      .toEqual(Cl.ok(Cl.uint(MAX_UINT)));
    expect(recordUsage(accumulationOverflow, nextFill(), 1).result)
      .toEqual(Cl.error(Cl.uint(2007)));
    const tuple = expectLedgerSnapshot(readLedger(accumulationOverflow, zeroPeriod), 1, 1);
    expect(tuple['usage-units']).toEqual(Cl.uint(MAX_UINT));
    expect(tuple['accrued-fees']).toEqual(Cl.uint(MAX_UINT));
  });

  it('returns structured registry, usage, ledger, and settlement values including billing snapshots', () => {
    const fixture = createFixture(1, 123);
    registerFixture(fixture);
    const period = readUint('integration-fee-collector', 'get-current-period', []);
    const eventFill = nextFill();
    expect(recordUsage(fixture, eventFill, 4).result).toEqual(Cl.ok(Cl.uint(492)));

    const registryTuple = readTuple(simnet.callReadOnlyFn(
      'integration-registry',
      'get-integration',
      [principal(fixture.integration)],
      deployer,
    ).result);
    expect(registryTuple['billing-mode']).toEqual(Cl.uint(1));
    expect(registryTuple['fee-amount']).toEqual(Cl.uint(123));
    expect(registryTuple.active).toEqual(Cl.bool(true));
    expect(registryTuple['key-hash']).toEqual(keyHash(fixture.keyFill));

    const usageTuple = readTuple(simnet.callReadOnlyFn(
      'integration-fee-collector',
      'get-usage-record',
      [usageId(eventFill)],
      deployer,
    ).result);
    expect(usageTuple.integration).toEqual(Cl.principal(fixture.integration));
    expect(usageTuple.reporter).toEqual(Cl.principal(fixture.reporter));
    expect(usageTuple['usage-units']).toEqual(Cl.uint(4));
    expect(usageTuple['fee-amount']).toEqual(Cl.uint(492));
    expect(usageTuple.period).toEqual(Cl.uint(period));

    const ledgerTuple = expectLedgerSnapshot(readLedger(fixture, period), 1, 123);
    expect(ledgerTuple['usage-count']).toEqual(Cl.uint(1));
    expect(ledgerTuple['usage-units']).toEqual(Cl.uint(4));
    expect(ledgerTuple['accrued-fees']).toEqual(Cl.uint(492));
    expect(ledgerTuple['settled-fees']).toEqual(Cl.uint(0));
    expect(ledgerTuple['last-settlement-id']).toEqual(Cl.none());

    const settlementId = usageId(nextFill());
    expect(simnet.callPublicFn(
      'integration-fee-collector',
      'settle-fees',
      [principal(fixture.integration), Cl.uint(period), Cl.uint(492), settlementId],
      fixture.payer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const settlementTuple = readTuple(simnet.callReadOnlyFn(
      'integration-fee-collector',
      'get-settlement',
      [settlementId],
      deployer,
    ).result);
    expect(settlementTuple.integration).toEqual(Cl.principal(fixture.integration));
    expect(settlementTuple.period).toEqual(Cl.uint(period));
    expect(settlementTuple.payer).toEqual(Cl.principal(fixture.payer));
    expect(settlementTuple.amount).toEqual(Cl.uint(492));
    expect(expectLedgerSnapshot(readLedger(fixture, period), 1, 123)['settled-fees'])
      .toEqual(Cl.uint(492));
  });
});
