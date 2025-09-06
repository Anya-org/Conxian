/**
 * Test Setup Helper for Enhanced Tokenomics System
 * 
 * Configures individual test environments with mock Clarinet integration
 */

import { beforeEach, afterEach } from 'vitest';

// Mock Clarinet Simnet for testing
export interface MockSimnet {
  callPublicFn: (contractName: string, functionName: string, args: any[], sender: string) => any;
  callReadOnlyFn: (contractName: string, functionName: string, args: any[], sender: string) => any;
  getAccounts: () => Map<string, string>;
}

// Global test accounts
export const TEST_ACCOUNTS = new Map([
  ['deployer', 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'],
  ['wallet_1', 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5'],
  ['wallet_2', 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG'],
  ['wallet_3', 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC'],
  ['wallet_4', 'ST2NEB84ASENDXKYGJPQW86YXQCEFEX2ZQPG87ND']
]);

// Test cleanup and setup
beforeEach(() => {
  // Reset test state
  process.env.TEST_TIMESTAMP = Date.now().toString();
});

afterEach(() => {
  // Cleanup after each test
  delete process.env.TEST_TIMESTAMP;
});

// Helper function to create mock simnet
export function createMockSimnet(): MockSimnet {
  return {
    callPublicFn: (contractName: string, functionName: string, args: any[], sender: string) => {
      return {
        result: { type: 'ok', value: { type: 'bool', value: true } },
        events: []
      };
    },
    callReadOnlyFn: (contractName: string, functionName: string, args: any[], sender: string) => {
      return {
        result: { type: 'ok', value: { type: 'bool', value: true } }
      };
    },
    getAccounts: () => TEST_ACCOUNTS
  };
}
