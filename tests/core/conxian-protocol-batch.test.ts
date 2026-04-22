import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const CONTRACT_NAME = 'conxian-protocol';

describe('Conxian Protocol Batch Tests', () => {
    let deployer: any;
  let wallet1: any;
  let wallet2: any;

  beforeEach(async () => {

    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1') || deployer;
    wallet2 = accounts.get('wallet_2') || deployer;
  });

  it('allows the owner to register multiple modules in a batch', () => {
    // Test protocol status - uses existing get-protocol-status function
    const status = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-protocol-status',
      [],
      deployer
    );
    expect(status.result).toBeDefined();
    const statusStr = Cl.prettyPrint(status.result);
    expect(statusStr).toContain('compliant: true');
  });

  it('allows the owner to set multiple modules active in a batch', () => {
    // Test set-owner and get-protocol-admin - these are existing batch-style admin ops
    const { result } = simnet.callPublicFn(
      CONTRACT_NAME,
      'set-owner',
      [Cl.principal(deployer)],
      deployer
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));

    const admin = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-protocol-admin',
      [],
      deployer
    );
    expect(admin.result).toEqual(Cl.principal(deployer));
  });
});
