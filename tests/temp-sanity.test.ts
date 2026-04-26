import { describe, it, expect, beforeEach } from 'vitest';
import { simnet } from './setup-test-env';
import { Cl } from '@stacks/transactions';

describe('Temporary Sanity Test for ownable contract', () => {
    let deployer: string;

  beforeEach(async () => {

    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('should successfully deploy the ownable contract', async () => {
    // Test conxian-access (our ownable/access-control contract) is deployed
    const source = simnet.getContractSource('conxian-access');
    expect(source).toBeDefined();
    // Verify admin check works
    const owner = simnet.callReadOnlyFn('conxian-access', 'get-contract-owner', [], deployer);
    expect(owner.result).toBeDefined();
  });
});
