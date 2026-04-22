import { beforeAll } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';

let internalSimnet: Simnet | null = null;
let initializationPromise: Promise<Simnet> | null = null;

export async function initializeSimnet(): Promise<Simnet> {
  if (internalSimnet) return internalSimnet;
  if (initializationPromise) return initializationPromise;

  initializationPromise = (async () => {
    try {
      console.log('Initializing simnet with Clarinet.toml...');
      const instance = await initSimnet('Clarinet.toml');
      internalSimnet = instance;
      console.log('Simnet initialized.');
      return instance;
    } catch (error) {
      console.error('Failed to initialize simnet:', error);
      initializationPromise = null; // Allow retry on failure
      throw error;
    }
  })();

  return initializationPromise;
}

export const simnet: Simnet = new Proxy({} as Simnet, {
  get: (_target, prop) => {
    if (!internalSimnet) {
      throw new Error(`Simnet not initialized. Ensure initializeSimnet() is called before accessing '${String(prop)}'.`);
    }
    const value = (internalSimnet as any)[prop];
    if (typeof value === 'function') {
      return value.bind(internalSimnet);
    }
    return value;
  }
});

beforeAll(async () => {
  await initializeSimnet();
});
