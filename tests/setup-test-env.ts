import { beforeAll } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';

let initializationPromise: Promise<Simnet> | null = null;
export let simnet: Simnet;

export async function initializeSimnet() {
  if (!initializationPromise) {
    console.log('Initializing Simnet for test environment...');
    initializationPromise = initSimnet('Clarinet.toml').then((instance) => {
      simnet = instance;
      console.log('Simnet initialized.');
      return instance;
    });
  }
  return initializationPromise;
}

beforeAll(async () => {
  await initializeSimnet();
});
