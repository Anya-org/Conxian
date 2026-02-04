// Mock simnet setup for integration tests
import { Cl } from '@stacks/transactions';
import type { Simnet } from '@stacks/clarinet-sdk';

export function createMockSimnet(): Simnet {
  return {
    callPublicFn: (contractName: string, functionName: string, args: any[], sender: string) => {
      return {
        result: Cl.ok(Cl.bool(true)),
        events: []
      };
    },
    callReadOnlyFn: (contractName: string, functionName: string, args: any[], sender: string) => {
      return {
        result: Cl.ok(Cl.bool(true))
      };
    },
    getAccounts: () => new Map([
      ['deployer', 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ'],
      ['wallet_1', 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5'],
      ['wallet_2', 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG']
    ])
  } as any;
}
