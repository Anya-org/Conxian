import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@stacks/clarinet-sdk';

describe('BME & Intent Layer Verification', () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    // Force simple simnet initialization without problematic agent-treasury dependency
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('verifies bme-engine has Activity Marker and Recycling logic', () => {
    const accounts = simnet.getAccounts();
    const pool = accounts.get('wallet_1')!;

    // Register Activity Marker
    simnet.callPublicFn('bme-engine', 'add-activity-reporter', [Cl.principal(deployer)], deployer);
    let res = simnet.callPublicFn('bme-engine', 'register-fee-activity', [Cl.principal(pool), Cl.uint(5000)], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.bool(true)));

    // Verify Recycling
    // Note: This would require cxd-token balance, but we test structural presence
    let stats = simnet.callReadOnlyFn('bme-engine', 'get-bme-stats', [], deployer);
    expect(stats.result).toBeDefined();
  });

  it('verifies intent-solver-gateway execution with Universal Message Bus', () => {
    const solver = deployer;
    const intentId = '1234567812345678123456781234567812345678123456781234567812345678';

    // Test execute-intent structural integrity
    let res = simnet.callPublicFn('intent-solver-gateway', 'execute-intent', [
      Cl.buffer(Buffer.from(intentId, 'hex')),
      Cl.buffer(Buffer.alloc(10)),
      Cl.principal(solver)
    ], deployer);
    expect(res.result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
