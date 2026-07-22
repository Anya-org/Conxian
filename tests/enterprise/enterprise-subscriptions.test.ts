import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const PLAN_ID = 503;
const PLAN_VERSION = 1;
const MONTHLY_BLOCKS = 4320;
const ANNUAL_BLOCKS = 51840;
const MONTHLY_PRICE = 1001n;
const ANNUAL_PRICE = 5001n;
const FEATURE_ID = 'api-calls';

describe('Enterprise prepaid subscriptions', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;

  const contractPrincipal = (name: string) => `${deployer}.${name}`;
  const principal = (value: string) => Cl.principal(value);
  const usageId = (fill: number) => Cl.buffer(Buffer.alloc(32, fill));
  const stxBalance = (address: string): bigint =>
    simnet.getAssetsMap().get('STX')?.get(address) ?? 0n;

  const readTuple = (result: any): Record<string, any> => {
    expect(result.type).toBe('ok');
    if (result.value.type === 'tuple') return result.value.value;
    expect(result.value.type).toBe('some');
    expect(result.value.value.type).toBe('tuple');
    return result.value.value.value;
  };

  const readSubscription = (subscriber: string): Record<string, any> =>
    readTuple(simnet.callReadOnlyFn(
      'enterprise-subscription',
      'get-subscription',
      [principal(subscriber)],
      deployer,
    ).result);

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;

    simnet.mintSTX(wallet1, 100_000n);
    simnet.mintSTX(wallet2, 100_000n);

    expect(simnet.callPublicFn(
      'kyc-registry',
      'set-identity-status',
      [principal(wallet1), Cl.uint(2), Cl.uint(0), Cl.stringAscii('USA')],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'kyc-registry',
      'set-identity-status',
      [principal(wallet2), Cl.uint(2), Cl.uint(2), Cl.stringAscii('USA')],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(
      'enterprise-plan-registry',
      'publish-plan',
      [
        Cl.uint(PLAN_ID),
        Cl.uint(PLAN_VERSION),
        Cl.uint(2),
        Cl.uint(MONTHLY_PRICE),
        Cl.uint(ANNUAL_PRICE),
        Cl.uint(2),
      ],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'enterprise-plan-registry',
      'publish-feature',
      [Cl.uint(PLAN_ID), Cl.uint(PLAN_VERSION), Cl.stringAscii(FEATURE_ID), Cl.bool(true), Cl.uint(5)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'enterprise-plan-registry',
      'set-plan-active',
      [Cl.uint(PLAN_ID), Cl.uint(PLAN_VERSION), Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(
      'enterprise-subscription',
      'register-consumer',
      [principal(contractPrincipal('enterprise-facade'))],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('requires explicit activation, compliance, and the full gross-STX Fiscal Dam route', () => {
    expect(simnet.callPublicFn(
      'enterprise-plan-registry',
      'publish-plan',
      [
        Cl.uint(PLAN_ID),
        Cl.uint(PLAN_VERSION),
        Cl.uint(2),
        Cl.uint(MONTHLY_PRICE),
        Cl.uint(ANNUAL_PRICE),
        Cl.uint(2),
      ],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(5002)));
    expect(simnet.callPublicFn(
      'enterprise-plan-registry',
      'publish-feature',
      [Cl.uint(PLAN_ID), Cl.uint(PLAN_VERSION), Cl.stringAscii(FEATURE_ID), Cl.bool(true), Cl.uint(5)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(5004)));

    expect(simnet.callPublicFn(
      'enterprise-plan-registry',
      'set-plan-active',
      [Cl.uint(PLAN_ID), Cl.uint(PLAN_VERSION), Cl.bool(false)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));

    const inactiveBalance = stxBalance(wallet1);
    expect(simnet.callPublicFn(
      'enterprise-subscription',
      'subscribe',
      [Cl.uint(PLAN_ID), Cl.uint(PLAN_VERSION), Cl.uint(MONTHLY_BLOCKS), Cl.uint(1)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(5102)));
    expect(stxBalance(wallet1)).toBe(inactiveBalance);

    expect(simnet.callPublicFn(
      'enterprise-plan-registry',
      'set-plan-active',
      [Cl.uint(PLAN_ID), Cl.uint(PLAN_VERSION), Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const sanctionedBalance = stxBalance(wallet2);
    expect(simnet.callPublicFn(
      'enterprise-subscription',
      'subscribe',
      [Cl.uint(PLAN_ID), Cl.uint(PLAN_VERSION), Cl.uint(MONTHLY_BLOCKS), Cl.uint(1)],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(7002)));
    expect(stxBalance(wallet2)).toBe(sanctionedBalance);

    const subscription = contractPrincipal('enterprise-subscription');
    const automation = contractPrincipal('revenue-automation');
    const distributor = contractPrincipal('revenue-distributor');
    const fiscalDam = contractPrincipal('cxd-treasury');
    const subscriptionBefore = stxBalance(subscription);
    const automationBefore = stxBalance(automation);
    const distributorBefore = stxBalance(distributor);
    const fiscalDamBefore = stxBalance(fiscalDam);
    const walletBefore = stxBalance(wallet1);

    expect(simnet.callPublicFn(
      'enterprise-subscription',
      'subscribe',
      [Cl.uint(PLAN_ID), Cl.uint(PLAN_VERSION), Cl.uint(MONTHLY_BLOCKS), Cl.uint(1)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(stxBalance(wallet1)).toBe(walletBefore - MONTHLY_PRICE);
    expect(stxBalance(subscription)).toBe(subscriptionBefore);
    expect(stxBalance(automation)).toBe(automationBefore);
    expect(stxBalance(distributor)).toBe(distributorBefore);
    expect(stxBalance(fiscalDam)).toBe(fiscalDamBefore + MONTHLY_PRICE);

    const receipt = readTuple(simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-stx-receipt',
      [principal(subscription), Cl.uint(1)],
      deployer,
    ).result);
    expect(receipt['gross-amount']).toEqual(Cl.uint(MONTHLY_PRICE));
    expect(receipt['treasury-amount']).toEqual(Cl.uint(450));
    expect(receipt['bounty-amount']).toEqual(Cl.uint(300));
    expect(receipt['lp-amount']).toEqual(Cl.uint(150));
    expect(receipt['grant-amount']).toEqual(Cl.uint(50));
    expect(receipt['buyback-amount']).toEqual(Cl.uint(50));
    expect(receipt['insurance-amount']).toEqual(Cl.uint(1));

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
    expect(subscriptionRecord['plan-id']).toEqual(Cl.uint(PLAN_ID));
    expect(subscriptionRecord['plan-version']).toEqual(Cl.uint(PLAN_VERSION));
    expect(subscriptionRecord['billing-period']).toEqual(Cl.uint(MONTHLY_BLOCKS));
    expect(subscriptionRecord.active).toEqual(Cl.bool(true));
    expect(subscriptionRecord.cancelled).toEqual(Cl.bool(false));
  });

  it('enforces namespaced, replay-protected usage limits and period-end cancellation', () => {
    expect(simnet.callPublicFn(
      'enterprise-subscription',
      'record-usage',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), usageId(99), Cl.uint(1)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(5109)));

    const entitlement = readTuple(simnet.callReadOnlyFn(
      'enterprise-subscription',
      'get-entitlement',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID)],
      deployer,
    ).result);
    expect(entitlement.entitled).toEqual(Cl.bool(true));
    expect(entitlement.limit).toEqual(Cl.uint(5));
    expect(entitlement.used).toEqual(Cl.uint(0));
    expect(entitlement.remaining).toEqual(Cl.uint(5));

    expect(simnet.callPublicFn(
      'enterprise-facade',
      'record-subscription-usage',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), usageId(1), Cl.uint(3)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(3)));
    expect(simnet.callPublicFn(
      'enterprise-facade',
      'record-subscription-usage',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), usageId(1), Cl.uint(3)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(5113)));
    expect(simnet.callPublicFn(
      'enterprise-facade',
      'record-subscription-usage',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID), usageId(2), Cl.uint(3)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(5114)));

    expect(simnet.callPublicFn(
      'enterprise-subscription',
      'cancel',
      [],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(
      'enterprise-subscription',
      'is-entitled',
      [principal(wallet1), Cl.stringAscii(FEATURE_ID)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(readSubscription(wallet1).cancelled).toEqual(Cl.bool(true));

    const priorPaidThrough = readSubscription(wallet1)['paid-through'];
    expect(simnet.callPublicFn(
      'enterprise-subscription',
      'renew',
      [Cl.uint(PLAN_ID), Cl.uint(PLAN_VERSION), Cl.uint(ANNUAL_BLOCKS), Cl.uint(2)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const renewed = readSubscription(wallet1);
    expect(renewed['paid-from'].value).toBe(priorPaidThrough.value);
    expect(renewed['paid-through'].value).toBe(priorPaidThrough.value + BigInt(ANNUAL_BLOCKS));
    expect(renewed['billing-period']).toEqual(Cl.uint(ANNUAL_BLOCKS));
    expect(renewed.cancelled).toEqual(Cl.bool(false));

    expect(simnet.callPublicFn(
      'enterprise-subscription',
      'renew',
      [Cl.uint(PLAN_ID), Cl.uint(PLAN_VERSION), Cl.uint(ANNUAL_BLOCKS), Cl.uint(2)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(5107)));
  });
});
