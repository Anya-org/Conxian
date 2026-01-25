import { describe, expect, it } from 'vitest';
import { Cl, cvToValue } from '@stacks/transactions';

describe('math-lib-concentrated', () => {
  it('should calculate the sqrt ratio correctly', () => {
    const { result } = simnet.callReadOnlyFn(
      'math-lib-concentrated',
      'get-sqrt-ratio-at-tick',
      [Cl.int(1)],
      simnet.deployer,
    );
    expect(result).toBeOk(Cl.uint(1000049998750));
  });
});
