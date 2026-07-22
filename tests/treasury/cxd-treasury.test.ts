import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const error = (code: number) => Cl.error(Cl.uint(code));

describe('CXD treasury Fiscal Dam custody', () => {
  let deployer: string;
  let source: string;
  let recipient: string;

  const principal = (value: string) => Cl.principal(value);
  const treasury = () => `${deployer}.cxd-treasury`;
  const stxBalance = (address: string): bigint =>
    simnet.getAssetsMap().get('STX')?.get(address) ?? 0n;
  const readTuple = (result: any): Record<string, any> => {
    expect(result.type).toBe('ok');
    if (result.value.type === 'tuple') return result.value.value;
    expect(result.value.type).toBe('some');
    expect(result.value.value.type).toBe('tuple');
    return result.value.value.value;
  };

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    source = accounts.get('wallet_1')!;
    recipient = accounts.get('wallet_2')!;
    simnet.mintSTX(source, 20_000n);
    simnet.mintSTX(recipient, 20_000n);

    expect(simnet.callPublicFn(
      'cxd-treasury',
      'authorize-stx-source',
      [principal(source)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'revenue-distributor',
      'authorize-stx-source',
      [principal(source)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('preserves six-way allocation, bounds, gross receipts, and policy evidence', () => {
    expect(simnet.callReadOnlyFn('cxd-treasury', 'get-policy-version', [], deployer).result)
      .toEqual(Cl.ok(Cl.uint(1)));
    expect(simnet.callReadOnlyFn('cxd-treasury', 'get-bounds', [], deployer).result)
      .toEqual(Cl.ok(Cl.tuple({ 'min-lp': Cl.uint(0), 'max-insurance': Cl.uint(10_000) })));

    expect(simnet.callPublicFn(
      'revenue-distributor',
      'distribute-stx',
      [Cl.uint(1001)],
      source,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const firstReceipt = readTuple(simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-stx-receipt',
      [principal(source), Cl.uint(1)],
      deployer,
    ).result);
    expect(firstReceipt['gross-amount']).toEqual(Cl.uint(1001));
    expect(firstReceipt['treasury-amount']).toEqual(Cl.uint(450));
    expect(firstReceipt['bounty-amount']).toEqual(Cl.uint(300));
    expect(firstReceipt['lp-amount']).toEqual(Cl.uint(150));
    expect(firstReceipt['grant-amount']).toEqual(Cl.uint(50));
    expect(firstReceipt['buyback-amount']).toEqual(Cl.uint(50));
    expect(firstReceipt['insurance-amount']).toEqual(Cl.uint(1));
    expect(firstReceipt['policy-version']).toEqual(Cl.uint(1));

    expect(simnet.callPublicFn(
      'cxd-treasury',
      'set-bounds',
      [Cl.uint(2000), Cl.uint(100)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'cxd-treasury',
      'rebalance',
      [Cl.uint(4500), Cl.uint(3000), Cl.uint(1500), Cl.uint(500), Cl.uint(500), Cl.uint(0)],
      deployer,
    ).result).toEqual(error(1003));
    expect(simnet.callPublicFn(
      'cxd-treasury',
      'rebalance',
      [Cl.uint(4499), Cl.uint(3000), Cl.uint(1500), Cl.uint(500), Cl.uint(500), Cl.uint(1)],
      deployer,
    ).result).toEqual(error(1003));
    expect(simnet.callPublicFn(
      'cxd-treasury',
      'set-bounds',
      [Cl.uint(0), Cl.uint(10_000)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'cxd-treasury',
      'set-bounds',
      [Cl.uint(0), Cl.uint(10_001)],
      deployer,
    ).result).toEqual(error(1003));

    expect(simnet.callPublicFn(
      'cxd-treasury',
      'rebalance',
      [Cl.uint(4000), Cl.uint(3000), Cl.uint(2000), Cl.uint(500), Cl.uint(500), Cl.uint(0)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn('cxd-treasury', 'get-policy-version', [], deployer).result)
      .toEqual(Cl.ok(Cl.uint(2)));

    expect(simnet.callPublicFn(
      'revenue-distributor',
      'distribute-stx',
      [Cl.uint(1000)],
      source,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const secondReceipt = readTuple(simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-stx-receipt',
      [principal(source), Cl.uint(2)],
      deployer,
    ).result);
    expect(secondReceipt['policy-version']).toEqual(Cl.uint(2));
    expect(secondReceipt['treasury-amount']).toEqual(Cl.uint(400));
    expect(secondReceipt['bounty-amount']).toEqual(Cl.uint(300));
    expect(secondReceipt['lp-amount']).toEqual(Cl.uint(200));
    expect(secondReceipt['grant-amount']).toEqual(Cl.uint(50));
    expect(secondReceipt['buyback-amount']).toEqual(Cl.uint(50));
    expect(secondReceipt['insurance-amount']).toEqual(Cl.uint(0));

    const accounting = readTuple(simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-stx-accounting',
      [],
      deployer,
    ).result);
    expect(accounting['gross-received']).toEqual(Cl.uint(2001));
    expect(accounting.released).toEqual(Cl.uint(0));
    expect(accounting['bucket-total']).toEqual(Cl.uint(2001));
    expect(accounting['accounted-total']).toEqual(Cl.uint(2001));
  });

  it('fails closed for bucket destinations and governs replay-safe custody release', () => {
    expect(simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-stx-bucket-recipient',
      [Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.none()));

    const bucketBefore = readTuple(simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-stx-bucket-balances',
      [],
      deployer,
    ).result).treasury.value as bigint;
    const recipientBefore = stxBalance(recipient);

    expect(simnet.callPublicFn(
      'cxd-treasury',
      'release-stx-bucket',
      [Cl.uint(1), Cl.uint(1), Cl.uint(100)],
      source,
    ).result).toEqual(error(1000));
    expect(simnet.callPublicFn(
      'cxd-treasury',
      'release-stx-bucket',
      [Cl.uint(1), Cl.uint(1), Cl.uint(0)],
      deployer,
    ).result).toEqual(error(1008));
    expect(simnet.callPublicFn(
      'cxd-treasury',
      'release-stx-bucket',
      [Cl.uint(1), Cl.uint(1), Cl.uint(100)],
      deployer,
    ).result).toEqual(error(1010));

    expect(simnet.callPublicFn(
      'cxd-treasury',
      'set-stx-bucket-recipient',
      [Cl.uint(7), principal(recipient)],
      deployer,
    ).result).toEqual(error(1009));
    expect(simnet.callPublicFn(
      'cxd-treasury',
      'set-stx-bucket-recipient',
      [Cl.uint(1), principal(treasury())],
      deployer,
    ).result).toEqual(error(1013));
    expect(simnet.callPublicFn(
      'cxd-treasury',
      'set-stx-bucket-recipient',
      [Cl.uint(1), principal(recipient)],
      source,
    ).result).toEqual(error(1000));
    expect(simnet.callPublicFn(
      'cxd-treasury',
      'set-stx-bucket-recipient',
      [Cl.uint(1), principal(recipient)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(
      'cxd-treasury',
      'release-stx-bucket',
      [Cl.uint(1), Cl.uint(1), Cl.uint(100)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(stxBalance(recipient)).toBe(recipientBefore + 100n);
    expect(readTuple(simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-stx-bucket-balances',
      [],
      deployer,
    ).result).treasury).toEqual(Cl.uint(bucketBefore - 100n));

    const releaseReceipt = readTuple(simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-stx-release-receipt',
      [Cl.uint(1), Cl.uint(1)],
      deployer,
    ).result);
    expect(releaseReceipt.bucket).toEqual(Cl.uint(1));
    expect(releaseReceipt['release-id']).toEqual(Cl.uint(1));
    expect(releaseReceipt.recipient).toEqual(principal(recipient));
    expect(releaseReceipt.amount).toEqual(Cl.uint(100));

    const afterFirstRelease = stxBalance(recipient);
    expect(simnet.callPublicFn(
      'cxd-treasury',
      'release-stx-bucket',
      [Cl.uint(1), Cl.uint(1), Cl.uint(1)],
      deployer,
    ).result).toEqual(error(1011));
    expect(stxBalance(recipient)).toBe(afterFirstRelease);

    expect(simnet.callPublicFn(
      'cxd-treasury',
      'release-stx-bucket',
      [Cl.uint(1), Cl.uint(2), Cl.uint(bucketBefore)],
      deployer,
    ).result).toEqual(error(1012));
    expect(simnet.callPublicFn(
      'cxd-treasury',
      'clear-stx-bucket-recipient',
      [Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      'cxd-treasury',
      'release-stx-bucket',
      [Cl.uint(1), Cl.uint(2), Cl.uint(1)],
      deployer,
    ).result).toEqual(error(1010));

    const accounting = readTuple(simnet.callReadOnlyFn(
      'cxd-treasury',
      'get-stx-accounting',
      [],
      deployer,
    ).result);
    expect(accounting['gross-received']).toEqual(Cl.uint(2001));
    expect(accounting.released).toEqual(Cl.uint(100));
    expect(accounting['accounted-total']).toEqual(Cl.uint(2001));
  });
});
