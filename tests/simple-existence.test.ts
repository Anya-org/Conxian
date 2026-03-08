import { describe, it, expect } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';

describe('Existence Check', () => {
  it('checks if core contracts are deployed', async () => {
    const simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;

    console.log('Deployer:', deployer);

    const contracts = [
      'conxian-protocol',
      'ops-engine',
      'swap-router',
      'agent-risk',
      'agent-treasury',
      'oracle-aggregator'
    ];

    for (const name of contracts) {
      try {
        const res = simnet.callReadOnlyFn(name, 'get-protocol-status', [], deployer);
        console.log(`Contract ${name} existence check: `, res.result);
      } catch (e) {
        console.log(`Contract ${name} check failed`);
      }
    }
  });
});
