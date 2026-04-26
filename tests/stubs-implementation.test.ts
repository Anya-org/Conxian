import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('System Stubs Implementation (CON-502)', () => {
  let deployer: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('finance-metrics should allow manual telemetry updates', () => {
    const res = simnet.callPublicFn('finance-metrics', 'update-metrics', [Cl.uint(100000000), Cl.uint(150)], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.bool(true)));

    const tvl = simnet.callReadOnlyFn('finance-metrics', 'get-protocol-tvl', [], deployer);
    expect(tvl.result).toEqual(Cl.ok(Cl.uint(100000000)));
  });

  it('dlc-manager should verify bitvm2 placeholders', () => {
    const res = simnet.callPublicFn('dlc-manager', 'verify-bitvm2-root', [Cl.buffer(new Uint8Array(32)), Cl.buffer(new Uint8Array(1024))], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
