// tests/refactor-verification.test.ts
//
// This test suite is designed to verify the correct functionality of the
// refactored Lending and Governance modules. It will test the end-to-end
// functionality through the facade contracts to ensure that the delegated
// architecture is working as expected.

import { describe, it, expect, beforeEach } from 'vitest';
import { Simnet, initSimnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Refactor Verification Suite', () => {
  let simnet: Simnet;
  let deployer: string;
  let wallet1: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('Lending Module - should supply and withdraw through the facade', () => {
    // Mint tokens first
    simnet.callPublicFn('mock-token', 'mint', [Cl.uint(10000), Cl.principal(wallet1)], wallet1);

    // Deposit via lending-manager
    let receipt = simnet.callPublicFn(
      'lending-manager',
      'deposit',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(1000)],
      wallet1
    );
    expect(receipt.result).toEqual(Cl.ok(Cl.bool(true)));

    // Verify supply balance
    let balance = simnet.callReadOnlyFn(
      'lending-manager',
      'get-user-supply-balance',
      [Cl.principal(wallet1), Cl.contractPrincipal(deployer, 'mock-token')],
      wallet1
    );
    expect(balance.result).toEqual(Cl.some(Cl.uint(1000)));

    // Withdraw
    receipt = simnet.callPublicFn(
      'lending-manager',
      'withdraw',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(1000)],
      wallet1
    );
    expect(receipt.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('Governance Module - admin should be able to set voting period', () => {
    // Call set-voting-period as deployer (who is the contract admin)
    const receipt = simnet.callPublicFn(
      'proposal-engine',
      'set-voting-period',
      [Cl.uint(200)],
      deployer
    );
    // Should succeed (deployer is admin)
    expect(receipt.result).toEqual(Cl.ok(Cl.bool(true)));
    // Should have emitted a print event
    expect(receipt.events).toHaveLength(1);
  });
});
