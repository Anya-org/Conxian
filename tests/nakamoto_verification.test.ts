import { describe, it, expect, beforeEach } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Nakamoto Architecture Verification', () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('Nakamoto Block Utils: verifies tenure info', () => {
    const result = simnet.callReadOnlyFn('block-utils', 'get-tenure-info', [], deployer);
    expect(result.result).toBeDefined();
  });
});
