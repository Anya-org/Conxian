
import { describe, it, expect, beforeEach } from 'vitest';
import { initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Office Worker Architecture', () => {
  let simnet: any;
  let accounts: Map<string, string>;
  let deployer: string;
  let worker: string;
  let other: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("wallet_1")!;
    worker = accounts.get("wallet_2")!;
    other = accounts.get("wallet_3")!;
  });
  
  it('should allow owner to register a worker', () => {
    const response = simnet.callPublicFn(
      'office-manager',
      'register-worker',
      [Cl.standardPrincipal(worker)],
      deployer
    );
    expect(response.result).toBeOk(Cl.bool(true));
    
    const active = simnet.callReadOnlyFn(
      'office-manager',
      'is-worker-active',
      [Cl.standardPrincipal(worker)],
      deployer
    );
    expect(active.result).toBeBool(true);
  });

  it('should allow owner to fund payroll', () => {
    const response = simnet.callPublicFn(
      'office-manager',
      'fund-payroll',
      [Cl.uint(1000)],
      deployer
    );
    expect(response.result).toBeOk(Cl.bool(true));
  });

  it('should authorize agent-treasury', () => {
    const response = simnet.callPublicFn(
      'office-manager',
      'set-agent-status',
      [Cl.contractPrincipal(deployer, 'agent-treasury'), Cl.bool(true)],
      deployer
    );
    expect(response.result).toBeOk(Cl.bool(true));
  });

  it('should allow worker to execute job and get paid', () => {
    // 1. Setup: Register worker, Fund payroll, Authorize Agent
    simnet.callPublicFn('office-manager', 'register-worker', [Cl.standardPrincipal(worker)], deployer);
    simnet.callPublicFn('office-manager', 'fund-payroll', [Cl.uint(1000)], deployer);
    simnet.callPublicFn('office-manager', 'set-agent-status', [Cl.contractPrincipal(deployer, 'agent-treasury'), Cl.bool(true)], deployer);

    // 2. Do Work (Trigger payout)
    const execResponse = simnet.callPublicFn(
      'agent-treasury',
      'do-work',
      [Cl.bufferFromHex('01')], // Fake job data
      worker
    );
    expect(execResponse.result).toBeOk(Cl.bool(true));

    // 3. Verify Payout event
    expect(execResponse.events.length).toBeGreaterThan(0);
  });

  it('should fail if unauthorized worker tries to work', () => {
     simnet.callPublicFn('office-manager', 'fund-payroll', [Cl.uint(1000)], deployer);
     simnet.callPublicFn('office-manager', 'set-agent-status', [Cl.contractPrincipal(deployer, 'agent-treasury'), Cl.bool(true)], deployer);

     const execResponse = simnet.callPublicFn(
      'agent-treasury',
      'do-work',
      [Cl.bufferFromHex('01')],
      other // Not registered
    );
    // Expect error because office-manager.payout will fail with ERR_UNKNOWN_WORKER
    expect(execResponse.result).toBeErr(Cl.uint(1001)); 
  });

});
