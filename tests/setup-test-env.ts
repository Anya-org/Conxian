import { beforeAll } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';

let internalSimnet: Simnet | null = null;
let initializationPromise: Promise<Simnet> | null = null;

/**
 * Robust singleton initialization for Simnet.
 * Ensures only one instance is created even if called concurrently.
 */
export async function initializeSimnet(): Promise<Simnet> {
  if (internalSimnet) return internalSimnet;
  if (initializationPromise) return initializationPromise;

  console.log('Initializing Simnet for test environment...');
  initializationPromise = initSimnet('Clarinet.toml').then((instance) => {
    internalSimnet = instance;
    console.log('Simnet initialized.'); console.log('Accounts:', instance.getAccounts());
    return instance;
  }).catch((error) => {
    initializationPromise = null; // Reset on failure to allow retry
    throw error;
  });

  return initializationPromise;
}

/**
 * Proxy for the simnet instance.
 * Allows tests to import 'simnet' and use it directly,
 * but provides a clear error if accessed before initialization.
 */
export const simnet: Simnet = new Proxy({} as Simnet, {
  get: (_target, prop) => {
    if (!internalSimnet) {
      throw new Error(
        `Accessing 'simnet.${String(prop)}' before initialization. ` +
        `Ensure you are calling this inside a test block (it, test) ` +
        `or after 'await initializeSimnet()' has completed.`
      );
    }
    const value = (internalSimnet as any)[prop];
    if (typeof value === 'function') {
      return value.bind(internalSimnet);
    }
    return value;
  }
});

// Register beforeAll to ensure initialization happens when this file is used as a setup file or imported.
beforeAll(async () => {
  await initializeSimnet();
});
