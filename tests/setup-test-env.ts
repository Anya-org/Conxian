import { beforeAll, afterAll } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import type { Simnet } from '@stacks/clarinet-sdk';

let simnet: Simnet;

beforeAll(async () => {
  if (!simnet) {
    console.log('Initializing Simnet for test environment...');
    simnet = await initSimnet();
    console.log('Simnet initialized.');
  }
});

afterAll(async () => {
  // Cleanup if necessary
});

export { simnet };
