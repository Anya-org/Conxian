#!/usr/bin/env node

/**
 * Conxian Protocol API Integration Deployment Script
 * Deploys and configures bank API integration contracts
 * Supports multiple environments: development, testnet, mainnet
 */

const { Clarinet } = require('@stacks/clarinet');
const fs = require('fs');
const path = require('path');

// Configuration for different environments
const ENVIRONMENTS = {
  development: {
    network: 'simnet',
    contracts: {
      'bank-api-adapter': { enabled: true, config: { provider: 'plaid', sandbox: true } },
      'ssi-credential-manager': { enabled: true, config: { maxCredentials: 20, verificationRequired: true } },
      'auto-regulatory-alignment': { enabled: true, config: { autoAlignment: true, jurisdictions: ['US', 'EU', 'SG'] } }
    }
  },
  testnet: {
    network: 'testnet',
    contracts: {
      'bank-api-adapter': { enabled: true, config: { provider: 'plaid', sandbox: true } },
      'ssi-credential-manager': { enabled: true, config: { maxCredentials: 50, verificationRequired: true } },
      'auto-regulatory-alignment': { enabled: true, config: { autoAlignment: true, jurisdictions: ['US', 'EU', 'SG', 'UK'] } }
    }
  },
  mainnet: {
    network: 'mainnet',
    contracts: {
      'bank-api-adapter': { enabled: true, config: { provider: 'plaid', sandbox: false } },
      'ssi-credential-manager': { enabled: true, config: { maxCredentials: 100, verificationRequired: true } },
      'auto-regulatory-alignment': { enabled: true, config: { autoAlignment: true, jurisdictions: ['US', 'EU', 'SG', 'UK', 'JP'] } }
    }
  }
};

class APIIntegrationDeployer {
  constructor(environment = 'development') {
    this.environment = environment;
    this.config = ENVIRONMENTS[environment];
    this.clarinet = null;
    this.deployer = null;
    this.deployedContracts = {};
    this.contractAddresses = {};
  }

  async initialize() {
    console.log(`🚀 Initializing Conxian API Integration deployment for ${this.environment}...`);
    
    this.clarinet = new Clarinet();
    this.deployer = await this.clarinet.deployer();
    
    console.log(`✅ Clarinet initialized for ${this.config.network}`);
  }

  async deployContracts() {
    console.log('📦 Deploying API Integration contracts...');
    
    const contractsToDeploy = [
      'contracts/integrations/bank-api-adapter.clar',
      'contracts/integrations/ssi-credential-manager.clar',
      'contracts/integrations/auto-regulatory-alignment.clar',
      'contracts/compliance/regulatory-adapter.clar',
      'contracts/access/conxian-access.clar',
      'contracts/governance/conxian-operations-engine.clar'
    ];

    for (const contractPath of contractsToDeploy) {
      try {
        console.log(`  Deploying ${path.basename(contractPath)}...`);
        
        const contract = await this.deployer.deployContract(contractPath);
        this.deployedContracts[path.basename(contractPath)] = contract;
        this.contractAddresses[path.basename(contractPath)] = contract.address;
        
        console.log(`    ✅ Deployed at: ${contract.address}`);
      } catch (error) {
        console.error(`    ❌ Failed to deploy ${path.basename(contractPath)}:`, error.message);
        throw error;
      }
    }

    console.log('✅ All contracts deployed successfully');
  }

  async configureContracts() {
    console.log('⚙️  Configuring contracts...');
    
    const admin = this.deployer.accounts.get('deployer');
    const institution = this.deployer.accounts.get('wallet_2');
    
    // Configure access control
    await this.deployer.runBlock(this.clarinet.Block.genesis());
    
    // Grant admin roles
    await this.deployer.tx(
      tx => tx.callFn('conxian-access.grant-role', admin.address, 1), // ROLE_ADMIN
      admin
    );
    
    await this.deployer.tx(
      tx => tx.callFn('conxian-access.grant-role', institution.address, 2), // ROLE_INSTITUTION
      admin
    );
    
    await this.deployer.runBlock(this.clarinet.Block.genesis());
    
    // Configure Bank API Adapter
    if (this.config.contracts['bank-api-adapter'].enabled) {
      const bankApiAdapter = this.deployedContracts['bank-api-adapter'];
      const config = this.config.contracts['bank-api-adapter'].config;
      
      console.log('  Configuring Bank API Adapter...');
      
      if (config.provider === 'plaid') {
        await this.deployer.tx(
          tx => tx.callFn('bank-api-adapter.register-api-provider', 1, config.clientId || 'test_client_id', config.publicKey || 'test_public_key'),
          admin
        );
      }
      
      console.log('    ✅ Bank API Adapter configured');
    }
    
    // Configure SSI Credential Manager
    if (this.config.contracts['ssi-credential-manager'].enabled) {
      console.log('  Configuring SSI Credential Manager...');
      
      // Register institutional issuers
      await this.deployer.tx(
        tx => tx.callFn('ssi-credential-manager.register-institutional-issuer',
          'Conxian Protocol',
          3, // High accreditation
          'US',
          15768000 // 1 year in blocks
        ),
        institution
      );
      
      console.log('    ✅ SSI Credential Manager configured');
    }
    
    // Configure Auto Regulatory Alignment
    if (this.config.contracts['auto-regulatory-alignment'].enabled) {
      const alignmentConfig = this.config.contracts['auto-regulatory-alignment'].config;
      console.log('  Configuring Auto Regulatory Alignment...');
      
      // Register frameworks for each jurisdiction
      for (const jurisdiction of alignmentConfig.jurisdictions) {
        const frameworkConfig = this.getFrameworkConfig(jurisdiction);
        
        await this.deployer.tx(
          tx => tx.callFn('auto-regulatory-alignment.register-regulatory-framework',
            this.getJurisdictionCode(jurisdiction),
            frameworkConfig.name,
          frameworkConfig.version,
          frameworkConfig.threshold
          ),
          admin
        );
        
        console.log(`    ✅ Registered ${jurisdiction} framework`);
      }
      
      console.log('    ✅ Auto Regulatory Alignment configured');
    }
    
    await this.deployer.runBlock(this.clarinet.Block.genesis());
    console.log('✅ All contracts configured');
  }

  getJurisdictionCode(jurisdiction) {
    const codes = {
      'US': 1,
      'EU': 2,
      'SG': 3,
      'UK': 4,
      'JP': 5
    };
    return codes[jurisdiction] || 1;
  }

  getFrameworkConfig(jurisdiction) {
    const frameworks = {
      'US': {
        name: 'US Banking Framework',
        version: 'v2.1',
        threshold: 900
      },
      'EU': {
        name: 'EU GDPR Banking Framework',
        version: 'v3.0',
        threshold: 850
      },
      'SG': {
        name: 'Singapore MAS Framework',
        version: 'v2.0',
        threshold: 800
      },
      'UK': {
        name: 'UK FCA Framework',
        version: 'v2.2',
        threshold: 850
      },
      'JP': {
        name: 'Japan FSA Framework',
        version: 'v1.9',
        threshold: 800
      }
    };
    return frameworks[jurisdiction] || frameworks['US'];
  }

  async runTests() {
    console.log('🧪 Running integration tests...');
    
    try {
      // Run the API integration test suite
      const { execSync } = require('child_process');
      const result = execSync('npm test -- tests/integrations/api-integration.test.ts', {
        cwd: process.cwd(),
        stdio: 'inherit'
      });
      
      if (result.status === 0) {
        console.log('✅ All tests passed');
      } else {
        console.log('❌ Some tests failed');
        process.exit(1);
      }
    } catch (error) {
      console.error('❌ Test execution failed:', error.message);
      process.exit(1);
    }
  }

  generateDeploymentReport() {
    console.log('📊 Generating deployment report...');
    
    const report = {
      environment: this.environment,
      network: this.config.network,
      deployedAt: new Date().toISOString(),
      contracts: {}
    };
    
    for (const [name, contract] of Object.entries(this.deployedContracts)) {
      report.contracts[name] = {
        address: contract.address,
        enabled: this.config.contracts[name]?.enabled || false
      };
    }
    
    const reportPath = `deployments/api-integration-${this.environment}.json`;
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
    
    console.log(`📋 Deployment report saved to: ${reportPath}`);
    
    // Generate environment file
    const envContent = this.generateEnvironmentFile();
    const envPath = `.env.${this.environment}`;
    fs.writeFileSync(envPath, envContent);
    
    console.log(`🔧 Environment file saved to: ${envPath}`);
  }

  generateEnvironmentFile() {
    const envVars = [
      `NETWORK=${this.config.network}`,
      '',
      '# Contract Addresses',
      `BANK_API_ADAPTER_ADDRESS=${this.contractAddresses['bank-api-adapter'] || ''}`,
      `SSI_CREDENTIAL_MANAGER_ADDRESS=${this.contractAddresses['ssi-credential-manager'] || ''}`,
      `AUTO_REGULATORY_ALIGNMENT_ADDRESS=${this.contractAddresses['auto-regulatory-alignment'] || ''}`,
      '',
      '# Configuration',
      `API_PROVIDER=${this.config.contracts['bank-api-adapter']?.config?.provider || 'plaid'}`,
      `API_SANDBOX=${this.config.contracts['bank-api-adapter']?.config?.sandbox ? 'true' : 'false'}`,
      `AUTO_ALIGNMENT_ENABLED=${this.config.contracts['auto-regulatory-alignment']?.config?.autoAlignment ? 'true' : 'false'}`,
      '',
      '# Timestamp',
      `DEPLOYMENT_TIMESTAMP=${new Date().toISOString()}`
    ];
    
    return envVars.join('\n');
  }

  async deploy() {
    try {
      await this.initialize();
      await this.deployContracts();
      await this.configureContracts();
      await this.runTests();
      this.generateDeploymentReport();
      
      console.log('🎉 API Integration deployment completed successfully!');
      console.log('');
      console.log('📋 Summary:');
      console.log(`  Environment: ${this.environment}`);
      console.log(`  Network: ${this.config.network}`);
      console.log(`  Contracts deployed: ${Object.keys(this.deployedContracts).length}`);
      console.log(`  Tests passed: ✅`);
      
    } catch (error) {
      console.error('❌ Deployment failed:', error.message);
      process.exit(1);
    }
  }
}

// CLI interface
if (require.main === module) {
  const environment = process.argv[2] || 'development';
  
  if (!['development', 'testnet', 'mainnet'].includes(environment)) {
    console.error('❌ Invalid environment. Use: development, testnet, or mainnet');
    process.exit(1);
  }
  
  const deployer = new APIIntegrationDeployer(environment);
  deployer.deploy();
}

module.exports = APIIntegrationDeployer;
