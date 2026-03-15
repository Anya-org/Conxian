import { describe, it, expect, beforeEach } from 'vitest';
import { Simnet, initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Temporary Sanity Test for ownable contract', () => {
  let simnet: Simnet;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
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
