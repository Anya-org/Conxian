import { describe, it, expect, beforeEach } from 'vitest';
import { simnet } from './setup-test-env';
import { Cl } from '@stacks/transactions';

describe('Nakamoto Architecture Verification', () => {
    let deployer: string;

  beforeEach(async () => {

    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('Nakamoto Block Utils: verifies tenure info', () => {
    const result = simnet.callReadOnlyFn('block-utils', 'get-tenure-info', [], deployer);
    expect(result.result).toBeDefined();
  });
});
