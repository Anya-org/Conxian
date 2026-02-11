import { describe, it } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { resolve } from 'path';

describe('Debug Accounts', () => {
  it('should print accounts', async () => {
    const simnet = await initSimnet(resolve(__dirname, '../Clarinet.toml'));
    const accounts = simnet.getAccounts();
    console.log('Deployer address:', accounts.get('deployer'));
  });
});
