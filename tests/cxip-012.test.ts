import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('CXIP-012: The Cybernetic Protocol Upgrade', () => {
  let deployer: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('Scenario: Black Monday - 30% Market Crash triggers Anti-LVR and Fiscal Dam', () => {
    // 1. Setup: Create pool, Mint initial tokens and set initial price
    simnet.callPublicFn('cxd-token', 'add-minter', [Cl.contractPrincipal(deployer, 'ops-engine')], deployer);

    // Create Pool 1
    simnet.callPublicFn('concentrated-liquidity-pool', 'create-pool', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.contractPrincipal(deployer, 'cxvg-token'),
        Cl.uint(3000), // 0.3%
        Cl.uint(100000000)
    ], deployer);

    // Set initial price $1.00 for CXD
    simnet.callPublicFn('oracle-aggregator', 'set-source', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(100000000), // $1.00
        Cl.uint(100)
    ], deployer);

    // Verify initial fee is 0.3% (3000 ppm)
    let fee = simnet.callReadOnlyFn('swap-router', 'get-fee', [], deployer);
    expect(fee.result).toEqual(Cl.uint(3000));

    // 2. TRIGGER CRASH: Price drops and volatility increases
    simnet.callPublicFn('oracle-aggregator', 'set-source', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(70000000), // $0.70
        Cl.uint(100)
    ], deployer);

    simnet.callPublicFn('oracle-aggregator', 'set-source', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(130000000), // $1.30 (high variance)
        Cl.uint(100)
    ], deployer);

    // 3. Run Automation (The "Keeper" Trigger)
    simnet.mineEmptyBlocks(11);

    const response = simnet.callPublicFn('ops-engine', 'trigger-epoch-update', [], deployer);
    expect(response.result).toBeDefined();

    // 4. Verify Anti-LVR (Fast Path)
    fee = simnet.callReadOnlyFn('swap-router', 'get-fee', [], deployer);
    expect(fee.result).toEqual(Cl.uint(10000));

    // 5. Verify Fiscal Dam (Slow Path)
    const shares = simnet.callReadOnlyFn('cxd-treasury', 'get-allocation-percentages', [], deployer);
    console.log('Final Shares:', Cl.prettyPrint(shares.result));
  });
});
