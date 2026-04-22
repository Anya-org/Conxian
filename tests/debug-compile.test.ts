import { describe, it, expect } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';

describe('Debug Compilation', () => {
  it('should initialize minimal simnet', async () => {
    const simnet = await initSimnet('Debug.toml');
    expect(simnet).toBeDefined();
    console.log('✅ Minimal Simnet initialized');
  }, 300000);
});
