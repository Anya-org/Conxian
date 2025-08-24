// global-vitest.setup.ts
import path from 'path';

export default function setup() {
  console.log('__dirname:', __dirname);
  const manifestPath = path.resolve(__dirname, '../Clarinet.toml');
  console.log('manifestPath:', manifestPath);
  // Set up global options required by clarinet SDK
  global.options = {
    clarinet: {
      manifestPath: manifestPath,
      initBeforeEach: true,
      coverage: false,
      coverageFilename: 'coverage.lcov',
      costs: false,
      costsFilename: 'costs.json',
      includeBootContracts: false,
      bootContractsPath: '',
    },
  };

  global.testEnvironment = 'clarinet';
  global.coverageReports = [];
  global.costsReports = [];
}
