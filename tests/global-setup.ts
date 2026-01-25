import { initSimnet } from '@stacks/clarinet-sdk';

export async function setup() {
  console.log("--- Executing Vitest Global Setup ---");
  const simnet = await initSimnet();
  (globalThis as any).simnet = simnet;
  console.log("--- Simnet Initialized and Set on globalThis ---");
}

export async function teardown() {
  console.log("--- Executing Vitest Global Teardown ---");
  // No specific cleanup needed for simnet at the moment.
}
