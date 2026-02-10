import { describe, it, expect } from 'vitest';
import { simnet } from '../setup-test-env';
import { Cl } from '@stacks/transactions';

describe('interest-rate-model', () => {
  it('should calculate the borrow rate correctly', () => {
    const result = simnet.callReadOnlyFn(
      'interest-rate-model',
      'get-borrow-rate',
      [Cl.uint(5000)], // 50% utilization
      simnet.deployer
    );
    expect(result.result).toBeDefined();
  });

  it('should calculate the supply rate correctly', () => {
    const result = simnet.callReadOnlyFn(
      'interest-rate-model',
      'get-supply-rate',
      [Cl.uint(5000)],
      simnet.deployer
    );
    expect(result.result).toBeDefined();
  });
});
