import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('CXIP-012: Cybernetic Protocol Upgrade Simulation', () => {
  let deployer: string;
  let keeper: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    keeper = accounts.get('wallet_1')!;
  });

  it('Scenario: Market Crash triggers Anti-LVR and Fiscal Dam', () => {
    // 1. SETUP: Authorize ops-engine, create pool, and initialize oracle
    simnet.callPublicFn('cxd-token', 'add-minter', [Cl.contractPrincipal(deployer, 'ops-engine')], deployer);

    // Set ops-engine in swap-router to allow fee updates
    simnet.callPublicFn('swap-router', 'set-ops-engine', [Cl.contractPrincipal(deployer, 'ops-engine')], deployer);

    // Create Pool 1
    simnet.callPublicFn('concentrated-liquidity-pool', 'create-pool', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.contractPrincipal(deployer, 'cxvg-token'),
        Cl.uint(30), // 0.3%
        Cl.uint(100000000),
        Cl.int(0)
    ], deployer);

    simnet.callPublicFn('oracle-aggregator', 'set-source', [
        Cl.contractPrincipal(deployer, 'cxd-token'),
        Cl.uint(100000000),
        Cl.uint(100)
    ], deployer);

    // Check initial fee (0.3% = 30 bps)
    const initialFee = simnet.callReadOnlyFn('swap-router', 'get-fee', [], deployer);
    expect(initialFee.result).toEqual(Cl.ok(Cl.uint(30)));

    // 2. TRIGGER CRASH: Increase volatility and set crisis risk params
    simnet.callPublicFn('oracle-aggregator', 'set-source', [Cl.contractPrincipal(deployer, 'cxd-token'), Cl.uint(70000000), Cl.uint(100)], deployer);

    // Set predictive params to trigger "Crisis" (score > 5000 -> GCR < 110)
    simnet.callPublicFn('agent-risk', 'set-predictive-params', [Cl.uint(0), Cl.uint(10000), Cl.uint(10000)], deployer);

    const riskScore = simnet.callReadOnlyFn('agent-risk', 'assess-system-risk', [], deployer);
    console.log('Risk Score:', riskScore.result);

    // 3. RUN AUTOMATION: Keeper triggers epoch update
    simnet.mineEmptyBlocks(13); // Ensure enough blocks for fast check (12)

    const response = simnet.callPublicFn('ops-engine', 'trigger-epoch-update', [], keeper);
    console.log('Epoch Update Response:', response.result);
    expect(response.result).toEqual(Cl.ok(Cl.bool(true)));

    // 4. VERIFY REFLEXES
    // Assert Fee spiked to 1.0% (100 bps) due to Anti-LVR
    const spikedFee = simnet.callReadOnlyFn('swap-router', 'get-fee', [], deployer);
    expect(spikedFee.result).toEqual(Cl.ok(Cl.uint(100)));

    // Assert Fiscal Dam rerouted revenue to Vault (0% staking, 0% dev, 100% insurance)
    const policy = simnet.callReadOnlyFn('cxd-treasury', 'get-allocation-percentages', [], deployer);
    expect(policy.result).toEqual(Cl.ok(Cl.tuple({ staking: Cl.uint(0), dev: Cl.uint(0), insurance: Cl.uint(10000) })));

    // 5. VERIFY KEEPER REWARD
    const balance = simnet.callReadOnlyFn('cxd-token', 'get-balance', [Cl.standardPrincipal(keeper)], deployer);
    expect(balance.result).toEqual(Cl.ok(Cl.uint(500000000))); // 5 CXD
  });
});
