import { describe, expect, it } from 'vitest';
import { simnet } from './setup-test-env';
import { Cl } from '@stacks/transactions';

describe('Admin Verification', () => {
  it('should have the correct protocol admin', () => {
    const accounts = simnet.getAccounts();
    const DEPLOYER = accounts.get('deployer')!;
    const adminRes = simnet.callReadOnlyFn('conxian-protocol', 'get-protocol-admin', [], DEPLOYER);
    expect((adminRes.result as any).value).toBe('ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P');
  });
});
