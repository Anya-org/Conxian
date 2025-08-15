import { initSimnet } from '@hirosystems/clarinet-sdk';
import { describe, it, expect } from 'vitest';

describe('simnet initialization test', () => {
  it('should initialize simnet without errors', async () => {
    try {
      const simnet = await initSimnet();
      const accounts = simnet.getAccounts();
      console.log('Successfully initialized simnet');
      console.log('Available accounts:', Array.from(accounts.keys()));
      expect(accounts.size).toBeGreaterThan(0);
    } catch (error) {
      console.error('Simnet initialization failed:', error);
      throw error;
    }
  });
});
