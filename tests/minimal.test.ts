import { describe, expect, it } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';

describe('Minimal Test', () => {
  it('should check built-ins', async () => {
    const simnet = await initSimnet('Clarinet.minimal.toml');
    const result = simnet.callReadOnlyFn('minimal', 'get-sbh', [], simnet.deployer);
    console.log('Result:', result.result);
    expect(result.result).toBeDefined();
  });
});
