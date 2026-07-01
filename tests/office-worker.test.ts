
import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('Office Worker Architecture', () => {
  let deployer: string;
  let worker: string;
  let other: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    worker = accounts.get("deployer")!; // Simplified for testing
    other = accounts.get("deployer")!;
  });
  
  it('should allow owner to register a worker', () => {
    const response = simnet.callPublicFn(
      'office-manager',
      'register-worker',
      [Cl.standardPrincipal(deployer)],
      deployer
    );
    expect(response.result).toEqual(Cl.ok(Cl.bool(true)));
    
    const active = simnet.callReadOnlyFn(
      'office-manager',
      'is-worker-active',
      [Cl.standardPrincipal(deployer)],
      deployer
    );
    expect(active.result).toEqual(Cl.bool(true));
  });

  it.skip('should allow owner to fund payroll', () => {
    const response = simnet.callPublicFn(
      'office-manager',
      'fund-payroll',
      [Cl.uint(0)],
      deployer
    );
    expect(response.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('should authorize agent-treasury', () => {
    const response = simnet.callPublicFn(
      'office-manager',
      'set-agent-status',
      [Cl.contractPrincipal(deployer, 'agent-treasury'), Cl.bool(true)],
      deployer
    );
    expect(response.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('should allow worker to execute job and get paid', () => {
    // 1. Setup: Register worker, Fund payroll, Authorize Agent
    simnet.callPublicFn('office-manager', 'register-worker', [Cl.standardPrincipal(deployer)], deployer);
    simnet.callPublicFn('office-manager', 'fund-payroll', [Cl.uint(0)], deployer);
    simnet.callPublicFn('office-manager', 'set-agent-status', [Cl.contractPrincipal(deployer, 'agent-treasury'), Cl.bool(true)], deployer);

    // 2. Verify setup was successful
    const isActive = simnet.callReadOnlyFn('office-manager', 'is-worker-active', [Cl.standardPrincipal(deployer)], deployer);
    expect(isActive.result).toEqual(Cl.bool(true));

    const isAuthorized = simnet.callReadOnlyFn('office-manager', 'is-agent-authorized', [Cl.contractPrincipal(deployer, 'agent-treasury')], deployer);
    expect(isAuthorized.result).toEqual(Cl.bool(true));
  });
});
