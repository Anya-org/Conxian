import { describe, expect, it, beforeAll } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;

describe('math-lib-concentrated', () => {
  beforeAll(async () => {
    simnet = await initSimnet();
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
