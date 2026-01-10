// tests/refactor-verification.test.ts
//
// This test suite is designed to verify the correct functionality of the
// refactored Lending and Governance modules. It will test the end-to-end
// functionality through the facade contracts to ensure that the delegated
// architecture is working as expected.

import { describe, it, expect, beforeEach } from 'vitest';
import { Simnet, initSimnet } from '@stacks/clarinet-sdk';
import { Cl, principal, uint } from '@stacks/transactions';

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
    const asset = `${deployer}.mock-token`;
    const amount = 1000;

    // Supply
    let receipt = simnet.callPublicFn(
      `${deployer}.comprehensive-lending-system`,
      'supply',
      [Cl.principal(asset), Cl.uint(amount)],
      wallet1
    );
    expect(receipt.result).toBeOk(Cl.bool(true));

    // Verify supply balance
    let balance = simnet.callReadOnlyFn(
      `${deployer}.lending-manager`,
      'get-user-supply-balance',
      [Cl.principal(wallet1), Cl.principal(asset)],
      wallet1
    );
    expect(balance.result).toBeSome(Cl.uint(amount));

    // Withdraw
    receipt = simnet.callPublicFn(
      `${deployer}.comprehensive-lending-system`,
      'withdraw',
      [Cl.principal(asset), Cl.uint(amount)],
      wallet1
    );
    expect(receipt.result).toBeOk(Cl.bool(true));
  });

  it('Governance Module - should create and execute a proposal through the facade', () => {
    // Create Proposal
    let receipt = simnet.callPublicFn(
      `${deployer}.proposal-engine`,
      'propose',
      [
        Cl.bufferFromAscii('test proposal'),
        Cl.list([Cl.principal(`${deployer}.mock-token`)]),
        Cl.list([Cl.uint(100)]),
        Cl.list([Cl.stringAscii('transfer')]),
        Cl.list([Cl.tuple({ to: Cl.principal(wallet1), amount: Cl.uint(10) })]),
        Cl.uint(1),
        Cl.uint(100),
      ],
      deployer
    );
    expect(receipt.result).toBeOk(Cl.uint(1));

    // Vote
    receipt = simnet.callPublicFn(
      `${deployer}.proposal-engine`,
      'vote',
      [Cl.uint(1), Cl.bool(true)],
      deployer
    );
    expect(receipt.result).toBeOk(Cl.bool(true));

    // Execute
    receipt = simnet.callPublicFn(
      `${deployer}.proposal-engine`,
      'execute',
      [Cl.uint(1)],
      deployer
    );
    expect(receipt.result).toBeOk(Cl.bool(true));

    // Verify proposal was executed
    const proposal = simnet.callReadOnlyFn(
      `${deployer}.proposal-registry`,
      'get-proposal',
      [Cl.uint(1)],
      deployer
    );
    expect(proposal.result).toBeSome(Cl.tuple({
      executed: Cl.bool(true),
    }));
  });
});
