
import { describe, it, beforeAll } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';

describe('Compilation Check', () => {
  it('should initialize simnet without errors', async () => {
    try {
      const simnet = await initSimnet();
      console.log('Simnet initialized successfully');
    } catch (e) {
      console.error('Simnet initialization failed:', e);
      throw e;
    }
  }, 300000);
});
