import { describe, it, expect, beforeEach } from 'vitest';
import { Simnet, initSimnet, Clarinet } from '@stacks/clarinet-sdk';

describe('Temporary Sanity Test for ownable contract', () => {
  let simnet: Simnet;
  // Hardcoding the deployer address to bypass issues with simnet.getAccounts()
  const deployer = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";

  beforeEach(async () => {
    simnet = await initSimnet();
  });

  it('should successfully deploy the ownable contract', async () => {
    const deployment = await simnet.deployContract(
      'ownable',
      'contracts/base/ownable.clar',
      null,
      deployer
    );
    // A successful deployment will have a result object with a `success` property that is true
    expect(deployment.result.success).toBe(true);
  });
});
