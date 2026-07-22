import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const TIER_ID = 1;
const SECOND_TIER_ID = 2;
const CANCELLATION_TIER_ID = 3;
const FEATURELESS_TIER_ID = 4;
const PLAN_VERSION = 1;
const MONTHLY_BLOCKS = 4320;
const ANNUAL_BLOCKS = 51840;
const MONTHLY_PRICE = 1001n;
const ANNUAL_PRICE = 5001n;
const FEATURE_ID = 'api-calls';
const NEW_FEATURE_ID = 'new-feature';
const AFTER_DEACTIVATION_FEATURE_ID = 'after-deactivation';

const error = (code: number) => Cl.error(Cl.uint(code));

describe('Enterprise prepaid subscriptions', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;
  let wallet4: string;

  const contractPrincipal = (name: string) => `${deployer}.${name}`;
  const principal = (value: string) => Cl.principal(value);
  const usageId = (fill: number) => Cl.buffer(Buffer.alloc(32, fill));
  const stxBalance = (address: string): bigint =>
    simnet.getAssetsMap().get('STX')?.get(address) ?? 0n;
  const burnHeight = (): bigint => BigInt((simnet.callReadOnlyFn(
    'block-utils',
    'get-burn-block-height',
    [],
    deployer,
  ).result as any).value);

  const readTuple = (result: any): Record<string, any> => {
    expect(result.type).toBe('ok');
    if (result.value.type === 'tuple') return result.value.value;
    expect(result.value.type).toBe('some');
    expect(result.value.value.type).toBe('tuple');
    return result.value.value.value;
  };

  const readOptionalTuple = (contract: string, method: string, args: any[]) => {
    const result = simnet.callReadOnlyFn(contract, method, args, deployer).result;
    expect(result.type).toBe('ok');
    return result.value;
  };

  const readSubscription = (subscriber: string): Record<string, any> =>
    readTuple(simnet.callReadOnlyFn(
      'enterprise-subscription',
      'get-subscription',
      [principal(subscriber)],
      deployer,
    ).result);

  const publishPlan = (
    tierId: number,
    version: number,
    monthly = MONTHLY_PRICE,
    annual = ANNUAL_PRICE,
    kyc = 2,
  ) => simnet.callPublicFn(
    'enterprise-plan-registry',
    'publish-plan',
    [Cl.uint(tierId), Cl.uint(version), Cl.uint(monthly), Cl.uint(annual), Cl.uint(kyc)],
    deployer,
  ).result;

  const activatePlan = (tierId: number, version: number, active: boolean) =>
    simnet.callPublicFn(
      'enterprise-plan-registry',
      'set-plan-active',
      [Cl.uint(tierId), Cl.uint(version), Cl.bool(active)],
      deployer,
    ).result;

  const subscribe = (
    subscriber: string,
    tierId: number,
    version: number,
    period: number,
    paymentId: number,
    amount: bigint,
  ) => simnet.callPublicFn(
    'enterprise-subscription',
    'subscribe',
    [Cl.uint(tierId), Cl.uint(version), Cl.uint(period), Cl.uint(paymentId), Cl.uint(amount)],
    subscriber,
  ).result;

  const renew = (
    subscriber: string,
    tierId: number,
    version: number,
    period: number,
    paymentId: number,
    amount: bigint,
  ) => simnet.callPublicFn(
    'enterprise-subscription',
    'renew',
    [Cl.uint(tierId), Cl.uint(version), Cl.uint(period), Cl.uint(paymentId), Cl.uint(amount)],
    subscriber,
  ).result;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
    wallet3 = accounts.get('wallet_3')!;
    // The canonical simnet plan has three funded wallets; use the deployer as
    // the fourth independent lifecycle actor when wallet_4 is absent.
    wallet4 = accounts.get('wallet_4') ?? deployer;

    for (const wallet of [wallet1, wallet2, wallet3, wallet4]) simnet.mintSTX(wallet, 200_000n);

    // Wallet 1/3/4 are compliant; wallet 2 is sanctioned for failure paths.
    for (const wallet of [wallet1, wallet3, wallet4]) {
      expect(simnet.callPublicFn(
        'kyc-registry',
        'set-identity-status',
        [principal(wallet), Cl.uint(2), Cl.uint(0), Cl.stringAscii('USA')],
        deployer,
      ).result).toEqual(Cl.ok(Cl.bool(true)));
    }
    expect(simnet.callPublicFn(
      'kyc-registry',
      'set-identity-status',
      [principal(wallet2), Cl.uint(2), Cl.uint(2), Cl.stringAscii('USA')],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(publishPlan(TIER_ID, PLAN_VERSION)).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'enterprise-plan-registry',
      'publish-feature',
      [Cl.uint(TIER_ID), Cl.uint(PLAN_VERSION), Cl.stringAscii(FEATURE_ID), Cl.bool(true), Cl.uint(5)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    // A second tier is published for the global payment-ID collision path.
    expect(publishPlan(SECOND_TIER_ID, PLAN_VERSION)).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'enterprise-plan-registry',
      'publish-feature',
      [Cl.uint(SECOND_TIER_ID), Cl.uint(PLAN_VERSION), Cl.stringAscii(FEATURE_ID), Cl.bool(true), Cl.uint(5)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    // A third tier keeps cancellation/expiry coverage independent from the
    // tier-1 deactivation and renewal cases below.
    expect(publishPlan(CANCELLATION_TIER_ID, PLAN_VERSION)).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'enterprise-plan-registry',
      'publish-feature',
      [Cl.uint(CANCELLATION_TIER_ID), Cl.uint(PLAN_VERSION), Cl.stringAscii(FEATURE_ID), Cl.bool(true), Cl.uint(5)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(activatePlan(CANCELLATION_TIER_ID, PLAN_VERSION, true)).toEqual(Cl.ok(Cl.bool(true)));

    // This is an explicit test integration, not a production default. The
    // deployment posture leaves product consumers empty until governance
    // audits and registers a concrete product contract.
    expect(simnet.callPublicFn(
      'enterprise-subscription',
      'register-consumer',
      [principal(contractPrincipal('enterprise-facade'))],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(publishPlan(FEATURELESS_TIER_ID, PLAN_VERSION)).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('enforces exactly four tier identities, nonzero versions/prices/KYC, and feature-backed activation', () => {
    expect(publishPlan(0, 2)).toEqual(error(5006));
    expect(publishPlan(5, 2)).toEqual(error(5006));
    expect(publishPlan(TIER_ID, 0)).toEqual(error(5001));
    expect(publishPlan(SECOND_TIER_ID, 2, 0n)).toEqual(error(5001));
    expect(publishPlan(SECOND_TIER_ID, 3, MONTHLY_PRICE, 0n)).toEqual(error(5001));
    expect(publishPlan(SECOND_TIER_ID, 4, MONTHLY_PRICE, ANNUAL_PRICE, 0)).toEqual(error(5007));
    expect(publishPlan(SECOND_TIER_ID, 5, MONTHLY_PRICE, ANNUAL_PRICE, 256)).toEqual(error(5007));

    expect(publishPlan(SECOND_TIER_ID, PLAN_VERSION)).toEqual(error(5002));
    expect(simnet.callReadOnlyFn(
      'enterprise-plan-registry',
      'is-plan-active',
      [Cl.uint(TIER_ID), Cl.uint(PLAN_VERSION)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(activatePlan(FEATURELESS_TIER_ID, PLAN_VERSION, true)).toEqual(error(5001));
    expect(simnet.callPublicFn(
      'enterprise-plan-registry',
      'publish-feature',
      [Cl.uint(FEATURELESS_TIER_ID), Cl.uint(PLAN_VERSION), Cl.stringAscii(FEATURE_ID), Cl.bool(true), Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(activatePlan(FEATURELESS_TIER_ID, PLAN_VERSION, true)).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('requires explicit activation, rejects inactive/incorrect purchases, and freezes active features', () => {
    const before = stxBalance(wallet1);
    expect(subscribe(wallet1, TIER_ID, PLAN_VERSION, MONTHLY_BLOCKS, 100, MONTHLY_PRICE)).toEqual(error(5102));
    expect(stxBalance(wallet1)).toBe(before);

    expect(activatePlan(TIER_ID, PLAN_VERSION, true)).toEqual(Cl.ok(Cl.bool(true)));
    expect(activatePlan(SECOND_TIER_ID, PLAN_VERSION, true)).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(
      'enterprise-plan-registry',
      'publish-feature',
      [Cl.uint(TIER_ID), Cl.uint(PLAN_VERSION), Cl.stringAscii(NEW_FEATURE_ID), Cl.bool(true), Cl.uint(1)],
      deployer,
    ).result).toEqual(error(5008));

    const wrongAmountBalance = stxBalance(wallet1);
    expect(subscribe(wallet1, TIER_ID, PLAN_VERSION, MONTHLY_BLOCKS, 101, MONTHLY_PRICE + 1n)).toEqual(error(5117));
    expect(stxBalance(wallet1)).toBe(wrongAmountBalance);
    expect(readOptionalTuple('enterprise-subscription', 'get-subscription', [principal(wallet1)]).type).toBe('none');
  });

  it('enforces KYC/AML, routes exact monthly and annual gross STX, and leaves no residual balance', () => {
    const sanctionedBalance = stxBalance(wallet2);
    expect(subscribe(wallet2, TIER_ID, PLAN_VERSION, MONTHLY_BLOCKS, 102, MONTHLY_PRICE)).toEqual(error(7002));
    expect(stxBalance(wallet2)).toBe(sanctionedBalance);

    const subscription = contractPrincipal('enterprise-subscription');
    const automation = contractPrincipal('revenue-automation');
    const distributor = contractPrincipal('revenue-distributor');
    const fiscalDam = contractPrincipal('cxd-treasury');
    const before = {
      wallet: stxBalance(wallet1),
      subscription: stxBalance(subscription),
      automation: stxBalance(automation),
      distributor: stxBalance(distributor),
      fiscalDam: stxBalance(fiscalDam),
    };

    expect(subscribe(wallet1, TIER_ID, PLAN_VERSION, MONTHLY_BLOCKS, 103, MONTHLY_PRICE)).toEqual(Cl.ok(Cl.bool(true)));
    expect(stxBalance(wallet1)).toBe(before.wallet - MONTHLY_PRICE);
    expect(stxBalance(subscription)).toBe(before.subscription);
    expect(stxBalance(automation)).toBe(before.automation);
    expect(stxBalance(distributor)).toBe(before.distributor);
    expect(stxBalance(fiscalDam)).toBe(before.fiscalDam + MONTHLY_PRICE);

    const receipt = readTuple(simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-stx-receipt',
      [principal(subscription), Cl.uint(103)],
      deployer,
    ).result);
    expect(receipt['gross-amount']).toEqual(Cl.uint(MONTHLY_PRICE));
    expect(receipt['treasury-amount']).toEqual(Cl.uint(450));
    expect(receipt['bounty-amount']).toEqual(Cl.uint(300));
    expect(receipt['lp-amount']).toEqual(Cl.uint(150));
    expect(receipt['grant-amount']).toEqual(Cl.uint(50));
    expect(receipt['buyback-amount']).toEqual(Cl.uint(50));
    expect(receipt['insurance-amount']).toEqual(Cl.uint(1));
    expect(receipt['policy-version']).toEqual(Cl.uint(1));

    const buckets = readTuple(simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-stx-bucket-balances',
      [],
      deployer,
    ).result);
    const bucketTotal = ['treasury', 'bounty', 'lp', 'grant', 'buyback', 'insurance']
      .reduce((total, name) => total + BigInt(buckets[name].value), 0n);
    expect(bucketTotal).toBe(MONTHLY_PRICE);

    const subscriptionRecord = readSubscription(wallet1);
    expect(subscriptionRecord['tier-id']).toEqual(Cl.uint(TIER_ID));
    expect(subscriptionRecord['plan-version']).toEqual(Cl.uint(PLAN_VERSION));
    expect(subscriptionRecord['billing-period']).toEqual(Cl.uint(MONTHLY_BLOCKS));
    expect(subscriptionRecord.active).toEqual(Cl.bool(true));
    expect(subscriptionRecord.cancelled).toEqual(Cl.bool(false));

    const annualBefore = stxBalance(wallet1);
    expect(renew(wallet1, TIER_ID, PLAN_VERSION, ANNUAL_BLOCKS, 104, ANNUAL_PRICE)).toEqual(Cl.ok(Cl.bool(true)));
    expect(stxBalance(wallet1)).toBe(annualBefore - ANNUAL_PRICE);
    expect(readSubscription(wallet1)['billing-period']).toEqual(Cl.uint(ANNUAL_BLOCKS));
    expect(renew(wallet1, TIER_ID, PLAN_VERSION, ANNUAL_BLOCKS, 104, ANNUAL_PRICE)).toEqual(error(5107));
  });

  it('rejects unauthorized revenue entry and atomically protects global payment IDs', () => {
    const subscription = contractPrincipal('enterprise-subscription');
    const fiscalDam = contractPrincipal('cxd-treasury');
    const before = stxBalance(fiscalDam);
    expect(simnet.callPublicFn(
      'cxd-treasury',
      'record-stx-revenue',
      [principal(subscription), Cl.uint(999), Cl.uint(1)],
      wallet1,
    ).result).toEqual(error(1005));
    expect(stxBalance(fiscalDam)).toBe(before);
    expect(simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-stx-receipt',
      [principal(subscription), Cl.uint(999)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.none()));

    const victimBalance = stxBalance(wallet2);
    expect(subscribe(wallet2, SECOND_TIER_ID, PLAN_VERSION, MONTHLY_BLOCKS, 103, MONTHLY_PRICE)).toEqual(error(5107));
    expect(stxBalance(wallet2)).toBe(victimBalance);
    expect(readOptionalTuple('enterprise-subscription', 'get-subscription', [principal(wallet2)]).type).toBe('none');
  });

  it('denies cross-account usage, enforces consumer/zero/limit/replay checks, and reuses IDs in a new period', () => {
    const periodBefore = readSubscription(wallet1)['usage-period-start'].value as bigint;
    const unauthorizedBefore = simnet.callReadOnlyFn(
      'enterprise-subscription',
      'get-usage-total',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), Cl.uint(periodBefore)],
      deployer,
    ).result;
    expect(unauthorizedBefore).toEqual(Cl.ok(Cl.uint(0)));

    expect(simnet.callPublicFn(
      'enterprise-facade',
      'record-subscription-usage',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), usageId(90), Cl.uint(1)],
      wallet2,
    ).result).toEqual(error(5200));
    expect(simnet.callPublicFn(
      'enterprise-subscription',
      'record-usage',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), usageId(91), Cl.uint(1)],
      wallet2,
    ).result).toEqual(error(5115));
    expect(simnet.callPublicFn(
      'enterprise-subscription',
      'record-usage',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), usageId(92), Cl.uint(0)],
      wallet1,
    ).result).toEqual(error(5109));

    expect(simnet.callPublicFn(
      'enterprise-facade',
      'record-subscription-usage',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), usageId(1), Cl.uint(3)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(3)));
    // A top-level simnet call uses its sender as contract-caller, so this
    // registered wallet acts as a second authorized consumer for replay scope.
    expect(simnet.callPublicFn(
      'enterprise-subscription',
      'register-consumer',
      [principal(wallet1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'enterprise-subscription',
      'record-usage',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), usageId(1), Cl.uint(1)],
      wallet1,
    ).result).toEqual(error(5113));
    expect(simnet.callPublicFn(
      'enterprise-facade',
      'record-subscription-usage',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), usageId(1), Cl.uint(1)],
      wallet1,
    ).result).toEqual(error(5113));
    expect(simnet.callPublicFn(
      'enterprise-facade',
      'record-subscription-usage',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), usageId(2), Cl.uint(3)],
      wallet1,
    ).result).toEqual(error(5114));

    const oldRecord = simnet.callReadOnlyFn(
      'enterprise-subscription',
      'get-usage-record',
      [principal(contractPrincipal('enterprise-facade')), principal(wallet1), Cl.stringAscii(FEATURE_ID), Cl.uint(periodBefore), usageId(1)],
      deployer,
    ).result;
    expect(oldRecord.type).toBe('ok');
    expect(oldRecord.value.type).toBe('some');

    const oldPaidThrough = readSubscription(wallet1)['paid-through'];
    expect(renew(wallet1, TIER_ID, PLAN_VERSION, ANNUAL_BLOCKS, 105, ANNUAL_PRICE)).toEqual(Cl.ok(Cl.bool(true)));
    expect(readSubscription(wallet1)['paid-from'].value).toBe(oldPaidThrough.value);
    const periodAfter = readSubscription(wallet1)['usage-period-start'].value as bigint;
    expect(periodAfter).toBe(oldPaidThrough.value);
    expect(periodAfter).not.toBe(periodBefore);

    // The same external usage ID is valid in the new paid period but remains
    // replay-protected inside that period.
    expect(simnet.callPublicFn(
      'enterprise-facade',
      'record-subscription-usage',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), usageId(1), Cl.uint(1)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(1)));
    expect(simnet.callPublicFn(
      'enterprise-facade',
      'record-subscription-usage',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), usageId(1), Cl.uint(1)],
      wallet1,
    ).result).toEqual(error(5113));
  });

  it('keeps cancellation/deactivation period-end semantics and blocks new sales on inactive plans', () => {
    expect(simnet.callPublicFn('enterprise-subscription', 'cancel', [], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(
      'enterprise-subscription',
      'is-entitled',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(readSubscription(wallet1).cancelled).toEqual(Cl.bool(true));

    expect(activatePlan(TIER_ID, PLAN_VERSION, false)).toEqual(Cl.ok(Cl.bool(false)));
    expect(simnet.callPublicFn(
      'enterprise-plan-registry',
      'publish-feature',
      [Cl.uint(TIER_ID), Cl.uint(PLAN_VERSION), Cl.stringAscii(AFTER_DEACTIVATION_FEATURE_ID), Cl.bool(true), Cl.uint(1)],
      deployer,
    ).result).toEqual(error(5008));
    expect(simnet.callReadOnlyFn(
      'enterprise-subscription',
      'is-entitled',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(renew(wallet1, TIER_ID, PLAN_VERSION, MONTHLY_BLOCKS, 106, MONTHLY_PRICE)).toEqual(error(5102));
    expect(subscribe(wallet2, TIER_ID, PLAN_VERSION, MONTHLY_BLOCKS, 107, MONTHLY_PRICE)).toEqual(error(5102));
    expect(readOptionalTuple('enterprise-subscription', 'get-subscription', [principal(wallet2)]).type).toBe('none');

    // Cancellation is period-end only: entitlement survives cancellation,
    // then ends exactly at the exclusive paid-through boundary.
    expect(subscribe(wallet3, CANCELLATION_TIER_ID, PLAN_VERSION, MONTHLY_BLOCKS, 108, MONTHLY_PRICE))
      .toEqual(Cl.ok(Cl.bool(true)));
    const cancellationPaidThrough = readSubscription(wallet3)['paid-through'].value as bigint;
    expect(simnet.callPublicFn('enterprise-subscription', 'cancel', [], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(
      'enterprise-subscription',
      'is-entitled',
      [principal(wallet3), Cl.stringAscii(FEATURE_ID)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const blocksToCancellationExpiry = cancellationPaidThrough - burnHeight();
    if (blocksToCancellationExpiry > 0n) simnet.mineEmptyBlocks(Number(blocksToCancellationExpiry));
    while (burnHeight() < cancellationPaidThrough) simnet.mineEmptyBlocks(1);
    expect(simnet.callReadOnlyFn(
      'enterprise-subscription',
      'is-entitled',
      [principal(wallet3), Cl.stringAscii(FEATURE_ID)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));
  });

  it('checks renewal before, exactly at, and after expiry without automatic renewal', () => {
    // Reactivate only for this explicit lifecycle test.
    expect(activatePlan(TIER_ID, PLAN_VERSION, true)).toEqual(Cl.ok(Cl.bool(true)));

    expect(subscribe(wallet4, TIER_ID, PLAN_VERSION, MONTHLY_BLOCKS, 201, MONTHLY_PRICE)).toEqual(Cl.ok(Cl.bool(true)));
    const beforeExpiry = readSubscription(wallet4);
    const beforePaidThrough = beforeExpiry['paid-through'].value as bigint;
    expect(renew(wallet4, TIER_ID, PLAN_VERSION, MONTHLY_BLOCKS, 202, MONTHLY_PRICE)).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(
      'kyc-registry',
      'set-identity-status',
      [principal(wallet2), Cl.uint(2), Cl.uint(0), Cl.stringAscii('USA')],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(subscribe(wallet2, TIER_ID, PLAN_VERSION, MONTHLY_BLOCKS, 203, MONTHLY_PRICE)).toEqual(Cl.ok(Cl.bool(true)));
    const exactPaidThrough = readSubscription(wallet2)['paid-through'].value as bigint;
    const blocksToExact = exactPaidThrough - burnHeight();
    if (blocksToExact > 0n) simnet.mineEmptyBlocks(Number(blocksToExact));
    while (burnHeight() < exactPaidThrough) simnet.mineEmptyBlocks(1);
    expect(simnet.callReadOnlyFn(
      'enterprise-subscription',
      'is-entitled',
      [principal(wallet2), Cl.stringAscii(FEATURE_ID)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(readSubscription(wallet2)['paid-through'].value).toBe(exactPaidThrough);

    expect(renew(wallet2, TIER_ID, PLAN_VERSION, MONTHLY_BLOCKS, 204, MONTHLY_PRICE)).toEqual(Cl.ok(Cl.bool(true)));
    expect(readSubscription(wallet2)['paid-from'].value).toBeGreaterThanOrEqual(exactPaidThrough);

    // The canceled tier-3 subscription above supplies a distinct after-expiry
    // case, then proves renewal is still explicit and current-height based.
    const afterPaidThrough = readSubscription(wallet3)['paid-through'].value as bigint;
    const blocksPastExpiry = afterPaidThrough - burnHeight() + 1n;
    if (blocksPastExpiry > 0n) simnet.mineEmptyBlocks(Number(blocksPastExpiry));
    expect(simnet.callReadOnlyFn(
      'enterprise-subscription',
      'is-entitled',
      [principal(wallet3), Cl.stringAscii(FEATURE_ID)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));
    expect(renew(wallet3, CANCELLATION_TIER_ID, PLAN_VERSION, MONTHLY_BLOCKS, 205, MONTHLY_PRICE)).toEqual(Cl.ok(Cl.bool(true)));
    expect(readSubscription(wallet3)['paid-from'].value).toBeGreaterThan(afterPaidThrough);
    expect(beforePaidThrough).toBeGreaterThan(0n);
  });
});
