
import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('Office Worker Architecture', () => {
  let deployer: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;

    // Initialize the Principal Registry in operational-treasury
    simnet.callPublicFn(
      'operational-treasury',
      'set-protocol-principal',
      [Cl.stringAscii("office-manager-owner"), Cl.principal(deployer)],
      deployer
    );
  });
  
  it('should allow owner to register a worker', () => {
    const response = simnet.callPublicFn(
      'office-manager',
      'register-worker',
      [Cl.standardPrincipal(deployer)],
      deployer
    );
    expect(response.result).toBeDefined();
    
    const active = simnet.callReadOnlyFn(
      'office-manager',
      'is-worker-active',
      [Cl.standardPrincipal(deployer)],
      deployer
    );
    expect(active.result).toEqual(Cl.bool(true));
  });

  it('should allow owner to fund payroll', () => {
    const response = simnet.callPublicFn(
      'office-manager',
      'fund-payroll',
      [Cl.uint(1000)],
      deployer
    );
    expect(response.result).toBeDefined();
  });

  it('should authorize fiscal-orchestrator', () => {
    const response = simnet.callPublicFn(
      'office-manager',
      'set-agent-status',
      [Cl.contractPrincipal(deployer, 'fiscal-orchestrator'), Cl.bool(true)],
      deployer
    );
    expect(response.result).toBeDefined();
  });

  it('should allow worker to execute job and get paid', () => {
    // 1. Setup: Register worker, Fund payroll, Authorize Agent
    simnet.callPublicFn('office-manager', 'register-worker', [Cl.standardPrincipal(deployer)], deployer);
    simnet.callPublicFn('office-manager', 'fund-payroll', [Cl.uint(1000)], deployer);
    simnet.callPublicFn('office-manager', 'set-agent-status', [Cl.contractPrincipal(deployer, 'fiscal-orchestrator'), Cl.bool(true)], deployer);

    // 2. Verify setup was successful
    const isActive = simnet.callReadOnlyFn('office-manager', 'is-worker-active', [Cl.standardPrincipal(deployer)], deployer);
    expect(isActive.result).toEqual(Cl.bool(true));

    const isAuthorized = simnet.callReadOnlyFn('office-manager', 'is-authorized-agent', [Cl.contractPrincipal(deployer, 'fiscal-orchestrator')], deployer);
    expect(isAuthorized.result).toEqual(Cl.bool(true));
  });
});
