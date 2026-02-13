import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('Conxian Core Comprehensive Integration', () => {
  let deployer: string;
  let wallet1: string;

  beforeAll(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;

    // 1. Setup Roles and Authorizations
    const opsEnginePrincipal = Cl.contractPrincipal(deployer, 'ops-engine');
    const agentTreasuryPrincipal = Cl.contractPrincipal(deployer, 'agent-treasury');

    // Authorize ops-engine to mint CXD (for keeper rewards)
    simnet.callPublicFn('cxd-token', 'add-minter', [opsEnginePrincipal], deployer);

    // Set ops-engine in swap-router
    simnet.callPublicFn('swap-router', 'set-ops-engine', [opsEnginePrincipal], deployer);
    
    // Set agent-treasury in cxd-treasury
    simnet.callPublicFn('cxd-treasury', 'set-agent-treasury', [agentTreasuryPrincipal], deployer);

    // Initialize oracle price for CXD
    simnet.callPublicFn('oracle-aggregator', 'set-source', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(100000000), // $1.00
        Cl.uint(10000)      // 100% weight
    ], deployer);
  });

  it('should initialize and run the full Dual-Clock epoch update', () => {
    // Mine some blocks to pass the 12-block fast-path threshold
    simnet.mineEmptyBlocks(15);

    // Current CXD supply
    const initialSupplyRes = simnet.callReadOnlyFn('cxd-token', 'get-total-supply', [], deployer);
    const initialSupply = (initialSupplyRes.result as any).value.value;

    // Trigger epoch update
    const triggerRes = simnet.callPublicFn('ops-engine', 'trigger-epoch-update', [], wallet1);
    expect(triggerRes.result).toEqual(Cl.ok(Cl.bool(true)));

    // 1. Verify Keeper was paid 5 CXD
    const finalSupplyRes = simnet.callReadOnlyFn('cxd-token', 'get-total-supply', [], deployer);
    const finalSupply = (finalSupplyRes.result as any).value.value;
    expect(finalSupply - initialSupply).toEqual(500000000n);

    // 2. Verify Fast Path: swap-router fee updated
    const feeRes = simnet.callReadOnlyFn('swap-router', 'get-fee', [], deployer);
    expect(feeRes.result).toEqual(Cl.ok(Cl.uint(30)));

    // 3. Verify Slow Path: agent-treasury ran and updated cxd-treasury
    const allocationRes = simnet.callReadOnlyFn('cxd-treasury', 'get-allocation-percentages', [], deployer);
    expect(allocationRes.result).toEqual(Cl.ok(Cl.tuple({
        treasury: Cl.uint(1000),
        bounty: Cl.uint(0),
        lp: Cl.uint(8000),
        grant: Cl.uint(0),
        buyback: Cl.uint(0),
        insurance: Cl.uint(1000),
        staking: Cl.uint(8000),
        dev: Cl.uint(1000)
    })));
  });

  it('should demonstrate Fiscal Dam rebalancing during a Crisis', () => {
    // Force Crisis via high risk score
    simnet.callPublicFn('agent-risk', 'set-predictive-params', [Cl.uint(0), Cl.uint(10000), Cl.uint(10000)], deployer);
    
    // Mine enough blocks to ensure burn-block-height > last-slow-check
    simnet.mineEmptyBlocks(20);
    simnet.mineEmptyBurnBlocks(2);

    // Trigger epoch update
    const triggerRes = simnet.callPublicFn('ops-engine', 'trigger-epoch-update', [], wallet1);
    expect(triggerRes.result).toEqual(Cl.ok(Cl.bool(true)));

    // Verify Crisis allocation (100% insurance)
    const allocationRes = simnet.callReadOnlyFn('cxd-treasury', 'get-allocation-percentages', [], deployer);
    expect(allocationRes.result).toEqual(Cl.ok(Cl.tuple({
        treasury: Cl.uint(0),
        bounty: Cl.uint(0),
        lp: Cl.uint(0),
        grant: Cl.uint(0),
        buyback: Cl.uint(0),
        insurance: Cl.uint(10000),
        staking: Cl.uint(0),
        dev: Cl.uint(0)
    })));
  });

  it('should correctly calculate PID stability fee when price deviates', () => {
    // Set CXD price to $0.50 (50% depeg) to ensure we hit the 2000 bps cap
    simnet.callPublicFn('oracle-aggregator', 'set-source', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(50000000), // $0.50
        Cl.uint(10000)
    ], deployer);

    // Mine enough blocks
    simnet.mineEmptyBlocks(20);
    simnet.mineEmptyBurnBlocks(2);

    const triggerRes = simnet.callPublicFn('ops-engine', 'trigger-epoch-update', [], wallet1);
    expect(triggerRes.result).toEqual(Cl.ok(Cl.bool(true)));

    // Verify PID updated stability-fee
    // Error = 1.0 - 0.5 = 0.5 = 50,000,000 (8 decimals)
    // Kp = 5. Output = 5 * 50,000,000 = 250,000,000
    // Clamped to 2000 bps
    const feeRes = simnet.callReadOnlyFn('agent-risk', 'get-stability-fee', [], deployer);
    expect(feeRes.result).toEqual(Cl.ok(Cl.uint(2000)));
  });
});
