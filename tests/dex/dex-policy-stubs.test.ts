import { describe, expect, it, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const MAX_UINT = (2n ** 128n) - 1n;

describe('DEX policy helpers', () => {
  let deployer: string;

  beforeAll(() => {
    deployer = simnet.getAccounts().get('deployer')!;
  });

  describe('protocol-invariant-monitor', () => {
    it('preserves the solvency helper and handles equality', () => {
      const solvent = simnet.callReadOnlyFn(
        'protocol-invariant-monitor',
        'check-invariants',
        [Cl.uint(100), Cl.uint(100)],
        deployer,
      );
      expect(solvent.result).toEqual(Cl.ok(Cl.bool(true)));

      const insolvent = simnet.callReadOnlyFn(
        'protocol-invariant-monitor',
        'check-invariants',
        [Cl.uint(99), Cl.uint(100)],
        deployer,
      );
      expect(insolvent.result).toEqual(Cl.ok(Cl.bool(false)));
    });

    it('treats zero reserves as a zero product and rejects mismatches', () => {
      const emptyPool = simnet.callReadOnlyFn(
        'protocol-invariant-monitor',
        'check-constant-product',
        [Cl.uint(0), Cl.uint(500), Cl.uint(0), Cl.uint(1000)],
        deployer,
      );
      expect(emptyPool.result).toEqual(Cl.ok(Cl.bool(true)));

      const invalidEmptyPool = simnet.callReadOnlyFn(
        'protocol-invariant-monitor',
        'check-constant-product',
        [Cl.uint(0), Cl.uint(500), Cl.uint(1), Cl.uint(1000)],
        deployer,
      );
      expect(invalidEmptyPool.result).toEqual(Cl.ok(Cl.bool(false)));
    });

    it('accepts deviations at the tolerance boundary and rejects those above it', () => {
      const exact = simnet.callReadOnlyFn(
        'protocol-invariant-monitor',
        'check-constant-product',
        [Cl.uint(100), Cl.uint(100), Cl.uint(10000), Cl.uint(1000)],
        deployer,
      );
      expect(exact.result).toEqual(Cl.ok(Cl.bool(true)));

      const upperBoundary = simnet.callReadOnlyFn(
        'protocol-invariant-monitor',
        'check-constant-product',
        [Cl.uint(100), Cl.uint(110), Cl.uint(10000), Cl.uint(1000)],
        deployer,
      );
      expect(upperBoundary.result).toEqual(Cl.ok(Cl.bool(true)));

      const aboveUpperBoundary = simnet.callReadOnlyFn(
        'protocol-invariant-monitor',
        'check-constant-product',
        [Cl.uint(100), Cl.uint(111), Cl.uint(10000), Cl.uint(1000)],
        deployer,
      );
      expect(aboveUpperBoundary.result).toEqual(Cl.ok(Cl.bool(false)));

      const lowerBoundary = simnet.callReadOnlyFn(
        'protocol-invariant-monitor',
        'check-constant-product',
        [Cl.uint(100), Cl.uint(90), Cl.uint(10000), Cl.uint(1000)],
        deployer,
      );
      expect(lowerBoundary.result).toEqual(Cl.ok(Cl.bool(true)));

      const belowLowerBoundary = simnet.callReadOnlyFn(
        'protocol-invariant-monitor',
        'check-constant-product',
        [Cl.uint(100), Cl.uint(89), Cl.uint(10000), Cl.uint(1000)],
        deployer,
      );
      expect(belowLowerBoundary.result).toEqual(Cl.ok(Cl.bool(false)));
    });

    it('rejects invalid tolerance and multiplication overflow', () => {
      const invalidTolerance = simnet.callReadOnlyFn(
        'protocol-invariant-monitor',
        'check-constant-product',
        [Cl.uint(100), Cl.uint(100), Cl.uint(10000), Cl.uint(10001)],
        deployer,
      );
      expect(invalidTolerance.result).toEqual(Cl.error(Cl.uint(2001)));

      const overflow = simnet.callReadOnlyFn(
        'protocol-invariant-monitor',
        'check-constant-product',
        [Cl.uint(MAX_UINT), Cl.uint(2), Cl.uint(0), Cl.uint(0)],
        deployer,
      );
      expect(overflow.result).toEqual(Cl.error(Cl.uint(2002)));
    });
  });

  describe('rebalancing-rules', () => {
    it('uses strict threshold semantics at below, equal, and above boundaries', () => {
      const below = simnet.callReadOnlyFn(
        'rebalancing-rules',
        'should-rebalance',
        [Cl.uint(105), Cl.uint(100), Cl.uint(10)],
        deployer,
      );
      expect(below.result).toEqual(Cl.ok(Cl.bool(false)));

      const equal = simnet.callReadOnlyFn(
        'rebalancing-rules',
        'should-rebalance',
        [Cl.uint(110), Cl.uint(100), Cl.uint(10)],
        deployer,
      );
      expect(equal.result).toEqual(Cl.ok(Cl.bool(false)));

      const above = simnet.callReadOnlyFn(
        'rebalancing-rules',
        'should-rebalance',
        [Cl.uint(111), Cl.uint(100), Cl.uint(10)],
        deployer,
      );
      expect(above.result).toEqual(Cl.ok(Cl.bool(true)));
    });

    it('returns absolute deltas and signed directions', () => {
      const positiveDelta = simnet.callReadOnlyFn(
        'rebalancing-rules',
        'get-rebalance-delta',
        [Cl.uint(100), Cl.uint(125)],
        deployer,
      );
      expect(positiveDelta.result).toEqual(Cl.ok(Cl.uint(25)));

      const negativeDelta = simnet.callReadOnlyFn(
        'rebalancing-rules',
        'get-rebalance-delta',
        [Cl.uint(125), Cl.uint(100)],
        deployer,
      );
      expect(negativeDelta.result).toEqual(Cl.ok(Cl.uint(25)));

      const positiveDirection = simnet.callReadOnlyFn(
        'rebalancing-rules',
        'get-rebalance-direction',
        [Cl.uint(100), Cl.uint(125)],
        deployer,
      );
      expect(positiveDirection.result).toEqual(Cl.ok(Cl.int(1)));

      const negativeDirection = simnet.callReadOnlyFn(
        'rebalancing-rules',
        'get-rebalance-direction',
        [Cl.uint(125), Cl.uint(100)],
        deployer,
      );
      expect(negativeDirection.result).toEqual(Cl.ok(Cl.int(-1)));

      const balancedDirection = simnet.callReadOnlyFn(
        'rebalancing-rules',
        'get-rebalance-direction',
        [Cl.uint(100), Cl.uint(100)],
        deployer,
      );
      expect(balancedDirection.result).toEqual(Cl.ok(Cl.int(0)));
    });
  });
});
