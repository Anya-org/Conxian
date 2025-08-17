// global-vitest.setup.ts
import path from 'path';

export default function setup() {
  // Set up global options required by clarinet SDK
  global.options = {
    clarinet: {
      manifestPath: path.resolve(__dirname, 'Clarinet.toml'),
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
