// setup-test-env.ts
import path from 'path';

// Set up global options required by clarinet SDK
globalThis.options = {
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

globalThis.testEnvironment = 'clarinet';
globalThis.coverageReports = [];
globalThis.costsReports = [];
