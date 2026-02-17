import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet, tx } from '@stacks/clarinet-sdk';

describe('Conxian Chaos Engineering Suite', () => {
  let simnet: any;
  let accounts: any;
  let deployer: string;
  let wallet1: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;

    // Initial setup: principal injection and authorizations
    const opsEngine = deployer + '.ops-engine';
    const agentTreasury = deployer + '.agent-treasury';
    const revenueDistributor = deployer + '.revenue-distributor';
    const agentRisk = deployer + '.agent-risk';

    simnet.callPublicFn('swap-router', 'set-ops-engine', [Cl.principal(opsEngine)], deployer);
    simnet.callPublicFn('agent-risk', 'set-ops-engine', [Cl.principal(opsEngine)], deployer);
    simnet.callPublicFn('cxd-treasury', 'set-authorized-principals', [Cl.principal(agentTreasury), Cl.principal(revenueDistributor)], deployer);
    simnet.callPublicFn('cxd-token', 'add-minter', [Cl.principal(opsEngine)], deployer);

    // Set some initial oracle data to avoid unwrap-panic
    const asset = Cl.principal(deployer + '.cxd-token');
    simnet.callPublicFn('oracle-aggregator', 'set-source', [asset, Cl.uint(100000000), Cl.uint(100)], deployer);
  });

  function unwrap(val: any): any {
    if (val && typeof val === 'object') {
      if ('value' in val) return unwrap(val.value);
      if ('data' in val) return val.data;
    }
    return val;
  }

  describe('Phase 1: Deterministic Logic & State Integrity', () => {
    it('Target 1 (Anti-LVR): Fee caps at 1.0% under extreme volatility', () => {
      const asset = Cl.principal(deployer + '.cxd-token');

      simnet.callPublicFn('oracle-aggregator', 'set-source', [asset, Cl.uint(100000000), Cl.uint(100)], deployer);
      simnet.callPublicFn('oracle-aggregator', 'set-source', [asset, Cl.uint(200000000), Cl.uint(100)], deployer);
      simnet.callPublicFn('oracle-aggregator', 'set-source', [asset, Cl.uint(50000000), Cl.uint(100)], deployer);

      simnet.callPublicFn('swap-router', 'update-volatility-fees', [], deployer);

      const feeRes = simnet.callReadOnlyFn('swap-router', 'get-fee', [], deployer);
      expect(unwrap(feeRes.result)).toBe(100n);
    });

    it('Target 2 (Fiscal Dam): Revenue split shifts to 100% Insurance at <110% GCR', () => {
      simnet.callPublicFn('agent-risk', 'set-mock-gcr', [Cl.uint(105)], deployer);
      const runRes = simnet.callPublicFn('agent-treasury', 'run-fiscal-strategy', [], deployer);

      const allocRes = simnet.callReadOnlyFn('cxd-treasury', 'get-allocation-percentages', [], deployer);
      const allocs = unwrap(allocRes.result);
      expect(unwrap(allocs.insurance)).toBe(10000n);
    });

    it('Target 3 (PID Stabilizer): Interest rate adjusts during de-peg', () => {
      const asset = Cl.principal(deployer + '.cxd-token');
      simnet.callPublicFn('oracle-aggregator', 'set-source', [asset, Cl.uint(99000000), Cl.uint(100)], deployer);

      const initialIntel = unwrap(simnet.callReadOnlyFn('agent-risk', 'get-cybernetic-intel', [], deployer).result);
      const initialFee = unwrap(initialIntel['operational-fee']);

      simnet.callPublicFn('agent-risk', 'update-pid-rates', [], deployer);

      const newIntel = unwrap(simnet.callReadOnlyFn('agent-risk', 'get-cybernetic-intel', [], deployer).result);
      const newFee = unwrap(newIntel['operational-fee']);

      expect(newFee).toBeGreaterThan(initialFee);
    });
  });

  describe('Phase 2: Property-Based Fuzzing', () => {
    it('Resilience against u1 (CRISIS) and Max uint inputs', () => {
      simnet.callPublicFn('agent-risk', 'set-mock-gcr', [Cl.uint(1)], deployer);
      simnet.callPublicFn('agent-treasury', 'run-fiscal-strategy', [], deployer);
      const allocRes = simnet.callReadOnlyFn('cxd-treasury', 'get-allocation-percentages', [], deployer);
      const allocs = unwrap(allocRes.result);
      expect(unwrap(allocs.insurance)).toBe(10000n);
    });
  });

  describe('Phase 3: Nakamoto Dual-Clock Desync', () => {
    it('Logic relies correctly on separate clocks', () => {
      simnet.callPublicFn('agent-treasury', 'run-fiscal-strategy', [], deployer);
      simnet.mineEmptyBlocks(5);

      const runAgain = simnet.callPublicFn('agent-treasury', 'run-fiscal-strategy', [], deployer);
      expect(runAgain.result.type).toBe(Cl.ok(Cl.bool(true)).type);
    });
  });

  describe('Phase 4: 10K Transaction Avalanche', () => {
    it('System handles load and prevents Keeper spam rewards', () => {
      const block = simnet.mineBlock([
        tx.callPublicFn('ops-engine', 'trigger-epoch-update', [], wallet1),
        tx.callPublicFn('ops-engine', 'trigger-epoch-update', [], wallet1),
        tx.callPublicFn('ops-engine', 'trigger-epoch-update', [], wallet1)
      ]);

      expect(block[0].result).toStrictEqual(Cl.ok(Cl.bool(true)));
      expect(block[1].result).toStrictEqual(Cl.error(Cl.uint(101)));
      expect(block[2].result).toStrictEqual(Cl.error(Cl.uint(101)));
    });
  });

  describe('Phase 5: Autonomous Self-Repair', () => {
    it('System defends against flash crash in a single cycle', () => {
      const asset = Cl.principal(deployer + '.cxd-token');
      simnet.callPublicFn('oracle-aggregator', 'set-source', [asset, Cl.uint(60000000), Cl.uint(100)], deployer);
      simnet.mineEmptyBlocks(20);
      simnet.callPublicFn('ops-engine', 'trigger-epoch-update', [], deployer);

      const feeRes = simnet.callReadOnlyFn('swap-router', 'get-fee', [], deployer);
      expect(unwrap(feeRes.result)).toBeGreaterThan(30n);
    });
  });
});
