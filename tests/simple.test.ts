import { describe, it, expect, beforeEach } from 'vitest';
import { Simnet, initSimnet } from '@stacks/clarinet-sdk';

describe('Simple Test', () => {
  let simnet: Simnet;

  beforeEach(async () => {
    simnet = await initSimnet();
  });

  it('should have access to the simnet object', () => {
    expect(simnet).toBeDefined();
  });
});
