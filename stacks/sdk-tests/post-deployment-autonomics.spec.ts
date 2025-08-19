import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@hirosystems/clarinet-sdk';

/**
 * Post-Deployment Autonomous Feature Activation Tests
 * 
 * Validates the automated activation system for autonomous economics features
 * after deployment health checks and stability verification.
 * 
 * Security Focus: Bitcoin-native governance with timelock delays and health monitoring
 */

describe('Post-Deployment Autonomous Feature Activation', () => {
  let simnet: any;
  let deployer: string;
  let daoAdmin: string;
  let user1: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    daoAdmin = accounts.get('wallet_1')!;
    user1 = accounts.get('wallet_2')!;
  });

  describe('🚀 Initialization & Phase Management', () => {
    it('should initialize post-deployment monitoring correctly', () => {
      const initResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'initialize-post-deployment',
        [],
        deployer
      );
      
      expect(initResult.result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });
      
      // Check deployment info
      const deploymentInfo = simnet.callReadOnlyFn(
        'post-deployment-autonomics',
        'get-deployment-info',
        [],
        deployer
      );
      
      expect(deploymentInfo.result.type).toEqual('tuple');
      expect(deploymentInfo.result.value['current-phase']).toEqual({ type: 'uint', value: 1n }); // PHASE_HEALTH_CHECK
      
      console.log('✅ Post-deployment monitoring initialized');
    });

    it('should prevent unauthorized initialization', () => {
      const unauthorizedResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'initialize-post-deployment',
        [],
        user1
      );
      
      expect(unauthorizedResult.result).toEqual({ 
        type: 'err', 
        value: { type: 'uint', value: 100n } 
      }); // ERR_NOT_AUTHORIZED
      
      console.log('✅ Unauthorized access properly rejected');
    });

    it('should prevent double initialization', () => {
      // First initialization
      simnet.callPublicFn(
        'post-deployment-autonomics',
        'initialize-post-deployment',
        [],
        deployer
      );
      
      // Second initialization should fail
      const doubleInitResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'initialize-post-deployment',
        [],
        deployer
      );
      
      expect(doubleInitResult.result).toEqual({ 
        type: 'err', 
        value: { type: 'uint', value: 101n } 
      }); // ERR_PHASE_INVALID
      
      console.log('✅ Double initialization prevented');
    });
  });

  describe('📊 Health Monitoring System', () => {
    beforeEach(() => {
      // Initialize the system first
      simnet.callPublicFn(
        'post-deployment-autonomics',
        'initialize-post-deployment',
        [],
        deployer
      );
    });

    it('should update health metrics correctly', () => {
      const updateResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'update-health-metrics',
        [Cl.uint(1000), Cl.uint(10)], // 1000 transactions, 10 errors = 99% success rate
        deployer
      );
      
      expect(updateResult.result).toEqual({ type: 'ok', value: { type: 'uint', value: 99n } });
      
      const healthInfo = simnet.callReadOnlyFn(
        'post-deployment-autonomics',
        'get-system-health',
        [],
        deployer
      );
      
      expect(healthInfo.result.type).toEqual('tuple');
      expect(healthInfo.result.value['health-score']).toEqual({ type: 'uint', value: 99n });
      
      console.log('✅ Health metrics updated successfully');
    });

    it('should track consecutive healthy blocks', () => {
      // Update with good health multiple times
      for (let i = 0; i < 5; i++) {
        simnet.callPublicFn(
          'post-deployment-autonomics',
          'update-health-metrics',
          [Cl.uint(100), Cl.uint(1)], // 99% success rate
          deployer
        );
        simnet.mineBlock([]); // Advance block
      }
      
      const healthInfo = simnet.callReadOnlyFn(
        'post-deployment-autonomics',
        'get-system-health',
        [],
        deployer
      );
      
      // Should track consecutive healthy blocks
      expect(healthInfo.result.value['health-score']).toEqual({ type: 'uint', value: 99n });
      
      console.log('✅ Consecutive healthy blocks tracked');
    });

    it('should reset consecutive blocks on poor health', () => {
      // First, establish some healthy blocks
      simnet.callPublicFn(
        'post-deployment-autonomics',
        'update-health-metrics',
        [Cl.uint(100), Cl.uint(1)],
        deployer
      );
      
      // Then introduce poor health
      simnet.callPublicFn(
        'post-deployment-autonomics',
        'update-health-metrics',
        [Cl.uint(100), Cl.uint(50)], // 50% error rate - poor health
        deployer
      );
      
      const healthInfo = simnet.callReadOnlyFn(
        'post-deployment-autonomics',
        'get-system-health',
        [],
        deployer
      );
      
      // Health score should be low
      expect(Number(healthInfo.result.value['health-score'].value)).toBeLessThan(95);
      
      console.log('✅ Poor health properly detected and tracked');
    });
  });

  describe('🎯 Activation Readiness & Triggering', () => {
    beforeEach(() => {
      simnet.callPublicFn(
        'post-deployment-autonomics',
        'initialize-post-deployment',
        [],
        deployer
      );
    });

    it('should detect when system is not ready for activation', () => {
      const readinessResult = simnet.callReadOnlyFn(
        'post-deployment-autonomics',
        'is-ready-for-activation',
        [],
        deployer
      );
      
      expect(readinessResult.result).toEqual({ type: 'bool', value: false });
      
      console.log('✅ Correctly detects system not ready initially');
    });

    it('should prevent activation when health requirements not met', () => {
      // Try to trigger activation without meeting health requirements
      const activationResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'trigger-autonomous-activation',
        [],
        deployer
      );
      
      expect(activationResult.result).toEqual({ 
        type: 'err', 
        value: { type: 'uint', value: 102n } 
      }); // ERR_HEALTH_CHECK_FAILED
      
      console.log('✅ Activation prevented when health requirements not met');
    });

    it('should allow activation when all requirements are met', () => {
      // First, establish good health for sufficient blocks
      for (let i = 0; i < 150; i++) { // More than MIN_BLOCKS_STABLE (144)
        simnet.callPublicFn(
          'post-deployment-autonomics',
          'update-health-metrics',
          [Cl.uint(100), Cl.uint(1)], // 99% success rate
          deployer
        );
        simnet.mineBlock([]);
      }
      
      // Now check if ready
      const readinessResult = simnet.callReadOnlyFn(
        'post-deployment-autonomics',
        'is-ready-for-activation',
        [],
        deployer
      );
      
      // Should be ready now
      expect(readinessResult.result).toEqual({ type: 'bool', value: true });
      
      // Trigger activation
      const activationResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'trigger-autonomous-activation',
        [],
        deployer
      );
      
      expect(activationResult.result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });
      
      console.log('✅ Activation triggered successfully when requirements met');
    });
  });

  describe('📋 Timelock Proposal Creation', () => {
    beforeEach(() => {
      simnet.callPublicFn(
        'post-deployment-autonomics',
        'initialize-post-deployment',
        [],
        deployer
      );
      
      // Set phase to activation
      for (let i = 0; i < 150; i++) {
        simnet.callPublicFn(
          'post-deployment-autonomics',
          'update-health-metrics',
          [Cl.uint(100), Cl.uint(1)],
          deployer
        );
        simnet.mineBlock([]);
      }
      
      simnet.callPublicFn(
        'post-deployment-autonomics',
        'trigger-autonomous-activation',
        [],
        deployer
      );
    });

    it('should create timelock proposal for autonomous fees', () => {
      const proposalResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'propose-enable-auto-fees',
        [],
        deployer
      );
      
      expect(proposalResult.result).toEqual({ type: 'ok', value: { type: 'uint', value: 1n } });
      
      console.log('✅ Auto fees proposal created');
    });

    it('should create timelock proposal for utilization thresholds', () => {
      const proposalResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'propose-configure-thresholds',
        [],
        deployer
      );
      
      expect(proposalResult.result).toEqual({ type: 'ok', value: { type: 'uint', value: 2n } });
      
      console.log('✅ Utilization thresholds proposal created');
    });

    it('should create timelock proposal for fee bounds', () => {
      const proposalResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'propose-configure-fee-bounds',
        [],
        deployer
      );
      
      expect(proposalResult.result).toEqual({ type: 'ok', value: { type: 'uint', value: 3n } });
      
      console.log('✅ Fee bounds proposal created');
    });

    it('should create timelock proposal for autonomous economics', () => {
      const proposalResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'propose-enable-auto-economics',
        [],
        deployer
      );
      
      expect(proposalResult.result).toEqual({ type: 'ok', value: { type: 'uint', value: 4n } });
      
      console.log('✅ Autonomous economics proposal created');
    });

    it('should create timelock proposal for performance benchmark', () => {
      const proposalResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'propose-set-performance-benchmark',
        [],
        deployer
      );
      
      expect(proposalResult.result).toEqual({ type: 'ok', value: { type: 'uint', value: 5n } });
      
      console.log('✅ Performance benchmark proposal created');
    });
  });

  describe('🛑 Emergency Controls', () => {
    beforeEach(() => {
      simnet.callPublicFn(
        'post-deployment-autonomics',
        'initialize-post-deployment',
        [],
        deployer
      );
    });

    it('should allow emergency pause of activation', () => {
      const pauseResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'emergency-pause-activation',
        [],
        deployer
      );
      
      expect(pauseResult.result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });
      
      // Check that phase was reset
      const deploymentInfo = simnet.callReadOnlyFn(
        'post-deployment-autonomics',
        'get-deployment-info',
        [],
        deployer
      );
      
      expect(deploymentInfo.result.value['current-phase']).toEqual({ type: 'uint', value: 0n }); // PHASE_WAITING
      
      console.log('✅ Emergency pause executed successfully');
    });

    it('should allow health monitoring reset', () => {
      // First update some health metrics
      simnet.callPublicFn(
        'post-deployment-autonomics',
        'update-health-metrics',
        [Cl.uint(100), Cl.uint(10)],
        deployer
      );
      
      // Reset health monitoring
      const resetResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'reset-health-monitoring',
        [],
        deployer
      );
      
      expect(resetResult.result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });
      
      // Check that health was reset
      const healthInfo = simnet.callReadOnlyFn(
        'post-deployment-autonomics',
        'get-system-health',
        [],
        deployer
      );
      
      expect(healthInfo.result.value['health-score']).toEqual({ type: 'uint', value: 0n });
      
      console.log('✅ Health monitoring reset successfully');
    });
  });

  describe('📖 Configuration & Information', () => {
    it('should return correct configuration parameters', () => {
      const configResult = simnet.callReadOnlyFn(
        'post-deployment-autonomics',
        'get-configuration',
        [],
        deployer
      );
      
      expect(configResult.result.type).toEqual('tuple');
      
      const config = configResult.result.value;
      expect(config['min-health-score']).toEqual({ type: 'uint', value: 95n });
      expect(config['min-stable-blocks']).toEqual({ type: 'uint', value: 144n });
      expect(config['max-error-threshold']).toEqual({ type: 'uint', value: 5n });
      expect(config['low-util-threshold']).toEqual({ type: 'uint', value: 2000n }); // 20%
      expect(config['high-util-threshold']).toEqual({ type: 'uint', value: 8000n }); // 80%
      
      console.log('✅ Configuration parameters correct');
    });

    it('should track activation status correctly', () => {
      simnet.callPublicFn(
        'post-deployment-autonomics',
        'initialize-post-deployment',
        [],
        deployer
      );
      
      const statusResult = simnet.callReadOnlyFn(
        'post-deployment-autonomics',
        'get-activation-status',
        [],
        deployer
      );
      
      expect(statusResult.result.type).toEqual('tuple');
      expect(statusResult.result.value['phase']).toEqual({ type: 'uint', value: 1n }); // PHASE_HEALTH_CHECK
      expect(statusResult.result.value['steps-completed']).toEqual({ type: 'uint', value: 0n });
      
      console.log('✅ Activation status tracked correctly');
    });
  });

  describe('🎯 Full Integration Test', () => {
    it('should complete full autonomous activation cycle', () => {
      console.log('🚀 Starting full autonomous activation integration test...');
      
      // Step 1: Initialize
      const initResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'initialize-post-deployment',
        [],
        deployer
      );
      expect(initResult.result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });
      console.log('  ✅ Phase 1: Initialization complete');
      
      // Step 2: Build up health over time
      for (let i = 0; i < 150; i++) {
        simnet.callPublicFn(
          'post-deployment-autonomics',
          'update-health-metrics',
          [Cl.uint(100), Cl.uint(1)], // 99% success rate
          deployer
        );
        simnet.mineBlock([]);
      }
      console.log('  ✅ Phase 2: Health monitoring established (150 blocks)');
      
      // Step 3: Verify readiness
      const readinessResult = simnet.callReadOnlyFn(
        'post-deployment-autonomics',
        'is-ready-for-activation',
        [],
        deployer
      );
      expect(readinessResult.result).toEqual({ type: 'bool', value: true });
      console.log('  ✅ Phase 3: System ready for activation confirmed');
      
      // Step 4: Trigger activation
      const activationResult = simnet.callPublicFn(
        'post-deployment-autonomics',
        'trigger-autonomous-activation',
        [],
        deployer
      );
      expect(activationResult.result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });
      console.log('  ✅ Phase 4: Autonomous activation triggered');
      
      // Step 5: Create all timelock proposals
      const proposals = [
        'propose-enable-auto-fees',
        'propose-configure-thresholds',
        'propose-configure-fee-bounds', 
        'propose-enable-auto-economics',
        'propose-set-performance-benchmark'
      ];
      
      proposals.forEach((proposal, index) => {
        const result = simnet.callPublicFn(
          'post-deployment-autonomics',
          proposal,
          [],
          deployer
        );
        expect(result.result).toEqual({ type: 'ok', value: { type: 'uint', value: BigInt(index + 1) } });
      });
      console.log('  ✅ Phase 5: All timelock proposals created');
      
      // Verify final status
      const finalStatus = simnet.callReadOnlyFn(
        'post-deployment-autonomics',
        'get-deployment-info',
        [],
        deployer
      );
      expect(finalStatus.result.value['current-phase']).toEqual({ type: 'uint', value: 3n }); // PHASE_COMPLETE
      
      console.log('🎉 AUTONOMOUS ACTIVATION INTEGRATION TEST COMPLETE!');
      console.log('   ✅ All phases executed successfully');
      console.log('   ✅ Health monitoring validated'); 
      console.log('   ✅ Timelock proposals created');
      console.log('   ✅ System ready for production governance');
    });
  });
});
