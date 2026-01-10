import { describe, it, expect, beforeEach } from 'vitest';
import { Simnet, initSimnet } from '@stacks/clarinet-sdk';

describe('Single Contract Compilation Test', () => {
  let simnet: Simnet;

  beforeEach(async () => {
    simnet = await initSimnet();
  });

  it('should successfully deploy the ownable contract', () => {
    const contractSource = simnet.getContractSource('ownable');
    expect(contractSource).toBeDefined();
  });
});
