import { describe, expect, it, beforeAll } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;

describe('math-lib-concentrated', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
  });

  it('should calculate the sqrt ratio correctly', () => {
    const { result } = simnet.callReadOnlyFn(
      'math-lib-concentrated',
      'get-sqrt-ratio-at-tick',
      [Cl.int(1)],
      simnet.deployer,
    );
    expect(result).toEqual(Cl.uint(1000049998750));
  });
});
