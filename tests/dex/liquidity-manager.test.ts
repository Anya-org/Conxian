import { beforeAll, describe, expect, it } from 'vitest';
import { tx } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';
import { initializeSimnet, simnet } from '../setup-test-env';

const BASIS_POINTS = 10000n;
const MAX_UINT = (2n ** 128n) - 1n;
const MAX_BPS_QUOTIENT = MAX_UINT / BASIS_POINTS;
const MAX_BPS_REMAINDER = MAX_UINT % BASIS_POINTS;

describe('Liquidity manager intent and risk ledger', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;

  const error = (code: number | bigint) => Cl.error(Cl.uint(code));
  const token = (name: string) => Cl.contractPrincipal(deployer, name);
  const oracle = () => Cl.contractPrincipal(deployer, 'oracle');

  function positionId(result: any): bigint {
    return BigInt(result.result.value.value);
  }

  function pretty(value: any): string {
    return Cl.prettyPrint(value);
  }

  function setCompliance(user: string) {
    const result = simnet.callPublicFn(
      'regulatory-adapter',
      'verify-and-update-compliance',
      [
        Cl.principal(user),
        Cl.stringAscii('USA'),
        Cl.uint(1),
        Cl.buffer(Buffer.alloc(65, 1)),
      ],
      deployer,
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
  }

  function submitPrice(asset: ReturnType<typeof token>, price: bigint) {
    const first = simnet.callPublicFn(
      'oracle-aggregator',
      'submit-price',
      [asset, Cl.uint(price)],
      deployer,
    );
    const second = simnet.callPublicFn(
      'oracle-aggregator',
      'submit-price',
      [asset, Cl.uint(price)],
      wallet1,
    );
    expect(first.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(second.result).toEqual(Cl.ok(Cl.bool(true)));
  }

  function updatePrice(asset: ReturnType<typeof token>, price: bigint) {
    const first = simnet.callPublicFn(
      'oracle-aggregator',
      'submit-price',
      [asset, Cl.uint(price)],
      deployer,
    );
    const second = simnet.callPublicFn(
      'oracle-aggregator',
      'submit-price',
      [asset, Cl.uint(price)],
      wallet1,
    );
    expect(first.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(second.result).toEqual(Cl.ok(Cl.bool(true)));
  }

  function seedValidatedPrices(
    entries: Array<{
      asset: ReturnType<typeof token>;
      firstSpot: bigint;
      secondSpot: bigint;
      twapPrice: bigint;
    }>,
  ) {
    const startResults = simnet.mineBlock(
      entries.map(({ asset, twapPrice }) =>
        tx.callPublicFn(
          'twap-oracle',
          'update-price-observation',
          [asset, Cl.uint(twapPrice)],
          deployer,
        ),
      ),
    );
    expect(startResults.map((result) => result.result)).toEqual(
      entries.map(() => Cl.ok(Cl.bool(true))),
    );

    simnet.mineBlock(
      entries.map(({ asset, twapPrice }) =>
        tx.callPublicFn(
          'twap-oracle',
          'update-price-observation',
          [asset, Cl.uint(twapPrice)],
          deployer,
        ),
      ),
    );

    const results = simnet.mineBlock(
      entries.flatMap(({ asset, firstSpot, secondSpot, twapPrice }) => [
        tx.callPublicFn(
          'oracle-aggregator',
          'submit-price',
          [asset, Cl.uint(firstSpot)],
          deployer,
        ),
        tx.callPublicFn(
          'oracle-aggregator',
          'submit-price',
          [asset, Cl.uint(secondSpot)],
          wallet1,
        ),
        tx.callPublicFn(
          'twap-oracle',
          'update-price-observation',
          [asset, Cl.uint(twapPrice)],
          deployer,
        ),
      ]),
    );

    expect(results.map((result) => result.result)).toEqual(
      entries.flatMap(() => [
        Cl.ok(Cl.bool(true)),
        Cl.ok(Cl.bool(true)),
        Cl.ok(Cl.bool(true)),
      ]),
    );
  }

  function seedValidatedPrice(
    asset: ReturnType<typeof token>,
    firstSpot: bigint,
    secondSpot: bigint,
    twapPrice: bigint,
  ) {
    seedValidatedPrices([{ asset, firstSpot, secondSpot, twapPrice }]);
  }

  function seedValidatedPricesWithAdminOverride(
    entries: Array<{ asset: ReturnType<typeof token>; price: bigint }>,
  ) {
    const startResults = simnet.mineBlock(
      entries.map(({ asset, price }) =>
        tx.callPublicFn(
          'twap-oracle',
          'update-price-observation',
          [asset, Cl.uint(price)],
          deployer,
        ),
      ),
    );
    expect(startResults.map((result) => result.result)).toEqual(
      entries.map(() => Cl.ok(Cl.bool(true))),
    );

    simnet.mineBlock(
      entries.map(({ asset, price }) =>
        tx.callPublicFn(
          'twap-oracle',
          'update-price-observation',
          [asset, Cl.uint(price)],
          deployer,
        ),
      ),
    );

    const results = simnet.mineBlock(
      entries.flatMap(({ asset, price }) => [
        tx.callPublicFn('oracle-aggregator', 'set-price', [asset, Cl.uint(price)], deployer),
        tx.callPublicFn('oracle-aggregator', 'submit-price', [asset, Cl.uint(price)], wallet1),
        tx.callPublicFn(
          'twap-oracle',
          'update-price-observation',
          [asset, Cl.uint(price)],
          deployer,
        ),
      ]),
    );

    expect(results.map((result) => result.result)).toEqual(
      entries.flatMap(() => [
        Cl.ok(Cl.bool(true)),
        Cl.ok(Cl.bool(true)),
        Cl.ok(Cl.bool(true)),
      ]),
    );
  }

  function openPositionWithValidatedAssets(
    caller: string,
    args: any[],
    token0: ReturnType<typeof token>,
    token1: ReturnType<typeof token>,
    twap0: bigint,
    twap1: bigint,
  ) {
    const results = simnet.mineBlock([
      tx.callPublicFn(
        'twap-oracle',
        'update-price-observation',
        [token0, Cl.uint(twap0)],
        deployer,
      ),
      tx.callPublicFn(
        'twap-oracle',
        'update-price-observation',
        [token1, Cl.uint(twap1)],
        deployer,
      ),
      tx.callPublicFn('liquidity-manager', 'open-position-with-assets', args, caller),
    ]);

    expect(results.slice(0, 2).map((result) => result.result)).toEqual([
      Cl.ok(Cl.bool(true)),
      Cl.ok(Cl.bool(true)),
    ]);
    return results[2];
  }

  function openPosition(
    caller: string,
    poolId = 1n,
    lower = -10,
    upper = 10,
    liquidity = 1000n,
  ) {
    return simnet.callPublicFn(
      'liquidity-manager',
      'open-position',
      [Cl.uint(poolId), Cl.int(lower), Cl.int(upper), Cl.uint(liquidity)],
      caller,
    );
  }

  beforeAll(async () => {
    await initializeSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;

    expect(
      simnet.callPublicFn(
        'regulatory-adapter',
        'update-authority',
        [
          Cl.principal(deployer),
          Cl.buffer(Buffer.concat([Buffer.from([2]), Buffer.alloc(32, 1)])),
        ],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    setCompliance(wallet1);

    expect(
      simnet.callPublicFn(
        'oracle-aggregator',
        'set-source-authorized',
        [Cl.principal(deployer), Cl.bool(true)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(
        'oracle-aggregator',
        'set-source-authorized',
        [Cl.principal(wallet1), Cl.bool(true)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(
        'oracle-aggregator',
        'set-price-decimals',
        [Cl.uint(8)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn('twap-oracle', 'set-price-decimals', [Cl.uint(8)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(
        'twap-oracle',
        'set-twap-window',
        [Cl.uint(1)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn('liquidity-manager', 'set-oracle', [oracle()], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('preserves the open-position signature, allocates IDs from one, and records no custody', () => {
    const first = openPosition(wallet1);
    const second = openPosition(wallet1, 2n, -20, 20, 2000n);
    const firstId = positionId(first);
    const secondId = positionId(second);

    expect(first.result).toEqual(Cl.ok(Cl.uint(firstId)));
    expect(second.result).toEqual(Cl.ok(Cl.uint(secondId)));
    expect(secondId).toBe(firstId + 1n);
    expect(firstId).toBeGreaterThan(0n);
    expect(first.events.some((event) => event.event === 'ft_transfer_event')).toBe(false);

    const stored = simnet.callReadOnlyFn(
      'liquidity-manager',
      'get-position',
      [Cl.uint(firstId)],
      deployer,
    );
    const printed = pretty(stored.result);
    expect(printed).toContain('requested-liquidity: u1000');
    expect(printed).toContain('accounted-liquidity: u0');
    expect(printed).toContain('active: true');
    expect(first.events.some((event) => event.event === 'print_event')).toBe(true);
  });

  it('fails closed for compliance and all position validation boundaries', () => {
    expect(openPosition(wallet2).result).toEqual(error(2003));
    expect(openPosition(wallet1, 0n).result).toEqual(error(2004));
    expect(openPosition(wallet1, 1n, -10, 10, 0n).result).toEqual(error(2005));
    expect(openPosition(wallet1, 1n, 10, 10).result).toEqual(error(2006));
    expect(openPosition(wallet1, 1n, 10, -10).result).toEqual(error(2006));
    expect(openPosition(wallet1, 1n, -887273, 0).result).toEqual(error(2006));
    expect(openPosition(wallet1, 1n, 0, 887273).result).toEqual(error(2006));
  });

  it('requires the canonical oracle and records validated nonzero entry prices', () => {
    const asset0 = token('lm-entry-token-0');
    const asset1 = token('lm-entry-token-1');

    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'set-oracle',
        [Cl.contractPrincipal(deployer, 'chainlink-adapter')],
        deployer,
      ).result,
    ).toEqual(error(2008));
    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'set-oracle-source',
        [Cl.contractPrincipal(deployer, 'chainlink-adapter')],
        deployer,
      ).result,
    ).toEqual(error(2008));

    expect(
      simnet.callPublicFn('liquidity-manager', 'set-oracle', [oracle()], wallet1).result,
    ).toEqual(error(1000));
    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'open-position-with-assets',
        [
          Cl.uint(1),
          Cl.int(-10),
          Cl.int(10),
          Cl.uint(500),
          asset0,
          asset1,
          Cl.contractPrincipal(deployer, 'chainlink-adapter'),
          Cl.uint(100),
        ],
        wallet1,
      ).result,
    ).toEqual(error(2008));

    seedValidatedPrices([
      { asset: asset0, firstSpot: 100n, secondSpot: 100n, twapPrice: 100n },
      { asset: asset1, firstSpot: 200n, secondSpot: 200n, twapPrice: 200n },
    ]);

    const opened = openPositionWithValidatedAssets(
      wallet1,
      [Cl.uint(1), Cl.int(-10), Cl.int(10), Cl.uint(500), asset0, asset1, oracle(), Cl.uint(100)],
      asset0,
      asset1,
      100n,
      200n,
    );
    const openedId = positionId(opened);
    expect(opened.result).toEqual(Cl.ok(Cl.uint(openedId)));
    expect(opened.events.some((event) => event.event === 'ft_transfer_event')).toBe(false);

    const stored = simnet.callReadOnlyFn(
      'liquidity-manager',
      'get-position',
      [Cl.uint(openedId)],
      deployer,
    );
    const printed = pretty(stored.result);
    expect(printed).toContain('token-0: (some');
    expect(printed).toContain('token-1: (some');
    expect(printed).toContain('entry-price-0: (some u100)');
    expect(printed).toContain('entry-price-1: (some u200)');
    expect(printed).toContain('accounted-liquidity: u0');
    expect(printed).toContain('max-price-move-bps: u100');
  });

  it('rejects zero prices, duplicate assets, and limits above 10000 bps', () => {
    const valid0 = token('lm-boundary-token-0');
    const valid1 = token('lm-boundary-token-1');
    seedValidatedPrices([
      { asset: valid0, firstSpot: 10n, secondSpot: 10n, twapPrice: 10n },
      { asset: valid1, firstSpot: 20n, secondSpot: 20n, twapPrice: 20n },
    ]);

    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'open-position-with-assets',
        [Cl.uint(4), Cl.int(-1), Cl.int(1), Cl.uint(1), valid0, valid1, oracle(), Cl.uint(10001)],
        wallet1,
      ).result,
    ).toEqual(error(2009));
    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'open-position-with-assets',
        [Cl.uint(4), Cl.int(-1), Cl.int(1), Cl.uint(1), valid0, valid0, oracle(), Cl.uint(100)],
        wallet1,
      ).result,
    ).toEqual(error(2011));

    const zero0 = token('lm-zero-token-0');
    seedValidatedPrice(zero0, 0n, 0n, 0n);
    const zeroOpening = openPositionWithValidatedAssets(
      wallet1,
      [Cl.uint(4), Cl.int(-1), Cl.int(1), Cl.uint(1), zero0, valid1, oracle(), Cl.uint(100)],
      zero0,
      valid1,
      0n,
      20n,
    );
    expect(zeroOpening.result).toEqual(error(7003));
  });

  it('requires fresh canonical TWAP data and enforces the inclusive deviation boundary', () => {
    const missingTwap0 = token('lm-missing-twap-token-0');
    const missingTwap1 = token('lm-missing-twap-token-1');
    submitPrice(missingTwap0, 100n);
    submitPrice(missingTwap1, 200n);

    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'open-position-with-assets',
        [
          Cl.uint(1),
          Cl.int(-1),
          Cl.int(1),
          Cl.uint(1),
          missingTwap0,
          missingTwap1,
          oracle(),
          Cl.uint(100),
        ],
        wallet1,
      ).result,
    ).toEqual(error(6001));

    const boundary0 = token('lm-twap-boundary-token-0');
    const boundary1 = token('lm-twap-boundary-token-1');
    seedValidatedPrices([
      { asset: boundary0, firstSpot: 105n, secondSpot: 105n, twapPrice: 100n },
      { asset: boundary1, firstSpot: 200n, secondSpot: 200n, twapPrice: 200n },
    ]);

    const opened = openPositionWithValidatedAssets(
      wallet1,
      [Cl.uint(1), Cl.int(-1), Cl.int(1), Cl.uint(1), boundary0, boundary1, oracle(), Cl.uint(100)],
      boundary0,
      boundary1,
      100n,
      200n,
    );
    const id = positionId(opened);
    expect(opened.result).toEqual(Cl.ok(Cl.uint(id)));

    const aboveBoundary = token('lm-twap-over-boundary-token');
    seedValidatedPrice(aboveBoundary, 106n, 106n, 100n);
    const aboveOpening = openPositionWithValidatedAssets(
      wallet1,
      [
        Cl.uint(2),
        Cl.int(-1),
        Cl.int(1),
        Cl.uint(1),
        aboveBoundary,
        boundary1,
        oracle(),
        Cl.uint(100),
      ],
      aboveBoundary,
      boundary1,
      100n,
      200n,
    );
    expect(aboveOpening.result).toEqual(error(7006));

    updatePrice(boundary0, 106n);
    expect(
      simnet.callReadOnlyFn(
        'liquidity-manager',
        'get-il-protection-status',
        [Cl.uint(id), oracle()],
        deployer,
      ).result,
    ).toEqual(error(6001));
  });

  it('enforces owner-or-position-owner close and risk-limit updates', () => {
    const position = openPosition(wallet1, 5n, -5, 5, 777n);
    const id = positionId(position);

    expect(
      simnet.callPublicFn('liquidity-manager', 'update-risk-limit', [Cl.uint(id), Cl.uint(10001)], wallet1).result,
    ).toEqual(error(2009));
    expect(
      simnet.callPublicFn('liquidity-manager', 'update-risk-limit', [Cl.uint(id), Cl.uint(250)], wallet2).result,
    ).toEqual(error(1000));
    expect(
      simnet.callPublicFn('liquidity-manager', 'update-risk-limit', [Cl.uint(id), Cl.uint(250)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callPublicFn('liquidity-manager', 'close-position', [Cl.uint(id)], wallet2).result,
    ).toEqual(error(1000));
    expect(
      simnet.callPublicFn('liquidity-manager', 'close-position', [Cl.uint(id)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn('liquidity-manager', 'close-position', [Cl.uint(id)], deployer).result,
    ).toEqual(error(2012));

    const stored = simnet.callReadOnlyFn('liquidity-manager', 'get-position', [Cl.uint(id)], deployer);
    const printed = pretty(stored.result);
    expect(printed).toContain('active: false');
    expect(printed).toContain('requested-liquidity: u777');
    expect(printed).toContain('accounted-liquidity: u0');
  });

  it('invalidates an active rebalance intent when its position closes', () => {
    const position = openPosition(wallet1, 6n, -10, 10, 600n);
    const id = positionId(position);
    expect(position.result).toEqual(Cl.ok(Cl.uint(id)));

    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'request-rebalance',
        [Cl.uint(id), Cl.int(-5), Cl.int(5), Cl.uint(800)],
        wallet1,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      pretty(simnet.callReadOnlyFn('liquidity-manager', 'get-rebalance', [Cl.uint(id)], deployer).result),
    ).toContain('active: true');

    expect(
      simnet.callPublicFn('liquidity-manager', 'close-position', [Cl.uint(id)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const closedPlan = pretty(
      simnet.callReadOnlyFn('liquidity-manager', 'get-rebalance-plan', [Cl.uint(id)], deployer).result,
    );
    expect(closedPlan).toContain('active: false');
    expect(closedPlan).toMatch(/cancelled-at: \(some u\d+\)/);
    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'request-rebalance',
        [Cl.uint(id), Cl.int(-4), Cl.int(4), Cl.uint(700)],
        wallet1,
      ).result,
    ).toEqual(error(2012));
  });

  it('reports price-movement proxy status with strict threshold semantics and overflow guard', () => {
    const risk0 = token('lm-risk-token-0');
    const risk1 = token('lm-risk-token-1');
    seedValidatedPrices([
      { asset: risk0, firstSpot: 100n, secondSpot: 100n, twapPrice: 100n },
      { asset: risk1, firstSpot: 200n, secondSpot: 200n, twapPrice: 200n },
    ]);

    const opened = openPositionWithValidatedAssets(
      wallet1,
      [Cl.uint(1), Cl.int(-10), Cl.int(10), Cl.uint(1000), risk0, risk1, oracle(), Cl.uint(100)],
      risk0,
      risk1,
      100n,
      200n,
    );
    const id = positionId(opened);
    expect(opened.result).toEqual(Cl.ok(Cl.uint(id)));

    seedValidatedPrices([
      { asset: risk0, firstSpot: 101n, secondSpot: 101n, twapPrice: 101n },
      { asset: risk1, firstSpot: 202n, secondSpot: 202n, twapPrice: 202n },
    ]);
    let status = simnet.callReadOnlyFn(
      'liquidity-manager',
      'get-il-protection-status',
      [Cl.uint(id), oracle()],
      deployer,
    );
    expect(pretty(status.result)).toContain('protection-type: "price-movement-proxy"');
    expect(pretty(status.result)).toContain('movement-bps-0: u100');
    expect(pretty(status.result)).toContain('movement-bps-1: u100');
    expect(pretty(status.result)).toContain('triggered: false');

    expect(
      simnet.callPublicFn('liquidity-manager', 'update-risk-limit', [Cl.uint(id), Cl.uint(99)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    seedValidatedPrices([
      { asset: risk0, firstSpot: 101n, secondSpot: 101n, twapPrice: 101n },
      { asset: risk1, firstSpot: 202n, secondSpot: 202n, twapPrice: 202n },
    ]);
    status = simnet.callReadOnlyFn('liquidity-manager', 'get-il-protection-status', [Cl.uint(id), oracle()], deployer);
    expect(pretty(status.result)).toContain('triggered: true');

    expect(
      simnet.callPublicFn('liquidity-manager', 'update-risk-limit', [Cl.uint(id), Cl.uint(101)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    seedValidatedPrices([
      { asset: risk0, firstSpot: 101n, secondSpot: 101n, twapPrice: 101n },
      { asset: risk1, firstSpot: 202n, secondSpot: 202n, twapPrice: 202n },
    ]);
    status = simnet.callReadOnlyFn('liquidity-manager', 'get-il-protection-status', [Cl.uint(id), oracle()], deployer);
    expect(pretty(status.result)).toContain('triggered: false');

    const overflow0 = token('lm-overflow-token-0');
    const overflow1 = token('lm-overflow-token-1');
    seedValidatedPrices([
      { asset: overflow0, firstSpot: 1n, secondSpot: 1n, twapPrice: 1n },
      { asset: overflow1, firstSpot: 1n, secondSpot: 1n, twapPrice: 1n },
    ]);
    const overflowPosition = openPositionWithValidatedAssets(
      wallet1,
      [Cl.uint(2), Cl.int(-2), Cl.int(2), Cl.uint(1), overflow0, overflow1, oracle(), Cl.uint(100)],
      overflow0,
      overflow1,
      1n,
      1n,
    );
    const overflowId = positionId(overflowPosition);
    expect(overflowPosition.result).toEqual(Cl.ok(Cl.uint(overflowId)));

    const overflowPrice = MAX_UINT / 2n;
    seedValidatedPricesWithAdminOverride([
      { asset: overflow0, price: overflowPrice },
      { asset: overflow1, price: 1n },
    ]);

    expect(
      simnet.callReadOnlyFn(
        'liquidity-manager',
        'get-il-protection-status',
        [Cl.uint(overflowId), oracle()],
        deployer,
      ).result,
    ).toEqual(error(2016));
  });

  it('rejects exact quotient-boundary fractional overflow through the public risk path', () => {
    const reference = 4999n;
    const remainder = (MAX_BPS_REMAINDER * reference) / BASIS_POINTS + 1n;
    const difference = MAX_BPS_QUOTIENT * reference + remainder;
    const currentPrice = reference + difference;

    expect(difference / reference).toBe(MAX_BPS_QUOTIENT);
    expect(difference % reference).toBe(remainder);
    expect((remainder * BASIS_POINTS) / reference).toBeGreaterThan(MAX_BPS_REMAINDER);
    expect(currentPrice * 2n).toBeLessThanOrEqual(MAX_UINT);

    const boundary0 = token('lm-quotient-boundary-token-0');
    const boundary1 = token('lm-quotient-boundary-token-1');
    seedValidatedPrices([
      { asset: boundary0, firstSpot: reference, secondSpot: reference, twapPrice: reference },
      { asset: boundary1, firstSpot: 1n, secondSpot: 1n, twapPrice: 1n },
    ]);

    const opened = openPositionWithValidatedAssets(
      wallet1,
      [Cl.uint(3), Cl.int(-2), Cl.int(2), Cl.uint(1), boundary0, boundary1, oracle(), Cl.uint(100)],
      boundary0,
      boundary1,
      reference,
      1n,
    );
    const id = positionId(opened);
    expect(opened.result).toEqual(Cl.ok(Cl.uint(id)));

    seedValidatedPricesWithAdminOverride([
      { asset: boundary0, price: currentPrice },
      { asset: boundary1, price: 1n },
    ]);

    expect(
      simnet.callReadOnlyFn(
        'liquidity-manager',
        'get-il-protection-status',
        [Cl.uint(id), oracle()],
        deployer,
      ).result,
    ).toEqual(error(2016));
  });

  it('supports position-owner rebalance intents without mutating position liquidity', () => {
    const opened = openPosition(wallet1, 8n, -10, 10, 1234n);
    const id = positionId(opened);
    expect(opened.result).toEqual(Cl.ok(Cl.uint(id)));
    const before = pretty(simnet.callReadOnlyFn('liquidity-manager', 'get-position', [Cl.uint(id)], deployer).result);

    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'request-rebalance',
        [Cl.uint(id), Cl.int(-20), Cl.int(20), Cl.uint(2000)],
        wallet2,
      ).result,
    ).toEqual(error(1000));
    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'request-rebalance',
        [Cl.uint(id), Cl.int(-20), Cl.int(20), Cl.uint(2000)],
        wallet1,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'request-rebalance',
        [Cl.uint(id), Cl.int(-20), Cl.int(20), Cl.uint(2000)],
        wallet1,
      ).result,
    ).toEqual(error(2014));
    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'request-rebalance',
        [Cl.uint(id), Cl.int(0), Cl.int(0), Cl.uint(2000)],
        wallet1,
      ).result,
    ).toEqual(error(2006));
    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'request-rebalance',
        [Cl.uint(id), Cl.int(-20), Cl.int(20), Cl.uint(0)],
        wallet1,
      ).result,
    ).toEqual(error(2005));

    const plan = simnet.callReadOnlyFn('liquidity-manager', 'get-rebalance', [Cl.uint(id)], deployer);
    expect(pretty(plan.result)).toContain('target-liquidity: u2000');
    expect(pretty(plan.result)).toContain('active: true');

    const afterRequest = pretty(
      simnet.callReadOnlyFn('liquidity-manager', 'get-position', [Cl.uint(id)], deployer).result,
    );
    expect(afterRequest).toBe(before);

    expect(
      simnet.callPublicFn('liquidity-manager', 'cancel-rebalance', [Cl.uint(id)], wallet2).result,
    ).toEqual(error(1000));
    expect(
      simnet.callPublicFn('liquidity-manager', 'cancel-rebalance', [Cl.uint(id)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      pretty(simnet.callReadOnlyFn('liquidity-manager', 'get-rebalance', [Cl.uint(id)], deployer).result),
    ).toContain('active: false');

    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'request-rebalance',
        [Cl.uint(id), Cl.int(-5), Cl.int(5), Cl.uint(1500)],
        wallet1,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const afterCancel = pretty(
      simnet.callReadOnlyFn('liquidity-manager', 'get-position', [Cl.uint(id)], deployer).result,
    );
    expect(afterCancel).toBe(before);
  });

  it('gives inclusive caller-observed tick advice and rejects mismatched oracle status calls', () => {
    const opened = openPosition(wallet1, 9n, -10, 10, 1234n);
    const id = positionId(opened);
    expect(opened.result).toEqual(Cl.ok(Cl.uint(id)));
    for (const [observed, inRange, shouldRebalance] of [
      [-11, false, true],
      [-10, true, false],
      [0, true, false],
      [10, true, false],
      [11, false, true],
    ] as const) {
      const advice = simnet.callReadOnlyFn(
        'liquidity-manager',
        'get-rebalance-advice',
        [Cl.uint(id), Cl.int(observed)],
        deployer,
      );
      expect(pretty(advice.result)).toContain(`in-range: ${inRange}`);
      expect(pretty(advice.result)).toContain(`should-rebalance: ${shouldRebalance}`);
      expect(pretty(advice.result)).toContain('pool-current-tick-available: false');
      expect(pretty(advice.result)).toContain('observation-source: "caller-observed-advisory"');
    }

    expect(
      simnet.callReadOnlyFn(
        'liquidity-manager',
        'get-il-protection-status',
        [Cl.uint(id), Cl.contractPrincipal(deployer, 'chainlink-adapter')],
        deployer,
      ).result,
    ).toEqual(error(2008));
  });
});
