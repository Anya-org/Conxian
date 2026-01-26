import { beforeAll, afterAll } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import type { Simnet } from '@stacks/clarinet-sdk';

let simnet: Simnet;

beforeAll(async () => {
  simnet = await initSimnet();
});

afterAll(async () => {
  // No cleanup needed
});

export { simnet };
