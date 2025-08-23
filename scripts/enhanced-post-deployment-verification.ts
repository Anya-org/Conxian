#!/usr/bin/env ts-node

/**
 * Enhanced Post-Deployment Verification System
 * Comprehensive validation of deployed AutoVault contracts
 * Covers: Performance, Security, Functionality, Production Readiness
 */

import { fetchCallReadOnlyFunction, cvToValue, principalCV, uintCV, stringAsciiCV } from '@stacks/transactions';
import { STACKS_TESTNET, STACKS_MAINNET } from '@stacks/network';
import 'dotenv/config';
import * as fs from 'fs';
import * as path from 'path';

// Configuration
interface VerificationConfig {
  network: any;
  networkName: string;
  deployerAddr: string;
  contracts: Record<string, string>;
  performanceTargets: Record<string, number>;
  securityRequirements: Record<string, any>;
}

interface VerificationResult {
  testName: string;
  status: 'PASS' | 'FAIL' | 'WARN';
  details: any;
  timestamp: Date;
}

interface ContractFunction {
  contractAddress: string;
  contractName: string;
  functionName: string;
  functionArgs?: any[];
  senderAddress?: string;
}

class EnhancedPostDeploymentVerifier {
  private config: VerificationConfig;
  private results: VerificationResult[] = [];
  private errors: string[] = [];
  private warnings: string[] = [];

  constructor() {
    const networkName = (process.env.NETWORK || 'testnet').toLowerCase();
    const deployerAddr = process.env.DEPLOYER_ADDR || 'SP000000000000000000002Q6VF78';

    this.config = {
  network: networkName === 'mainnet' ? STACKS_MAINNET : STACKS_TESTNET,
      networkName,
      deployerAddr,
      contracts: {
        vault: `${deployerAddr}.vault-enhanced`,
        vaultLegacy: `${deployerAddr}.vault`,
        oracle: `${deployerAddr}.oracle-aggregator-enhanced`,
        dexFactory: `${deployerAddr}.dex-factory-enhanced`,
        batchProcessor: `${deployerAddr}.enhanced-batch-processing`,
        cachingSystem: `${deployerAddr}.advanced-caching-system`,
        loadDistribution: `${deployerAddr}.dynamic-load-distribution`,
        timelock: `${deployerAddr}.timelock`,
        dao: `${deployerAddr}.dao`,
        govToken: `${deployerAddr}.gov-token`,
        treasury: `${deployerAddr}.treasury`,
      },
      performanceTargets: {
        batchProcessingTps: 180000,
        cachingSystemTps: 40000,
        loadDistributionTps: 35000,
        vaultEnhancedTps: 200000,
        oracleAggregatorTps: 50000,
        dexFactoryTps: 50000,
        totalTargetTps: 735000,
        successRateMin: 97,
        responseTimeMax: 1000,
      },
      securityRequirements: {
        adminMultisig: true,
        timelockEnabled: true,
        emergencyPause: true,
        inputValidation: true,
        accessControls: true,
      },
    };

  // Try to load deployment registry overrides if provided
  this.loadDeploymentRegistry();
  }

  // =============================================================================
  // CORE VERIFICATION UTILITIES
  // =============================================================================

  private loadDeploymentRegistry() {
    try {
      const registryPath = process.env.DEPLOYMENT_REGISTRY;
      if (!registryPath) return;
      const fullPath = path.isAbsolute(registryPath)
        ? registryPath
        : path.resolve(process.cwd(), registryPath);
      if (!fs.existsSync(fullPath)) return;

      const data = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
      const contracts = data?.contracts || {};

      const getId = (key: string): string | undefined => contracts[key]?.contract_id;
      const setIf = (cfgKey: keyof VerificationConfig['contracts'], ...candidates: string[]) => {
        for (const name of candidates) {
          const id = getId(name);
          if (id) {
            this.config.contracts[cfgKey] = id;
            return;
          }
        }
      };

      setIf('vault', 'vault-enhanced', 'vault');
      setIf('oracle', 'oracle-aggregator-enhanced', 'oracle-aggregator');
      setIf('dexFactory', 'dex-factory-enhanced', 'dex-factory');
      setIf('batchProcessor', 'enhanced-batch-processing', 'batch-processing');
      setIf('cachingSystem', 'advanced-caching-system', 'caching-system');
      setIf('loadDistribution', 'dynamic-load-distribution', 'load-distribution');
      setIf('timelock', 'timelock');
      setIf('dao', 'dao', 'dao-governance');
      setIf('govToken', 'gov-token');
      setIf('treasury', 'treasury');

      // Update deployer address from any contract id if available
      const anyId: string | undefined = Object.values(this.config.contracts)[0];
      if (anyId && anyId.includes('.')) {
        this.config.deployerAddr = anyId.split('.')[0];
      }
      console.log(`Using deployment registry: ${fullPath}`);
    } catch (e) {
      this.warnings.push(`Failed to load deployment registry: ${(e as Error).message}`);
    }
  }

  private async callReadOnly(func: ContractFunction): Promise<any> {
    try {
      const [contractAddress, contractName] = func.contractAddress.split('.');
      const response = await fetchCallReadOnlyFunction({
        contractAddress,
        contractName,
        functionName: func.functionName,
        functionArgs: func.functionArgs || [],
        network: this.config.network,
        senderAddress: func.senderAddress || contractAddress,
      });
      return cvToValue(response);
    } catch (error) {
      throw new Error(`Failed to call ${func.contractAddress}.${func.functionName}: ${error}`);
    }
  }

  private recordResult(testName: string, status: 'PASS' | 'FAIL' | 'WARN', details: any = {}) {
    const result: VerificationResult = {
      testName,
      status,
      details,
      timestamp: new Date(),
    };

    this.results.push(result);

    if (status === 'FAIL') {
      this.errors.push(`${testName}: ${JSON.stringify(details)}`);
    } else if (status === 'WARN') {
      this.warnings.push(`${testName}: ${JSON.stringify(details)}`);
    }

    console.log(`[${status}] ${testName}:`, details);
  }

  private async contractExists(contractAddr: string): Promise<boolean> {
    try {
      const [address, name] = contractAddr.split('.');
  const response = await fetchCallReadOnlyFunction({
        contractAddress: address,
        contractName: name,
        functionName: 'get-contract-info',
        functionArgs: [],
        network: this.config.network,
        senderAddress: address,
      });
      return response !== null;
    } catch {
      return false;
    }
  }

  // =============================================================================
  // CONTRACT EXISTENCE VERIFICATION
  // =============================================================================

  async verifyContractDeployments(): Promise<void> {
    console.log('\n📋 Verifying Contract Deployments...');

    for (const [contractType, contractAddr] of Object.entries(this.config.contracts)) {
      const exists = await this.contractExists(contractAddr);
      if (exists) {
        this.recordResult(`Contract Deployment: ${contractType}`, 'PASS', { address: contractAddr });
      } else {
        this.recordResult(`Contract Deployment: ${contractType}`, 'FAIL', { 
          address: contractAddr, 
          error: 'Contract not found on network' 
        });
      }
    }
  }

  // =============================================================================
  // ENHANCED VAULT VERIFICATION
  // =============================================================================

  async verifyEnhancedVault(): Promise<void> {
    console.log('\n🏦 Verifying Enhanced Vault...');

    try {
      // Check if enhanced vault exists
      const vaultExists = await this.contractExists(this.config.contracts.vault);
      if (!vaultExists) {
        this.recordResult('Enhanced Vault: Deployment', 'FAIL', { error: 'Enhanced vault not deployed' });
        return;
      }

      // Verify admin configuration
      const adminResult = await this.callReadOnly({
        contractAddress: this.config.contracts.vault,
        contractName: 'vault-enhanced',
        functionName: 'get-admin',
      });

      if (adminResult?.ok) {
        this.recordResult('Enhanced Vault: Admin Configuration', 'PASS', { admin: adminResult.value });
      } else {
        this.recordResult('Enhanced Vault: Admin Configuration', 'FAIL', { error: 'Admin not properly configured' });
      }

      // Verify fee configuration
      const feesResult = await this.callReadOnly({
        contractAddress: this.config.contracts.vault,
        contractName: 'vault-enhanced',
        functionName: 'get-fees',
      });

      if (feesResult?.ok) {
        this.recordResult('Enhanced Vault: Fee Configuration', 'PASS', { fees: feesResult.value });
      } else {
        this.recordResult('Enhanced Vault: Fee Configuration', 'WARN', { warning: 'Fee configuration may be missing' });
      }

      // Verify batch processing integration
      const batchLimitsResult = await this.callReadOnly({
        contractAddress: this.config.contracts.vault,
        contractName: 'vault-enhanced',
        functionName: 'get-batch-limits',
      });

      if (batchLimitsResult?.ok && batchLimitsResult.value?.['max-batch-size'] >= 50) {
        this.recordResult('Enhanced Vault: Batch Processing', 'PASS', { 
          batchLimits: batchLimitsResult.value,
          expectedTps: this.config.performanceTargets.vaultEnhancedTps
        });
      } else {
        this.recordResult('Enhanced Vault: Batch Processing', 'FAIL', { 
          error: 'Batch processing not properly configured',
          actual: batchLimitsResult?.value,
          required: { 'max-batch-size': 50 }
        });
      }

      // Verify caching integration
      const cacheStatsResult = await this.callReadOnly({
        contractAddress: this.config.contracts.vault,
        contractName: 'vault-enhanced',
        functionName: 'get-cache-stats',
      });

      if (cacheStatsResult?.ok) {
        this.recordResult('Enhanced Vault: Caching Integration', 'PASS', { cacheStats: cacheStatsResult.value });
      } else {
        this.recordResult('Enhanced Vault: Caching Integration', 'WARN', { warning: 'Cache statistics not available' });
      }

      // Verify pause mechanism
      const pausedResult = await this.callReadOnly({
        contractAddress: this.config.contracts.vault,
        contractName: 'vault-enhanced',
        functionName: 'get-paused',
      });

      if (pausedResult?.ok !== undefined) {
        this.recordResult('Enhanced Vault: Emergency Controls', 'PASS', { paused: pausedResult.value });
      } else {
        this.recordResult('Enhanced Vault: Emergency Controls', 'FAIL', { error: 'Emergency pause mechanism not found' });
      }

    } catch (error: any) {
      this.recordResult('Enhanced Vault: Verification', 'FAIL', { error: error?.message || 'Unknown error' });
    }
  }

  // =============================================================================
  // BATCH PROCESSING VERIFICATION
  // =============================================================================

  async verifyBatchProcessing(): Promise<void> {
    console.log('\n⚡ Verifying Batch Processing System...');

    try {
      const batchExists = await this.contractExists(this.config.contracts.batchProcessor);
      if (!batchExists) {
        this.recordResult('Batch Processing: Deployment', 'FAIL', { error: 'Batch processor not deployed' });
        return;
      }

      // Verify batch limits
      const batchLimitsResult = await this.callReadOnly({
        contractAddress: this.config.contracts.batchProcessor,
        contractName: 'enhanced-batch-processing',
        functionName: 'get-batch-limits',
      });

      if (batchLimitsResult?.ok) {
        const maxBatchSize = batchLimitsResult.value?.['max-batch-size'] || 0;
        if (maxBatchSize >= 100) {
          this.recordResult('Batch Processing: Capacity', 'PASS', { 
            maxBatchSize,
            targetTps: this.config.performanceTargets.batchProcessingTps
          });
        } else {
          this.recordResult('Batch Processing: Capacity', 'FAIL', { 
            maxBatchSize,
            required: 100,
            impact: 'May not achieve target TPS'
          });
        }
      }

      // Verify batch processing statistics
      const batchStatsResult = await this.callReadOnly({
        contractAddress: this.config.contracts.batchProcessor,
        contractName: 'enhanced-batch-processing',
        functionName: 'get-batch-stats',
      });

      if (batchStatsResult?.ok) {
        this.recordResult('Batch Processing: Statistics', 'PASS', { stats: batchStatsResult.value });
      } else {
        this.recordResult('Batch Processing: Statistics', 'WARN', { warning: 'Batch statistics not available' });
      }

    } catch (error: any) {
      this.recordResult('Batch Processing: Verification', 'FAIL', { error: error?.message || 'Unknown error' });
    }
  }

  // =============================================================================
  // CACHING SYSTEM VERIFICATION
  // =============================================================================

  async verifyCachingSystem(): Promise<void> {
    console.log('\n🗄️ Verifying Advanced Caching System...');

    try {
      const cacheExists = await this.contractExists(this.config.contracts.cachingSystem);
      if (!cacheExists) {
        this.recordResult('Caching System: Deployment', 'FAIL', { error: 'Caching system not deployed' });
        return;
      }

      // Verify cache configuration
      const cacheConfigResult = await this.callReadOnly({
        contractAddress: this.config.contracts.cachingSystem,
        contractName: 'advanced-caching-system',
        functionName: 'get-cache-config',
      });

      if (cacheConfigResult?.ok) {
        this.recordResult('Caching System: Configuration', 'PASS', { config: cacheConfigResult.value });
      } else {
        this.recordResult('Caching System: Configuration', 'WARN', { warning: 'Cache configuration not accessible' });
      }

      // Verify cache statistics
      const cacheStatsResult = await this.callReadOnly({
        contractAddress: this.config.contracts.cachingSystem,
        contractName: 'advanced-caching-system',
        functionName: 'get-cache-stats',
      });

      if (cacheStatsResult?.ok) {
        const hitRate = cacheStatsResult.value?.['hit-rate'] || 0;
        if (hitRate >= 80) {
          this.recordResult('Caching System: Performance', 'PASS', { 
            hitRate,
            targetTps: this.config.performanceTargets.cachingSystemTps
          });
        } else {
          this.recordResult('Caching System: Performance', 'WARN', { 
            hitRate,
            warning: 'Cache hit rate below optimal (80%+)'
          });
        }
      }

      // Test cache functionality
      const testCacheResult = await this.callReadOnly({
        contractAddress: this.config.contracts.cachingSystem,
        contractName: 'advanced-caching-system',
        functionName: 'get-cached-data',
        functionArgs: [stringAsciiCV('test-key')],
      });

      // Cache miss is expected for test key
      this.recordResult('Caching System: Functionality', 'PASS', { 
        cacheTest: 'Cache lookup functional',
        result: testCacheResult 
      });

    } catch (error: any) {
      this.recordResult('Caching System: Verification', 'FAIL', { error: error?.message || 'Unknown error' });
    }
  }

  // =============================================================================
  // LOAD DISTRIBUTION VERIFICATION
  // =============================================================================

  async verifyLoadDistribution(): Promise<void> {
    console.log('\n⚖️ Verifying Load Distribution System...');

    try {
      const loadExists = await this.contractExists(this.config.contracts.loadDistribution);
      if (!loadExists) {
        this.recordResult('Load Distribution: Deployment', 'FAIL', { error: 'Load distribution not deployed' });
        return;
      }

      // Verify load metrics
      const loadMetricsResult = await this.callReadOnly({
        contractAddress: this.config.contracts.loadDistribution,
        contractName: 'dynamic-load-distribution',
        functionName: 'get-load-metrics',
      });

      if (loadMetricsResult?.ok) {
        this.recordResult('Load Distribution: Metrics', 'PASS', { 
          metrics: loadMetricsResult.value,
          targetTps: this.config.performanceTargets.loadDistributionTps
        });
      } else {
        this.recordResult('Load Distribution: Metrics', 'WARN', { warning: 'Load metrics not available' });
      }

      // Verify node selection functionality
      const nodeSelectionResult = await this.callReadOnly({
        contractAddress: this.config.contracts.loadDistribution,
        contractName: 'dynamic-load-distribution',
        functionName: 'select-optimal-node',
        functionArgs: [stringAsciiCV('test-service')],
      });

      if (nodeSelectionResult?.ok) {
        this.recordResult('Load Distribution: Node Selection', 'PASS', { 
          selectedNode: nodeSelectionResult.value 
        });
      } else {
        this.recordResult('Load Distribution: Node Selection', 'FAIL', { 
          error: 'Node selection not functional' 
        });
      }

    } catch (error: any) {
      this.recordResult('Load Distribution: Verification', 'FAIL', { error: error?.message || 'Unknown error' });
    }
  }

  // =============================================================================
  // ORACLE AGGREGATOR VERIFICATION
  // =============================================================================

  async verifyOracleAggregator(): Promise<void> {
    console.log('\n🔮 Verifying Enhanced Oracle Aggregator...');

    try {
      const oracleExists = await this.contractExists(this.config.contracts.oracle);
      if (!oracleExists) {
        this.recordResult('Oracle Aggregator: Deployment', 'FAIL', { error: 'Oracle aggregator not deployed' });
        return;
      }

      // Verify oracle configuration
      const oracleConfigResult = await this.callReadOnly({
        contractAddress: this.config.contracts.oracle,
        contractName: 'oracle-aggregator-enhanced',
        functionName: 'get-oracle-config',
      });

      if (oracleConfigResult?.ok) {
        this.recordResult('Oracle Aggregator: Configuration', 'PASS', { config: oracleConfigResult.value });
      } else {
        this.recordResult('Oracle Aggregator: Configuration', 'WARN', { warning: 'Oracle configuration not accessible' });
      }

      // Verify oracle statistics
      const oracleStatsResult = await this.callReadOnly({
        contractAddress: this.config.contracts.oracle,
        contractName: 'oracle-aggregator-enhanced',
        functionName: 'get-oracle-stats',
      });

      if (oracleStatsResult?.ok) {
        this.recordResult('Oracle Aggregator: Statistics', 'PASS', { 
          stats: oracleStatsResult.value,
          targetTps: this.config.performanceTargets.oracleAggregatorTps
        });
      } else {
        this.recordResult('Oracle Aggregator: Statistics', 'WARN', { warning: 'Oracle statistics not available' });
      }

      // Test price caching functionality
      const cachedPriceResult = await this.callReadOnly({
        contractAddress: this.config.contracts.oracle,
        contractName: 'oracle-aggregator-enhanced',
        functionName: 'get-cached-price',
        functionArgs: [stringAsciiCV('BTC-STX')],
      });

      if (cachedPriceResult?.ok || cachedPriceResult?.error) {
        this.recordResult('Oracle Aggregator: Price Caching', 'PASS', { 
          priceCache: 'Functional',
          result: cachedPriceResult 
        });
      } else {
        this.recordResult('Oracle Aggregator: Price Caching', 'FAIL', { 
          error: 'Price caching not functional' 
        });
      }

    } catch (error: any) {
      this.recordResult('Oracle Aggregator: Verification', 'FAIL', { error: error?.message || 'Unknown error' });
    }
  }

  // =============================================================================
  // DEX FACTORY VERIFICATION
  // =============================================================================

  async verifyDexFactory(): Promise<void> {
    console.log('\n🏭 Verifying Enhanced DEX Factory...');

    try {
      const dexExists = await this.contractExists(this.config.contracts.dexFactory);
      if (!dexExists) {
        this.recordResult('DEX Factory: Deployment', 'FAIL', { error: 'DEX factory not deployed' });
        return;
      }

      // Verify factory statistics
      const factoryStatsResult = await this.callReadOnly({
        contractAddress: this.config.contracts.dexFactory,
        contractName: 'dex-factory-enhanced',
        functionName: 'get-factory-stats',
      });

      if (factoryStatsResult?.ok) {
        this.recordResult('DEX Factory: Statistics', 'PASS', { 
          stats: factoryStatsResult.value,
          targetTps: this.config.performanceTargets.dexFactoryTps
        });
      } else {
        this.recordResult('DEX Factory: Statistics', 'WARN', { warning: 'Factory statistics not available' });
      }

      // Test pool recommendation functionality
      const poolRecommendationResult = await this.callReadOnly({
        contractAddress: this.config.contracts.dexFactory,
        contractName: 'dex-factory-enhanced',
        functionName: 'recommend-pool',
        functionArgs: [
          principalCV('SP000000000000000000002Q6VF78.test-token-a'),
          principalCV('SP000000000000000000002Q6VF78.test-token-b'),
          uintCV(1000)
        ],
      });

      if (poolRecommendationResult) {
        this.recordResult('DEX Factory: Pool Recommendation', 'PASS', { 
          recommendation: poolRecommendationResult 
        });
      } else {
        this.recordResult('DEX Factory: Pool Recommendation', 'WARN', { 
          warning: 'Pool recommendation may need pool data' 
        });
      }

    } catch (error: any) {
      this.recordResult('DEX Factory: Verification', 'FAIL', { error: error?.message || 'Unknown error' });
    }
  }

  // =============================================================================
  // SECURITY VERIFICATION
  // =============================================================================

  async verifySecurityControls(): Promise<void> {
    console.log('\n🔒 Verifying Security Controls...');

    // Verify timelock integration
    try {
      const timelockExists = await this.contractExists(this.config.contracts.timelock);
      if (timelockExists) {
        const timelockConfigResult = await this.callReadOnly({
          contractAddress: this.config.contracts.timelock,
          contractName: 'timelock',
          functionName: 'get-min-delay',
        });

        if (timelockConfigResult?.ok && timelockConfigResult.value > 0) {
          this.recordResult('Security: Timelock Integration', 'PASS', { 
            minDelay: timelockConfigResult.value 
          });
        } else {
          this.recordResult('Security: Timelock Integration', 'FAIL', { 
            error: 'Timelock not properly configured' 
          });
        }
      } else {
        this.recordResult('Security: Timelock Integration', 'FAIL', { 
          error: 'Timelock contract not deployed' 
        });
      }
    } catch (error: any) {
      this.recordResult('Security: Timelock Integration', 'FAIL', { error: error?.message || 'Unknown error' });
    }

    // Verify admin controls in enhanced contracts
    for (const [contractType, contractAddr] of Object.entries(this.config.contracts)) {
      if (contractType.includes('enhanced') || contractType === 'vault') {
        try {
          const adminResult = await this.callReadOnly({
            contractAddress: contractAddr,
            contractName: contractAddr.split('.')[1],
            functionName: 'get-admin',
          });

          if (adminResult?.ok) {
            this.recordResult(`Security: ${contractType} Admin Control`, 'PASS', { 
              admin: adminResult.value 
            });
          } else {
            this.recordResult(`Security: ${contractType} Admin Control`, 'WARN', { 
              warning: 'Admin control not accessible' 
            });
          }
        } catch (error) {
          this.recordResult(`Security: ${contractType} Admin Control`, 'WARN', { 
            warning: 'Could not verify admin control' 
          });
        }
      }
    }
  }

  // =============================================================================
  // PERFORMANCE VERIFICATION
  // =============================================================================

  async verifyPerformanceTargets(): Promise<void> {
    console.log('\n🚀 Verifying Performance Targets...');

    const performanceResults = {
      batchProcessing: 0,
      caching: 0,
      loadDistribution: 0,
      vault: 0,
      oracle: 0,
      dex: 0,
    };

    // Estimate TPS based on contract capabilities
    try {
      // Batch processing TPS estimation
      const batchLimitsResult = await this.callReadOnly({
        contractAddress: this.config.contracts.batchProcessor,
        contractName: 'enhanced-batch-processing',
        functionName: 'get-batch-limits',
      });

      if (batchLimitsResult?.ok) {
        const maxBatchSize = batchLimitsResult.value?.['max-batch-size'] || 0;
        performanceResults.batchProcessing = maxBatchSize * 1800; // Estimate: batch_size * blocks_per_hour
      }

      // Caching TPS estimation
      const cacheStatsResult = await this.callReadOnly({
        contractAddress: this.config.contracts.cachingSystem,
        contractName: 'advanced-caching-system',
        functionName: 'get-cache-stats',
      });

      if (cacheStatsResult?.ok) {
        const hitRate = cacheStatsResult.value?.['hit-rate'] || 0;
        performanceResults.caching = Math.floor(this.config.performanceTargets.cachingSystemTps * (hitRate / 100));
      }

      // Calculate total estimated TPS
      const totalEstimatedTps = Object.values(performanceResults).reduce((sum, tps) => sum + tps, 0);

      if (totalEstimatedTps >= this.config.performanceTargets.totalTargetTps * 0.8) {
        this.recordResult('Performance: TPS Targets', 'PASS', { 
          estimatedTps: totalEstimatedTps,
          targetTps: this.config.performanceTargets.totalTargetTps,
          breakdown: performanceResults
        });
      } else if (totalEstimatedTps >= this.config.performanceTargets.totalTargetTps * 0.6) {
        this.recordResult('Performance: TPS Targets', 'WARN', { 
          estimatedTps: totalEstimatedTps,
          targetTps: this.config.performanceTargets.totalTargetTps,
          warning: 'Performance below optimal but acceptable',
          breakdown: performanceResults
        });
      } else {
        this.recordResult('Performance: TPS Targets', 'FAIL', { 
          estimatedTps: totalEstimatedTps,
          targetTps: this.config.performanceTargets.totalTargetTps,
          error: 'Performance significantly below targets',
          breakdown: performanceResults
        });
      }

    } catch (error: any) {
      this.recordResult('Performance: TPS Targets', 'FAIL', { error: error?.message || 'Unknown error' });
    }
  }

  // =============================================================================
  // PRODUCTION READINESS VERIFICATION
  // =============================================================================

  async verifyProductionReadiness(): Promise<void> {
    console.log('\n🏭 Verifying Production Readiness...');

    let readinessScore = 0;
    const maxReadinessScore = 10;

    // Check contract deployment completeness
    const deployedContracts = this.results.filter(r => 
      r.testName.includes('Contract Deployment') && r.status === 'PASS'
    ).length;

    if (deployedContracts >= 6) { // Core enhanced contracts
      readinessScore += 3;
      this.recordResult('Production Readiness: Contract Deployment', 'PASS', { 
        deployedContracts,
        requiredContracts: 6
      });
    } else {
      this.recordResult('Production Readiness: Contract Deployment', 'FAIL', { 
        deployedContracts,
        requiredContracts: 6,
        error: 'Missing critical contract deployments'
      });
    }

    // Check security controls
    const securityPassed = this.results.filter(r => 
      r.testName.includes('Security') && r.status === 'PASS'
    ).length;

    if (securityPassed >= 3) {
      readinessScore += 3;
      this.recordResult('Production Readiness: Security Controls', 'PASS', { 
        securityControls: securityPassed
      });
    } else {
      readinessScore += 1;
      this.recordResult('Production Readiness: Security Controls', 'WARN', { 
        securityControls: securityPassed,
        warning: 'Some security controls need verification'
      });
    }

    // Check performance readiness
    const performancePassed = this.results.filter(r => 
      r.testName.includes('Performance') && r.status === 'PASS'
    ).length;

    if (performancePassed >= 1) {
      readinessScore += 2;
      this.recordResult('Production Readiness: Performance', 'PASS', { 
        performanceTests: performancePassed
      });
    } else {
      this.recordResult('Production Readiness: Performance', 'WARN', { 
        performanceTests: performancePassed,
        warning: 'Performance validation needs improvement'
      });
    }

    // Check functional completeness
    const functionalPassed = this.results.filter(r => 
      r.testName.includes('Enhanced') && r.status === 'PASS'
    ).length;

    if (functionalPassed >= 4) {
      readinessScore += 2;
      this.recordResult('Production Readiness: Functionality', 'PASS', { 
        functionalTests: functionalPassed
      });
    } else {
      readinessScore += 1;
      this.recordResult('Production Readiness: Functionality', 'WARN', { 
        functionalTests: functionalPassed,
        warning: 'Some enhanced features need verification'
      });
    }

    // Overall readiness assessment
    const readinessPercentage = Math.floor((readinessScore / maxReadinessScore) * 100);

    if (readinessPercentage >= 90) {
      this.recordResult('Production Readiness: Overall Assessment', 'PASS', { 
        readinessScore: `${readinessPercentage}%`,
        status: 'PRODUCTION READY',
        recommendation: 'System ready for production deployment'
      });
    } else if (readinessPercentage >= 70) {
      this.recordResult('Production Readiness: Overall Assessment', 'WARN', { 
        readinessScore: `${readinessPercentage}%`,
        status: 'NEEDS MINOR FIXES',
        recommendation: 'Address warnings before production deployment'
      });
    } else {
      this.recordResult('Production Readiness: Overall Assessment', 'FAIL', { 
        readinessScore: `${readinessPercentage}%`,
        status: 'NOT PRODUCTION READY',
        recommendation: 'Significant fixes required before production deployment'
      });
    }
  }

  // =============================================================================
  // REPORT GENERATION
  // =============================================================================

  generateDetailedReport(): string {
    const timestamp = new Date().toISOString();
    const passedTests = this.results.filter(r => r.status === 'PASS').length;
    const failedTests = this.results.filter(r => r.status === 'FAIL').length;
    const warningTests = this.results.filter(r => r.status === 'WARN').length;
    const totalTests = this.results.length;
    const successRate = Math.floor((passedTests / totalTests) * 100);

    const overallStatus = failedTests === 0 && this.errors.length === 0 
      ? (warningTests <= 3 ? 'PRODUCTION READY' : 'PRODUCTION READY (WITH WARNINGS)')
      : failedTests <= 2 && this.errors.length === 0 
        ? 'NEEDS MINOR FIXES'
        : 'NOT PRODUCTION READY';

    let report = `# AutoVault Enhanced Contracts - Post-Deployment Verification Report

**Generated:** ${timestamp}
**Network:** ${this.config.networkName}
**Deployer:** ${this.config.deployerAddr}
**Overall Status:** ${overallStatus}

## Executive Summary

- **Total Tests:** ${totalTests}
- **Passed:** ${passedTests}
- **Failed:** ${failedTests}
- **Warnings:** ${warningTests}
- **Success Rate:** ${successRate}%

## Test Results

`;

    // Group results by category
    const categories = new Map<string, VerificationResult[]>();
    this.results.forEach(result => {
      const category = result.testName.split(':')[0];
      if (!categories.has(category)) {
        categories.set(category, []);
      }
      categories.get(category)!.push(result);
    });

    categories.forEach((results, category) => {
      report += `### ${category}\n\n`;
      results.forEach(result => {
        const status = result.status === 'PASS' ? '✅' : result.status === 'WARN' ? '⚠️' : '❌';
        report += `- ${status} **${result.testName}**\n`;
        if (result.details && Object.keys(result.details).length > 0) {
          report += `  \`\`\`json\n  ${JSON.stringify(result.details, null, 2)}\n  \`\`\`\n`;
        }
        report += '\n';
      });
    });

    if (this.errors.length > 0) {
      report += `## Errors

`;
      this.errors.forEach(error => {
        report += `- ❌ ${error}\n`;
      });
      report += '\n';
    }

    if (this.warnings.length > 0) {
      report += `## Warnings

`;
      this.warnings.forEach(warning => {
        report += `- ⚠️ ${warning}\n`;
      });
      report += '\n';
    }

    report += `## Recommendations

`;

    if (overallStatus === 'PRODUCTION READY') {
      report += `✅ **System is ready for production deployment!**

- All critical verifications passed
- Enhanced contracts are functional
- Performance targets are achievable
- Security measures are in place

**Next Steps:**
1. Final security audit review
2. Performance monitoring setup
3. User acceptance testing
4. Production deployment when ready
`;
    } else if (overallStatus.includes('PRODUCTION READY')) {
      report += `⚠️ **System is ready for production with minor warnings**

- Address the warning items listed above
- Monitor the flagged areas closely
- Consider additional testing for warning areas

**Next Steps:**
1. Review and address warnings
2. Enhanced monitoring for flagged areas
3. Proceed with staged deployment
`;
    } else if (overallStatus === 'NEEDS MINOR FIXES') {
      report += `⚠️ **Minor fixes required before production deployment**

- Address the failed verifications listed above
- Review and resolve warning items
- Re-run verification after fixes

**Estimated Fix Time:** 1-3 days
`;
    } else {
      report += `❌ **Major fixes required before production deployment**

- Critical verifications are failing
- Address all failed items before proceeding
- Consider comprehensive review and refactoring

**Estimated Fix Time:** 1-2 weeks
`;
    }

    report += `
## Contract Information

`;

    Object.entries(this.config.contracts).forEach(([name, address]) => {
      report += `- **${name}:** \`${address}\`\n`;
    });

    return report;
  }

  // =============================================================================
  // MAIN EXECUTION
  // =============================================================================

  async runFullVerification(): Promise<void> {
    console.log('🔍 AutoVault Enhanced Contracts - Post-Deployment Verification');
    console.log('==================================================================');
    console.log(`Network: ${this.config.networkName}`);
    console.log(`Deployer: ${this.config.deployerAddr}`);
    console.log('');

    try {
      // Run all verification phases
      await this.verifyContractDeployments();
      await this.verifyEnhancedVault();
      await this.verifyBatchProcessing();
      await this.verifyCachingSystem();
      await this.verifyLoadDistribution();
      await this.verifyOracleAggregator();
      await this.verifyDexFactory();
      await this.verifySecurityControls();
      await this.verifyPerformanceTargets();
      await this.verifyProductionReadiness();

      // Generate and save report
  const report = this.generateDetailedReport();
  // Save report at repository root (../ from scripts when invoked via stacks)
  const reportPath = path.resolve(__dirname, '..', 'POST_DEPLOYMENT_VERIFICATION_REPORT.md');
      fs.writeFileSync(reportPath, report);

      console.log('\n📊 Verification Complete!');
      console.log(`Report saved to: ${reportPath}`);

      // Summary
      const passedTests = this.results.filter(r => r.status === 'PASS').length;
      const failedTests = this.results.filter(r => r.status === 'FAIL').length;
      const warningTests = this.results.filter(r => r.status === 'WARN').length;

      console.log(`\nSummary: ${passedTests} passed, ${failedTests} failed, ${warningTests} warnings`);

      // Exit with appropriate code
      if (failedTests === 0 && this.errors.length === 0) {
        process.exit(0); // Success
      } else if (failedTests <= 2 && this.errors.length === 0) {
        process.exit(1); // Minor issues
      } else {
        process.exit(2); // Major issues
      }

    } catch (error) {
      console.error('Fatal error during verification:', error);
      process.exit(3);
    }
  }
}

// Main execution
if (require.main === module) {
  const verifier = new EnhancedPostDeploymentVerifier();
  verifier.runFullVerification();
}

export { EnhancedPostDeploymentVerifier };
