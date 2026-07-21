import { describe, expect, it, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

const MAX_UINT = (2n ** 128n) - 1n;

describe('predictive-scaling-system policy helpers', () => {
  let deployer: string;

  beforeAll(() => {
    deployer = simnet.getAccounts().get('deployer')!;
  });

  it('preserves the legacy scaling factor and fails closed on zero/overflow', () => {
    const compatible = simnet.callReadOnlyFn(
      'predictive-scaling-system',
      'get-scaling-factor',
      [Cl.uint(125), Cl.uint(100)],
      deployer,
    );
    expect(compatible.result).toEqual(Cl.ok(Cl.uint(125)));

    const zeroBaseline = simnet.callReadOnlyFn(
      'predictive-scaling-system',
      'get-scaling-factor',
      [Cl.uint(100), Cl.uint(0)],
      deployer,
    );
    expect(zeroBaseline.result).toEqual(Cl.error(Cl.uint(1001)));

    const overflow = simnet.callReadOnlyFn(
      'predictive-scaling-system',
      'get-scaling-factor',
      [Cl.uint(MAX_UINT), Cl.uint(1)],
      deployer,
    );
    expect(overflow.result).toEqual(Cl.error(Cl.uint(1004)));
  });

  it('applies volatility scaling and clamps fees to the requested bounds', () => {
    const clampedToMinimum = simnet.callReadOnlyFn(
      'predictive-scaling-system',
      'get-volatility-adjusted-fee-bps',
      [Cl.uint(100), Cl.uint(5000), Cl.uint(200), Cl.uint(500)],
      deployer,
    );
    expect(clampedToMinimum.result).toEqual(Cl.ok(Cl.uint(200)));

    const clampedToMaximum = simnet.callReadOnlyFn(
      'predictive-scaling-system',
      'get-volatility-adjusted-fee-bps',
      [Cl.uint(900), Cl.uint(5000), Cl.uint(200), Cl.uint(1000)],
      deployer,
    );
    expect(clampedToMaximum.result).toEqual(Cl.ok(Cl.uint(1000)));

    const cappedVolatility = simnet.callReadOnlyFn(
      'predictive-scaling-system',
      'get-volatility-adjusted-fee-bps',
      [Cl.uint(100), Cl.uint(20000), Cl.uint(0), Cl.uint(1000)],
      deployer,
    );
    expect(cappedVolatility.result).toEqual(Cl.ok(Cl.uint(200)));

    const invalidBounds = simnet.callReadOnlyFn(
      'predictive-scaling-system',
      'get-volatility-adjusted-fee-bps',
      [Cl.uint(100), Cl.uint(0), Cl.uint(501), Cl.uint(500)],
      deployer,
    );
    expect(invalidBounds.result).toEqual(Cl.error(Cl.uint(1002)));
  });

  it('adjusts liquidity by bounded target/observed depth and handles zero/overflow', () => {
    const reduced = simnet.callReadOnlyFn(
      'predictive-scaling-system',
      'get-depth-adjusted-liquidity',
      [Cl.uint(1000), Cl.uint(8000), Cl.uint(10000)],
      deployer,
    );
    expect(reduced.result).toEqual(Cl.ok(Cl.uint(800)));

    const increased = simnet.callReadOnlyFn(
      'predictive-scaling-system',
      'get-depth-adjusted-liquidity',
      [Cl.uint(1000), Cl.uint(10000), Cl.uint(5000)],
      deployer,
    );
    expect(increased.result).toEqual(Cl.ok(Cl.uint(2000)));

    const zeroTarget = simnet.callReadOnlyFn(
      'predictive-scaling-system',
      'get-depth-adjusted-liquidity',
      [Cl.uint(1000), Cl.uint(0), Cl.uint(10000)],
      deployer,
    );
    expect(zeroTarget.result).toEqual(Cl.ok(Cl.uint(0)));

    const zeroObservedDepth = simnet.callReadOnlyFn(
      'predictive-scaling-system',
      'get-depth-adjusted-liquidity',
      [Cl.uint(1000), Cl.uint(1000), Cl.uint(0)],
      deployer,
    );
    expect(zeroObservedDepth.result).toEqual(Cl.error(Cl.uint(1003)));

    const overflow = simnet.callReadOnlyFn(
      'predictive-scaling-system',
      'get-depth-adjusted-liquidity',
      [Cl.uint(MAX_UINT), Cl.uint(10000), Cl.uint(1)],
      deployer,
    );
    expect(overflow.result).toEqual(Cl.error(Cl.uint(1004)));
  });
});
