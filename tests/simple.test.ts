
import { describe, expect, it, beforeAll } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Simple Test', () => {
  let simnet: any;
  let deployer: string;

  beforeAll(async () => {
    simnet = await initSimnet();
    deployer = simnet.deployer;
  });

  it('should load conxian-access', () => {
    const owner = simnet.callReadOnlyFn(
      'conxian-access',
      'get-contract-owner',
      [],
      deployer
    );
    expect(owner.result).toBeDefined();
  });
});
