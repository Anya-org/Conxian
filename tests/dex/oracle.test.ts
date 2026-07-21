import { beforeAll, describe, expect, it } from 'vitest';
import { tx } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const BASIS_POINTS = 10000n;
const MAX_UINT = (2n ** 128n) - 1n;
const MAX_BPS_QUOTIENT = MAX_UINT / BASIS_POINTS;
const MAX_BPS_REMAINDER = MAX_UINT % BASIS_POINTS;

describe('DEX oracle facade', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;

  const error = (code: number | bigint) => Cl.error(Cl.uint(code));

  const asset = (name: string) => Cl.contractPrincipal(deployer, name);

  function seedAggregatedPrice(
    token: ReturnType<typeof asset>,
    first: bigint,
    second: bigint,
  ) {
    const firstSubmission = simnet.callPublicFn(
      'oracle-aggregator',
      'submit-price',
      [token, Cl.uint(first)],
      wallet1,
    );
    const secondSubmission = simnet.callPublicFn(
      'oracle-aggregator',
      'submit-price',
      [token, Cl.uint(second)],
      wallet2,
    );

    expect(firstSubmission.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(secondSubmission.result).toEqual(Cl.ok(Cl.bool(true)));
  }

  function seedTwap(token: ReturnType<typeof asset>, start: bigint, end: bigint) {
    const startObservation = simnet.callPublicFn(
      'twap-oracle',
      'update-price-observation',
      [token, Cl.uint(start)],
      deployer,
    );
    expect(startObservation.result).toEqual(Cl.ok(Cl.bool(true)));

    simnet.mineEmptyBlocks(1);

    const endObservation = simnet.callPublicFn(
      'twap-oracle',
      'update-price-observation',
      [token, Cl.uint(end)],
      deployer,
    );
    expect(endObservation.result).toEqual(Cl.ok(Cl.bool(true)));
  }

  // The TWAP contract indexes observations by exact burn height. The start
  // observation is written one block before an empty block and the end
  // observation, so a two-block window is deterministic in simnet.
  function seedTwapAndAggregatedPrice(
    token: ReturnType<typeof asset>,
    firstSpot: bigint,
    secondSpot: bigint,
    twapPrice: bigint,
  ) {
    const startObservation = simnet.callPublicFn(
      'twap-oracle',
      'update-price-observation',
      [token, Cl.uint(twapPrice)],
      deployer,
    );
    expect(startObservation.result).toEqual(Cl.ok(Cl.bool(true)));

    simnet.mineEmptyBlocks(1);

    const results = simnet.mineBlock([
      tx.callPublicFn(
        'oracle-aggregator',
        'submit-price',
        [token, Cl.uint(firstSpot)],
        wallet1,
      ),
      tx.callPublicFn(
        'oracle-aggregator',
        'submit-price',
        [token, Cl.uint(secondSpot)],
        wallet2,
      ),
      tx.callPublicFn(
        'twap-oracle',
        'update-price-observation',
        [token, Cl.uint(twapPrice)],
        deployer,
      ),
    ]);

    expect(results.map((result) => result.result)).toEqual([
      Cl.ok(Cl.bool(true)),
      Cl.ok(Cl.bool(true)),
      Cl.ok(Cl.bool(true)),
    ]);
  }

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;

    expect(
      simnet.callPublicFn(
        'oracle-aggregator',
        'set-source-authorized',
        [Cl.standardPrincipal(wallet1), Cl.bool(true)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(
        'oracle-aggregator',
        'set-source-authorized',
        [Cl.standardPrincipal(wallet2), Cl.bool(true)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(
        'twap-oracle',
        'set-twap-window',
        [Cl.uint(2)],
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
  });

  it('rejects a zero TWAP window while accepting the one-block minimum', () => {
    expect(simnet.callReadOnlyFn('twap-oracle', 'get-twap-window', [], deployer).result).toEqual(
      Cl.uint(2),
    );
    expect(
      simnet.callPublicFn('twap-oracle', 'set-twap-window', [Cl.uint(0)], deployer).result,
    ).toEqual(error(6002));
    expect(simnet.callReadOnlyFn('twap-oracle', 'get-twap-window', [], deployer).result).toEqual(
      Cl.uint(2),
    );
    expect(
      simnet.callPublicFn('twap-oracle', 'set-twap-window', [Cl.uint(1)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn('twap-oracle', 'get-twap-window', [], deployer).result).toEqual(
      Cl.uint(1),
    );
    expect(
      simnet.callPublicFn('twap-oracle', 'set-twap-window', [Cl.uint(2)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('requires matching explicit decimal metadata across canonical sources', () => {
    expect(simnet.callReadOnlyFn('oracle', 'get-price-decimals', [], deployer).result).toEqual(
      Cl.ok(Cl.uint(8)),
    );
    expect(
      simnet.callReadOnlyFn('oracle-aggregator', 'get-price-decimals', [], deployer).result,
    ).toEqual(Cl.some(Cl.uint(8)));
    expect(simnet.callReadOnlyFn('twap-oracle', 'get-price-decimals', [], deployer).result).toEqual(
      Cl.some(Cl.uint(8)),
    );

    expect(
      simnet.callPublicFn('twap-oracle', 'set-price-decimals', [Cl.uint(18)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn('oracle', 'get-price-decimals', [], deployer).result).toEqual(
      error(7008),
    );
    expect(
      simnet.callReadOnlyFn('oracle', 'get-price', [asset('oracle-scale-mismatch-token')], deployer)
        .result,
    ).toEqual(error(7008));

    expect(
      simnet.callPublicFn('twap-oracle', 'set-price-decimals', [Cl.uint(8)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('keeps owner-only legacy metadata isolated from canonical prices', () => {
    const legacyToken = asset('oracle-legacy-token');

    expect(
      simnet.callReadOnlyFn('oracle', 'get-max-twap-deviation-bps', [], deployer).result,
    ).toEqual(Cl.uint(500));

    expect(
      simnet.callPublicFn(
        'oracle',
        'set-price',
        [legacyToken, Cl.uint(777)],
        wallet1,
      ).result,
    ).toEqual(error(1000));
    expect(
      simnet.callPublicFn('oracle', 'set-price', [legacyToken, Cl.uint(0)], deployer).result,
    ).toEqual(error(7001));

    const setLegacy = simnet.callPublicFn(
      'oracle',
      'set-price',
      [legacyToken, Cl.uint(777)],
      deployer,
    );
    expect(setLegacy.result).toEqual(Cl.ok(Cl.bool(true)));
    expect(setLegacy.events.some((event) => event.event === 'print_event')).toBe(true);

    const legacy = simnet.callReadOnlyFn('oracle', 'get-legacy-price', [legacyToken], deployer);
    expect(Cl.prettyPrint(legacy.result)).toMatch(/\(some \{ price: u777, updated-at: u\d+ \}\)/);

    // The manual value must not make a missing aggregate price appear valid.
    expect(simnet.callReadOnlyFn('oracle', 'get-price', [legacyToken], deployer).result).toEqual(
      error(1007),
    );
  });

  it('delegates get-price and public fetch-price to the multi-source aggregator', () => {
    const aggregateToken = asset('oracle-aggregate-token');
    seedAggregatedPrice(aggregateToken, 100n, 110n);

    const legacyOverride = simnet.callPublicFn(
      'oracle',
      'set-price',
      [aggregateToken, Cl.uint(999)],
      deployer,
    );
    expect(legacyOverride.result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callReadOnlyFn('oracle', 'get-price', [aggregateToken], deployer).result).toEqual(
      Cl.ok(Cl.uint(105)),
    );
    expect(simnet.callPublicFn('oracle', 'fetch-price', [aggregateToken], wallet1).result).toEqual(
      Cl.ok(Cl.uint(105)),
    );
    expect(
      simnet.callReadOnlyFn('oracle-aggregator', 'get-price', [aggregateToken], deployer).result,
    ).toEqual(Cl.ok(Cl.uint(105)));
    expect(Cl.prettyPrint(
      simnet.callReadOnlyFn('oracle', 'get-legacy-price', [aggregateToken], deployer).result,
    )).toMatch(/price: u999/);
  });

  it('returns TWAP prices and preserves upstream missing-data failures', () => {
    const missingToken = asset('oracle-missing-twap-token');
    expect(simnet.callReadOnlyFn('oracle', 'get-twap-price', [missingToken], deployer).result).toEqual(
      error(6001),
    );

    const twapToken = asset('oracle-twap-token');
    seedTwap(twapToken, 100n, 110n);

    expect(simnet.callReadOnlyFn('oracle', 'get-twap-price', [twapToken], deployer).result).toEqual(
      Cl.ok(Cl.uint(105)),
    );
  });

  it('accepts the inclusive configured deviation boundary and exposes diagnostics', () => {
    const boundaryToken = asset('oracle-boundary-token');
    expect(
      simnet.callPublicFn(
        'oracle',
        'set-max-twap-deviation-bps',
        [Cl.uint(500)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    seedTwapAndAggregatedPrice(boundaryToken, 105n, 105n, 100n);

    expect(
      simnet.callReadOnlyFn('oracle', 'get-price-diagnostics', [boundaryToken], deployer).result,
    ).toEqual(
      Cl.ok(
        Cl.tuple({
          spot: Cl.uint(105),
          twap: Cl.uint(100),
          'deviation-bps': Cl.uint(500),
        }),
      ),
    );
    expect(
      simnet.callReadOnlyFn('oracle', 'get-validated-price', [boundaryToken], deployer).result,
    ).toEqual(Cl.ok(Cl.uint(105)));
  });

  it('bounds deviation configuration and rejects prices above the boundary', () => {
    expect(
      simnet.callPublicFn(
        'oracle',
        'set-max-twap-deviation-bps',
        [Cl.uint(10001)],
        deployer,
      ).result,
    ).toEqual(error(7002));
    expect(
      simnet.callPublicFn(
        'oracle',
        'set-max-twap-deviation-bps',
        [Cl.uint(500)],
        wallet1,
      ).result,
    ).toEqual(error(1000));

    expect(
      simnet.callPublicFn(
        'oracle',
        'set-max-twap-deviation-bps',
        [Cl.uint(10000)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callReadOnlyFn('oracle', 'get-max-twap-deviation-bps', [], deployer).result,
    ).toEqual(Cl.uint(10000));
    expect(
      simnet.callPublicFn(
        'oracle',
        'set-max-twap-deviation-bps',
        [Cl.uint(0)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callReadOnlyFn('oracle', 'get-max-twap-deviation-bps', [], deployer).result,
    ).toEqual(Cl.uint(0));
    expect(
      simnet.callPublicFn(
        'oracle',
        'set-max-twap-deviation-bps',
        [Cl.uint(500)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    const overBoundaryToken = asset('oracle-over-boundary-token');
    seedTwapAndAggregatedPrice(overBoundaryToken, 106n, 106n, 100n);

    expect(
      simnet.callReadOnlyFn('oracle', 'get-price-diagnostics', [overBoundaryToken], deployer).result,
    ).toEqual(
      Cl.ok(
        Cl.tuple({
          spot: Cl.uint(106),
          twap: Cl.uint(100),
          'deviation-bps': Cl.uint(600),
        }),
      ),
    );
    expect(
      simnet.callReadOnlyFn('oracle', 'get-validated-price', [overBoundaryToken], deployer).result,
    ).toEqual(error(7006));
  });

  it('fails closed on zero values and arithmetic overflow', () => {
    const zeroAggregateToken = asset('oracle-zero-aggregate-token');
    seedAggregatedPrice(zeroAggregateToken, 0n, 0n);
    expect(
      simnet.callReadOnlyFn('oracle', 'get-price', [zeroAggregateToken], deployer).result,
    ).toEqual(error(7001));
    expect(
      simnet.callPublicFn('oracle', 'fetch-price', [zeroAggregateToken], wallet1).result,
    ).toEqual(error(7001));

    const zeroSpotToken = asset('oracle-zero-spot-token');
    seedTwapAndAggregatedPrice(zeroSpotToken, 0n, 0n, 100n);
    expect(
      simnet.callReadOnlyFn('oracle', 'get-price-diagnostics', [zeroSpotToken], deployer).result,
    ).toEqual(error(7003));

    const zeroTwapToken = asset('oracle-zero-twap-token');
    seedTwapAndAggregatedPrice(zeroTwapToken, 100n, 100n, 0n);
    expect(
      simnet.callReadOnlyFn('oracle', 'get-twap-price', [zeroTwapToken], deployer).result,
    ).toEqual(error(7001));
    expect(
      simnet.callReadOnlyFn('oracle', 'get-price-diagnostics', [zeroTwapToken], deployer).result,
    ).toEqual(error(7004));

    const overflowToken = asset('oracle-overflow-token');
    seedTwapAndAggregatedPrice(overflowToken, MAX_UINT, 0n, 1n);
    expect(
      simnet.callReadOnlyFn('oracle', 'get-price-diagnostics', [overflowToken], deployer).result,
    ).toEqual(error(7005));
    expect(
      simnet.callReadOnlyFn('oracle', 'get-validated-price', [overflowToken], deployer).result,
    ).toEqual(error(7005));
  });

  it('rejects exact quotient-boundary fractional overflow in diagnostics and validation', () => {
    const reference = 4999n;
    const remainder = (MAX_BPS_REMAINDER * reference) / BASIS_POINTS + 1n;
    const difference = MAX_BPS_QUOTIENT * reference + remainder;
    const spot = reference + difference;

    expect(difference / reference).toBe(MAX_BPS_QUOTIENT);
    expect(difference % reference).toBe(remainder);
    expect((remainder * BASIS_POINTS) / reference).toBeGreaterThan(MAX_BPS_REMAINDER);
    expect(spot * 2n).toBeLessThanOrEqual(MAX_UINT);

    const boundaryToken = asset('oracle-quotient-boundary-fraction-token');
    seedTwapAndAggregatedPrice(boundaryToken, spot, spot, reference);

    expect(
      simnet.callReadOnlyFn('oracle', 'get-price-diagnostics', [boundaryToken], deployer).result,
    ).toEqual(error(7005));
    expect(
      simnet.callReadOnlyFn('oracle', 'get-validated-price', [boundaryToken], deployer).result,
    ).toEqual(error(7005));
  });

  it('preserves owner transfer compatibility', () => {
    const newOwner = simnet.getAccounts().get('wallet_3')!;

    expect(
      simnet.callPublicFn('oracle', 'transfer-ownership', [Cl.standardPrincipal(newOwner)], wallet1).result,
    ).toEqual(error(1000));
    expect(
      simnet.callPublicFn('oracle', 'transfer-ownership', [Cl.standardPrincipal(newOwner)], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn('oracle', 'get-contract-owner', [], deployer).result).toEqual(
      Cl.ok(Cl.standardPrincipal(newOwner)),
    );
    expect(
      simnet.callPublicFn(
        'oracle',
        'set-max-twap-deviation-bps',
        [Cl.uint(500)],
        deployer,
      ).result,
    ).toEqual(error(1000));
    expect(
      simnet.callPublicFn(
        'oracle',
        'transfer-ownership',
        [Cl.standardPrincipal(deployer)],
        newOwner,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn('oracle', 'get-contract-owner', [], deployer).result).toEqual(
      Cl.ok(Cl.standardPrincipal(deployer)),
    );
  });
});
