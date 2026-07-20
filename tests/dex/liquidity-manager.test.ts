import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initializeSimnet, simnet } from '../setup-test-env';

const MAX_UINT = (2n ** 128n) - 1n;

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
      simnet.callPublicFn('liquidity-manager', 'set-oracle', [oracle()], deployer).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('preserves the open-position signature, allocates IDs from one, and records no custody', () => {
    const first = openPosition(wallet1);
    const second = openPosition(wallet1, 2n, -20, 20, 2000n);

    expect(first.result).toEqual(Cl.ok(Cl.uint(1)));
    expect(second.result).toEqual(Cl.ok(Cl.uint(2)));
    expect(first.events.some((event) => event.event === 'ft_transfer_event')).toBe(false);

    const stored = simnet.callReadOnlyFn(
      'liquidity-manager',
      'get-position',
      [Cl.uint(1)],
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

  it('requires an owner-configured matching oracle and records nonzero entry prices', () => {
    const asset0 = token('lm-entry-token-0');
    const asset1 = token('lm-entry-token-1');
    submitPrice(asset0, 100n);
    submitPrice(asset1, 200n);

    expect(
      simnet.callPublicFn('liquidity-manager', 'set-oracle', [oracle()], wallet1).result,
    ).toEqual(error(1000));
    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'open-position-with-assets',
        [
          Cl.uint(3),
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

    const opened = simnet.callPublicFn(
      'liquidity-manager',
      'open-position-with-assets',
      [Cl.uint(3), Cl.int(-10), Cl.int(10), Cl.uint(500), asset0, asset1, oracle(), Cl.uint(100)],
      wallet1,
    );
    expect(opened.result).toEqual(Cl.ok(Cl.uint(3)));
    expect(opened.events.some((event) => event.event === 'ft_transfer_event')).toBe(false);

    const stored = simnet.callReadOnlyFn(
      'liquidity-manager',
      'get-position',
      [Cl.uint(3)],
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
    submitPrice(valid0, 10n);
    submitPrice(valid1, 20n);

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
    submitPrice(zero0, 0n);
    expect(
      simnet.callPublicFn(
        'liquidity-manager',
        'open-position-with-assets',
        [Cl.uint(4), Cl.int(-1), Cl.int(1), Cl.uint(1), zero0, valid1, oracle(), Cl.uint(100)],
        wallet1,
      ).result,
    ).toEqual(error(2010));
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

  it('reports price-movement proxy status with strict threshold semantics and overflow guard', () => {
    const risk0 = token('lm-risk-token-0');
    const risk1 = token('lm-risk-token-1');
    submitPrice(risk0, 100n);
    submitPrice(risk1, 200n);

    const opened = simnet.callPublicFn(
      'liquidity-manager',
      'open-position-with-assets',
      [Cl.uint(6), Cl.int(-10), Cl.int(10), Cl.uint(1000), risk0, risk1, oracle(), Cl.uint(100)],
      wallet1,
    );
    expect(opened.result).toEqual(Cl.ok(Cl.uint(5)));
    const id = positionId(opened);

    updatePrice(risk0, 101n);
    updatePrice(risk1, 202n);
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
    status = simnet.callReadOnlyFn('liquidity-manager', 'get-il-protection-status', [Cl.uint(id), oracle()], deployer);
    expect(pretty(status.result)).toContain('triggered: true');

    expect(
      simnet.callPublicFn('liquidity-manager', 'update-risk-limit', [Cl.uint(id), Cl.uint(101)], wallet1).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    status = simnet.callReadOnlyFn('liquidity-manager', 'get-il-protection-status', [Cl.uint(id), oracle()], deployer);
    expect(pretty(status.result)).toContain('triggered: false');

    const overflow0 = token('lm-overflow-token-0');
    const overflow1 = token('lm-overflow-token-1');
    submitPrice(overflow0, 1n);
    submitPrice(overflow1, 1n);
    const overflowPosition = simnet.callPublicFn(
      'liquidity-manager',
      'open-position-with-assets',
      [Cl.uint(7), Cl.int(-2), Cl.int(2), Cl.uint(1), overflow0, overflow1, oracle(), Cl.uint(100)],
      wallet1,
    );
    expect(overflowPosition.result).toEqual(Cl.ok(Cl.uint(6)));
    const overflowId = positionId(overflowPosition);

    expect(
      simnet.callPublicFn(
        'oracle-aggregator',
        'set-price',
        [overflow0, Cl.uint(MAX_UINT)],
        deployer,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));
    expect(
      simnet.callPublicFn(
        'oracle-aggregator',
        'submit-price',
        [overflow0, Cl.uint(0)],
        wallet1,
      ).result,
    ).toEqual(Cl.ok(Cl.bool(true)));

    expect(
      simnet.callReadOnlyFn(
        'liquidity-manager',
        'get-il-protection-status',
        [Cl.uint(overflowId), oracle()],
        deployer,
      ).result,
    ).toEqual(error(2016));
  });

  it('supports position-owner rebalance intents without mutating position liquidity', () => {
    const opened = openPosition(wallet1, 8n, -10, 10, 1234n);
    expect(opened.result).toEqual(Cl.ok(Cl.uint(7)));
    const id = positionId(opened);
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
    const id = 7n;
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
        [Cl.uint(5), Cl.contractPrincipal(deployer, 'chainlink-adapter')],
        deployer,
      ).result,
    ).toEqual(error(2008));
  });
});
