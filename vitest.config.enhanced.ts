import { defineConfig } from 'vitest/config';
import { resolve } from 'path';

/**
 * Enhanced Vitest Configuration for Conxian Tokenomics System
 * 
 * Configures comprehensive testing environment with:
 * - Clarity contract integration via Clarinet
 * - Enhanced load testing capabilities
 * - Test coverage reporting
 * - Performance benchmarking
 */
export default defineConfig({
  test: {
    // Test directories for comprehensive coverage
    include: [
      'stacks/tests/**/*.test.ts',
      'stacks/sdk-tests/**/*.spec.ts',
      'tests/load-testing/**/*.ts'
    ],
    exclude: [
      'stacks/tests/helpers/**',
      'node_modules/**',
      'dist/**'
    ],
    
    // Enhanced test environment
    environment: 'node',
    testTimeout: 60000, // Extended timeout for load tests
    hookTimeout: 30000,
    
    // Parallel execution for performance
    threads: true,
    maxThreads: 4,
    minThreads: 1,
    
    // Global setup and teardown
    globalSetup: ['./stacks/tests/helpers/global-setup.ts'],
    setupFiles: ['./stacks/tests/helpers/test-setup.ts'],
    
    // Coverage configuration
    coverage: {
      enabled: true,
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      reportsDirectory: './coverage',
      include: [
        'stacks/tests/**/*.ts',
        'contracts/**/*.clar'
      ],
      exclude: [
        'stacks/tests/helpers/**',
        'node_modules/**',
        '**/*.d.ts',
        '**/*.config.*'
      ],
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 85,
          statements: 85
        }
      }
    },
    
    // Enhanced reporting
    reporter: [
      'verbose',
      'json'
    ],
    outputFile: {
      json: './test-results/results.json',
      html: './test-results/report.html'
    },
    
    // Performance benchmarking
    benchmark: {
      include: ['tests/load-testing/**/*.ts'],
      reporters: ['verbose'],
      outputFile: './test-results/benchmark.json'
    }
  },
  
  // TypeScript configuration
  resolve: {
    alias: {
      '@tests': resolve(__dirname, './stacks/tests'),
      '@contracts': resolve(__dirname, './contracts'),
      '@helpers': resolve(__dirname, './stacks/tests/helpers')
    }
  },
  
  // Build configuration for test environment
  build: {
    target: 'node14',
    lib: {
      entry: resolve(__dirname, 'stacks/tests/index.ts'),
      formats: ['es', 'cjs']
    }
  },
  
  // Environment variables
  define: {
    'process.env.NODE_ENV': '"test"',
    'process.env.CLARINET_MODE': '"test"'
  }
});
