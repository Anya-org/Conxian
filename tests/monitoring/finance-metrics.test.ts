import { describe, it, expect, beforeAll } from 'vitest';
import { simnet } from '../setup-test-env';
import { Cl } from '@stacks/transactions';

describe('Finance Metrics', () => {
  it('verifies v1.2.0 features and Unified Theory variables', () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;

    // Check version and theory metrics in status
    const statusRes = simnet.callReadOnlyFn('finance-metrics', 'get-protocol-status', [], deployer);
    const status: any = statusRes.result;

    // Status should be (ok { ... })
    // In Vitest Simnet, we might need to parse the response or check prettyPrint
    console.log('Status Result:', Cl.prettyPrint(status));

    expect(Cl.prettyPrint(status)).toContain('version: "v1.2.0-Apex"');
    expect(Cl.prettyPrint(status)).toContain('c-r: u0');
    expect(Cl.prettyPrint(status)).toContain('v-x: u0');
    expect(Cl.prettyPrint(status)).toContain('a-s: u0');

    // Update theory metrics
    const updateRes = simnet.callPublicFn(
      'finance-metrics',
      'update-theory-metrics',
      [Cl.uint(100), Cl.uint(200), Cl.uint(300)],
      deployer
    );
    expect(updateRes.result).toEqual(Cl.ok(Cl.bool(true)));

    // Verify updated status
    const updatedStatusRes = simnet.callReadOnlyFn('finance-metrics', 'get-protocol-status', [], deployer);
    const updatedStatus = updatedStatusRes.result;
    console.log('Updated Status:', Cl.prettyPrint(updatedStatus));

    expect(Cl.prettyPrint(updatedStatus)).toContain('c-r: u100');
    expect(Cl.prettyPrint(updatedStatus)).toContain('v-x: u200');
    expect(Cl.prettyPrint(updatedStatus)).toContain('a-s: u300');
  });
});
