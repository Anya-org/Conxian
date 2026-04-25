import { describe, expect, it, beforeAll } from 'vitest';
import { simnet } from '../setup-test-env';
import { Cl } from '@stacks/transactions';

let deployer: string;

describe('math-lib-concentrated', () => {
  beforeAll(async () => {

    deployer = simnet.getAccounts().get('deployer')!;
  });

  it('should calculate the sqrt ratio correctly', () => {
    const { result } = simnet.callReadOnlyFn(
      'math-lib-concentrated',
      'get-sqrt-ratio-at-tick',
      [Cl.int(1)],
      deployer,
    );
    expect(result).toEqual(Cl.uint(1000049998750));
  });
});
