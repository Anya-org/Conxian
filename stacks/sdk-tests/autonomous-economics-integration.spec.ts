import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@hirosystems/clarinet-sdk';

/**
 * AutoVault Autonomous Economics & Multi-Token Integration Tests
 * Validates enhanced autonomous fee adjustments, performance benchmarks,
 * and competitor token liquidity acceptance for maximum yield optimization
 */

describe('AutoVault Autonomous Economics Integration', () => {
  let simnet: any;
  let accounts: Map<string, string>;
  let admin: string;
  let user1: string;
  let user2: string;
  let CONTRACTS: any;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    admin = accounts.get('deployer')!;
    user1 = accounts.get('wallet_1')!;
    user2 = accounts.get('wallet_2')!;
    
    CONTRACTS = {
      vault: `${admin}.vault`,
      vaultMultiToken: `${admin}.vault-multi-token`,
      mockFt: `${admin}.mock-ft`,
    };
  });

  describe('Autonomous Fee Adjustments', () => {
    it('should enable autonomous fee adjustments on deployment', () => {
      // Test autonomous fee system activation
      const enableResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-auto-fees-enabled',
        [Cl.bool(true)],
        admin
      );
      expect(enableResult.result).toBeOk(Cl.bool(true));

      // Verify autonomous economics can be enabled
      const enableEconomicsResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-auto-economics-enabled',
        [Cl.bool(true)],
        admin
      );
      expect(enableEconomicsResult.result).toBeOk(Cl.bool(true));

      // Check status
      const statusResult = simnet.callReadOnlyFn(
        CONTRACTS.vault,
        'get-autonomous-economics-status',
        [],
        admin
      );
      expect(statusResult.result).toBeOk(
        Cl.tuple({
          'auto-fees-enabled': Cl.bool(true),
          'auto-economics-enabled': Cl.bool(true),
          'competitive-yield-tracking': Cl.bool(false),
          'performance-benchmark': Cl.uint(500)
        })
      );
    });

    it('should adjust fees based on utilization automatically', () => {
      // Enable autonomous fees
      simnet.callPublicFn(
        CONTRACTS.vault,
        'set-auto-fees-enabled',
        [Cl.bool(true)],
        admin
      );

      // Set utilization thresholds
      const setThresholdsResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-util-thresholds',
        [Cl.uint(8000), Cl.uint(2000)], // 80% high, 20% low
        admin
      );
      expect(setThresholdsResult.result).toBeOk(Cl.bool(true));

      // Set fee bounds
      const setBoundsResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-fee-bounds',
        [Cl.uint(5), Cl.uint(100)], // 0.05% min, 1% max
        admin
      );
      expect(setBoundsResult.result).toBeOk(Cl.bool(true));

      // Trigger fee update
      const updateResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'update-fees-based-on-utilization',
        [],
        admin
      );
      expect(updateResult.result).toBeOk(Cl.uint(0)); // 0% utilization initially
    });

    it('should update reserve bands and fee ramps', () => {
      // Set reserve target bands
      const setBandsResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-reserve-bands',
        [Cl.uint(500), Cl.uint(1500)], // 5% - 15%
        admin
      );
      expect(setBandsResult.result).toBeOk(Cl.bool(true));

      // Set fee ramp steps
      const setRampsResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-fee-ramps',
        [Cl.uint(5), Cl.uint(5)], // 0.05% steps
        admin
      );
      expect(setRampsResult.result).toBeOk(Cl.bool(true));

      // Verify settings
      const bandsResult = simnet.callReadOnlyFn(
        CONTRACTS.vault,
        'get-reserve-bands',
        [],
        admin
      );
      expect(bandsResult.result).toBeOk(
        Cl.tuple({
          low: Cl.uint(500),
          high: Cl.uint(1500)
        })
      );
    });
  });

  describe('Performance Benchmark Configuration', () => {
    it('should configure performance benchmarks for competitive yields', () => {
      // Set performance benchmark APY
      const setBenchmarkResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-performance-benchmark',
        [Cl.uint(600)], // 6% APY
        admin
      );
      expect(setBenchmarkResult.result).toBeOk(Cl.bool(true));

      // Enable competitive yield tracking
      const enableTrackingResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-competitive-yield-tracking',
        [Cl.bool(true)],
        admin
      );
      expect(enableTrackingResult.result).toBeOk(Cl.bool(true));

      // Check benchmark status
      const benchmarkResult = simnet.callReadOnlyFn(
        CONTRACTS.vault,
        'get-performance-benchmark',
        [],
        admin
      );
      expect(benchmarkResult.result).toBeOk(
        Cl.tuple({
          'apy-bps': Cl.uint(600),
          'last-update': Cl.uint(simnet.blockHeight),
          'update-interval': Cl.uint(144),
          'competitive-tracking': Cl.bool(true)
        })
      );
    });

    it('should reject excessive benchmark rates', () => {
      // Try to set unrealistic 25% benchmark (should fail)
      const setBenchmarkResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-performance-benchmark',
        [Cl.uint(2500)], // 25% APY - too high
        admin
      );
      expect(setBenchmarkResult.result).toBeErr(Cl.uint(108)); // ERR_INVALID_BENCHMARK
    });

    it('should auto-adjust benchmarks when competitive tracking enabled', () => {
      // Enable competitive tracking first
      simnet.callPublicFn(
        CONTRACTS.vault,
        'set-competitive-yield-tracking',
        [Cl.bool(true)],
        admin
      );

      // Mine enough blocks to trigger update
      simnet.mineEmptyBlocks(150); // More than update interval (144)

      // Trigger dynamic adjustment
      const adjustResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'adjust-benchmark-dynamically',
        [],
        admin
      );
      expect(adjustResult.result).toBeOk(Cl.bool(true));
    });
  });

  describe('Multi-Token Competitor Integration', () => {
    it('should add supported competitor tokens', () => {
      // Add a mock competitor token (STX in this case)
      const addTokenResult = simnet.callPublicFn(
        CONTRACTS.vaultMultiToken,
        'add-supported-token',
        [
          Cl.principal(`${admin}.mock-ft`), // token
          Cl.uint(2500), // 25% weight
          Cl.principal(`${admin}.vault`), // strategy contract
          Cl.uint(3), // risk rating (1-5)
          Cl.uint(1000), // min balance
          Cl.uint(3000) // 30% max allocation
        ],
        admin
      );
      expect(addTokenResult.result).toBeOk(Cl.bool(true));

      // Verify token was added
      const tokenInfoResult = simnet.callReadOnlyFn(
        CONTRACTS.vaultMultiToken,
        'get-supported-token',
        [Cl.principal(`${admin}.mock-ft`)],
        admin
      );
      expect(tokenInfoResult.result).toBeSome(
        Cl.tuple({
          enabled: Cl.bool(true),
          weight: Cl.uint(2500),
          strategy: Cl.principal(`${admin}.vault`),
          'risk-rating': Cl.uint(3),
          'min-balance': Cl.uint(1000),
          'max-allocation': Cl.uint(3000)
        })
      );
    });

    it('should reject high-risk tokens', () => {
      // Try to add token with risk rating > 5
      const addTokenResult = simnet.callPublicFn(
        CONTRACTS.vaultMultiToken,
        'add-supported-token',
        [
          Cl.principal(`${admin}.mock-ft`),
          Cl.uint(1000),
          Cl.principal(`${admin}.vault`),
          Cl.uint(6), // Invalid risk rating
          Cl.uint(1000),
          Cl.uint(2000)
        ],
        admin
      );
      expect(addTokenResult.result).toBeErr(Cl.uint(114)); // ERR_RISK_TOO_HIGH
    });

    it('should update token weights for rebalancing', () => {
      // First add a token
      simnet.callPublicFn(
        CONTRACTS.vaultMultiToken,
        'add-supported-token',
        [
          Cl.principal(`${admin}.mock-ft`),
          Cl.uint(2000),
          Cl.principal(`${admin}.vault`),
          Cl.uint(2),
          Cl.uint(1000),
          Cl.uint(2500)
        ],
        admin
      );

      // Update token weight
      const updateWeightResult = simnet.callPublicFn(
        CONTRACTS.vaultMultiToken,
        'update-token-weight',
        [Cl.principal(`${admin}.mock-ft`), Cl.uint(3000)],
        admin
      );
      expect(updateWeightResult.result).toBeOk(Cl.bool(true));
    });

    it('should disable competitor tokens when needed', () => {
      // Add token first
      simnet.callPublicFn(
        CONTRACTS.vaultMultiToken,
        'add-supported-token',
        [
          Cl.principal(`${admin}.mock-ft`),
          Cl.uint(1500),
          Cl.principal(`${admin}.vault`),
          Cl.uint(2),
          Cl.uint(500),
          Cl.uint(2000)
        ],
        admin
      );

      // Disable token
      const disableResult = simnet.callPublicFn(
        CONTRACTS.vaultMultiToken,
        'disable-token',
        [Cl.principal(`${admin}.mock-ft`)],
        admin
      );
      expect(disableResult.result).toBeOk(Cl.bool(true));

      // Verify token is disabled
      const isSupported = simnet.callReadOnlyFn(
        CONTRACTS.vaultMultiToken,
        'is-token-supported',
        [Cl.principal(`${admin}.mock-ft`)],
        admin
      );
      expect(isSupported.result).toBeFalsy();
    });

    it('should get portfolio allocation status', () => {
      const allocationResult = simnet.callReadOnlyFn(
        CONTRACTS.vaultMultiToken,
        'get-portfolio-allocation',
        [],
        admin
      );
      expect(allocationResult.result).toBeOk(
        Cl.tuple({
          'total-tokens': Cl.uint(0),
          'rebalance-enabled': Cl.bool(false),
          'max-tokens': Cl.uint(10)
        })
      );
    });
  });

  describe('Integrated Autonomous System Tests', () => {
    it('should enable full autonomous system post-deployment', () => {
      // Step 1: Enable autonomous fees
      const enableFeesResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-auto-fees-enabled',
        [Cl.bool(true)],
        admin
      );
      expect(enableFeesResult.result).toBeOk(Cl.bool(true));

      // Step 2: Enable autonomous economics
      const enableEconomicsResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-auto-economics-enabled',
        [Cl.bool(true)],
        admin
      );
      expect(enableEconomicsResult.result).toBeOk(Cl.bool(true));

      // Step 3: Enable competitive yield tracking
      const enableTrackingResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-competitive-yield-tracking',
        [Cl.bool(true)],
        admin
      );
      expect(enableTrackingResult.result).toBeOk(Cl.bool(true));

      // Step 4: Configure performance benchmark
      const setBenchmarkResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-performance-benchmark',
        [Cl.uint(550)], // 5.5% competitive benchmark
        admin
      );
      expect(setBenchmarkResult.result).toBeOk(Cl.bool(true));

      // Step 5: Add competitor token for diversification
      const addTokenResult = simnet.callPublicFn(
        CONTRACTS.vaultMultiToken,
        'add-supported-token',
        [
          Cl.principal(`${admin}.mock-ft`),
          Cl.uint(2000), // 20% allocation
          Cl.principal(`${admin}.vault`),
          Cl.uint(2), // Low-medium risk
          Cl.uint(1000),
          Cl.uint(2500) // Max 25% of vault
        ],
        admin
      );
      expect(addTokenResult.result).toBeOk(Cl.bool(true));

      // Verify complete system status
      const statusResult = simnet.callReadOnlyFn(
        CONTRACTS.vault,
        'get-autonomous-economics-status',
        [],
        admin
      );
      expect(statusResult.result).toBeOk(
        Cl.tuple({
          'auto-fees-enabled': Cl.bool(true),
          'auto-economics-enabled': Cl.bool(true),
          'competitive-yield-tracking': Cl.bool(true),
          'performance-benchmark': Cl.uint(550)
        })
      );
    });

    it('should execute full autonomics update cycle', () => {
      // Enable all autonomous features
      simnet.callPublicFn(CONTRACTS.vault, 'set-auto-fees-enabled', [Cl.bool(true)], admin);
      simnet.callPublicFn(CONTRACTS.vault, 'set-auto-economics-enabled', [Cl.bool(true)], admin);
      simnet.callPublicFn(CONTRACTS.vault, 'set-competitive-yield-tracking', [Cl.bool(true)], admin);

      // Execute full autonomics update
      const updateResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'update-autonomics',
        [],
        admin
      );
      expect(updateResult.result).toBeOk(Cl.uint(0)); // Returns utilization ratio
    });
  });

  describe('Authorization and Security', () => {
    it('should restrict admin functions to authorized users only', () => {
      // Non-admin tries to enable autonomous fees
      const unauthorizedResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-auto-fees-enabled',
        [Cl.bool(true)],
        user1 // Not admin
      );
      expect(unauthorizedResult.result).toBeErr(Cl.uint(100)); // ERR_NOT_AUTHORIZED

      // Non-admin tries to add competitor token
      const unauthorizedTokenResult = simnet.callPublicFn(
        CONTRACTS.vaultMultiToken,
        'add-supported-token',
        [
          Cl.principal(`${admin}.mock-ft`),
          Cl.uint(1000),
          Cl.principal(`${admin}.vault`),
          Cl.uint(2),
          Cl.uint(500),
          Cl.uint(1500)
        ],
        user1 // Not admin
      );
      expect(unauthorizedTokenResult.result).toBeErr(Cl.uint(100)); // ERR_NOT_AUTHORIZED
    });

    it('should validate parameter bounds for safety', () => {
      // Try to set invalid utilization thresholds (high <= low)
      const invalidThresholdsResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-util-thresholds',
        [Cl.uint(2000), Cl.uint(8000)], // Wrong order
        admin
      );
      expect(invalidThresholdsResult.result).toBeErr(Cl.uint(106)); // Invalid thresholds

      // Try to set invalid fee bounds (min >= max)
      const invalidBoundsResult = simnet.callPublicFn(
        CONTRACTS.vault,
        'set-fee-bounds',
        [Cl.uint(100), Cl.uint(50)], // Wrong order
        admin
      );
      expect(invalidBoundsResult.result).toBeErr(Cl.uint(107)); // Invalid bounds
    });
  });
});
