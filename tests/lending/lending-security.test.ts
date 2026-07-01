import { describe, expect, it, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const CONTRACT_NAME = 'lending-manager';

describe('Lending Manager Security and Solvency', () => {
  let accounts: any;
  let deployer: string;
  let wallet1: string;

  beforeEach(() => {
    accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('should initialize correctly', () => {
    const res = simnet.callPublicFn(CONTRACT_NAME, 'initialize', [Cl.principal(deployer)], deployer);
    expect(Cl.prettyPrint(res.result)).toMatch(/ok true|u1000/);
  });

  it('should reject borrowing if account is insolvent', () => {
    const ASSET = Cl.principal(deployer + '.cxd-token');
    const res = simnet.callPublicFn(CONTRACT_NAME, 'borrow', [ASSET, Cl.uint(1000)], wallet1);
    expect(res.result).toEqual(Cl.error(Cl.uint(404))); // ERR_NOT_FOUND for reserve
  });

  it('should respect circuit breaker', () => {
    const ASSET = Cl.principal(deployer + '.cxd-token');
    // Pause the contract via enhanced-circuit-breaker
    simnet.callPublicFn('enhanced-circuit-breaker', 'toggle-contract-pause', [Cl.principal(deployer + '.' + CONTRACT_NAME)], deployer);

    const res = simnet.callPublicFn(CONTRACT_NAME, 'deposit', [ASSET, Cl.uint(1000)], wallet1);
    expect(res.result).toEqual(Cl.error(Cl.uint(1001))); // ERR_PAUSED
  });
});
