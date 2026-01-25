import { describe, expect, it } from 'vitest';
import { Cl, cvToValue } from '@stacks/transactions';

describe('interest-rate-model', () => {
  it('should calculate the borrow rate correctly', () => {
    const { result } = simnet.callReadOnlyFn(
      'interest-rate-model',
      'get-borrow-rate',
      [Cl.uint(800000000000000000)],
      simnet.deployer,
    );
    expect(result).toBeOk(Cl.uint(100000000000000000));
  });

  it('should calculate the supply rate correctly', () => {
    const { result } = simnet.callReadOnlyFn(
      'interest-rate-model',
      'get-supply-rate',
      [Cl.uint(800000000000000000)],
      simnet.deployer,
    );
    expect(result).toBeOk(Cl.uint(80000000000000000));
  });
});
