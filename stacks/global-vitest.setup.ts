// global-vitest.setup.ts
import path from 'path';

export default function setup() {
  // Set up global options required by clarinet SDK 3.5.0
  global.options = {
    clarinet: {
      manifestPath: path.resolve(__dirname, 'Clarinet.toml'),
      initBeforeEach: true,
      
      // ✅ ENABLED: Advanced coverage reporting
      coverage: true,
      coverageFilename: 'reports/coverage-detailed.lcov',
      
      // ✅ ENABLED: Gas cost analysis  
      costs: true,
      costsFilename: 'reports/gas-costs.json',
      
      // 🔄 FUTURE: Custom boot contracts
      includeBootContracts: false,
      bootContractsPath: '',
    },
  };

  global.testEnvironment = 'clarinet';
  global.coverageReports = [];
  global.costsReports = [];
}
