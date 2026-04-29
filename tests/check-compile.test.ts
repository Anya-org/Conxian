
import { describe, it } from 'vitest';
import { initializeSimnet } from './setup-test-env';

describe('Compilation Check', () => {
  it('should initialize simnet without errors', async () => {
    await initializeSimnet();
    console.log('Simnet initialized successfully');
  }, 300000);
});
