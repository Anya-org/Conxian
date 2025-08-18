import { describe, it, expect, beforeEach } from 'vitest';
import { initSimnet } from '@hirosystems/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: any; let accounts: Map<string, any>; let deployer: any; let wallet1: any; let wallet2: any;

/*
  Bounty System Error Path Tests
  Verifies critical authorization & invariants with deterministic principals
  Error Codes Referenced:
  u100 unauthorized
  u106 cannot-apply-to-own-bounty
  u107 already-applied
  u108 application-not-found
*/

describe('Bounty System (SDK) - Error Paths', () => {
  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    
    // Use predefined addresses to ensure distinct principals (learned from oracle debugging)
    wallet1 = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
    wallet2 = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
  });

  it('enforces cannot apply to own bounty (u106)', () => {
    // Creator creates bounty
    const createRes = simnet.callPublicFn('bounty-system','create-bounty', [
      Cl.stringUtf8('Self Apply Test'),
      Cl.stringUtf8('Testing self application restriction'),
      Cl.uint(0),
      Cl.uint(5000),
      Cl.uint(100)
    ], wallet1);
    expect(createRes.result.type).toBe('ok');

    // Try to apply with same wallet
    const applyRes = simnet.callPublicFn('bounty-system','apply-for-bounty', [
      Cl.uint(1),
      Cl.stringUtf8('I wrote it'),
      Cl.uint(50)
    ], wallet1);
    expect(applyRes.result.type).toBe('err');
    if (applyRes.result.type === 'err') {
      expect(applyRes.result.value.value).toBe(106n);
    }
  });

  it('rejects duplicate applications (u107)', () => {
    // Setup bounty by wallet1; wallet2 applies twice
    simnet.callPublicFn('bounty-system','create-bounty', [
      Cl.stringUtf8('Duplicate Apply'),
      Cl.stringUtf8('Dup app test'),
      Cl.uint(0),
      Cl.uint(6000),
      Cl.uint(120)
    ], wallet1);

    expect(wallet2).not.toBe(wallet1);
    const first = simnet.callPublicFn('bounty-system','apply-for-bounty', [
      Cl.uint(1), Cl.stringUtf8('First proposal'), Cl.uint(75)
    ], wallet2);
    expect(first.result.type).toBe('ok');

    const second = simnet.callPublicFn('bounty-system','apply-for-bounty', [
      Cl.uint(1), Cl.stringUtf8('Second attempt'), Cl.uint(80)
    ], wallet2);
    expect(second.result.type).toBe('err');
    if (second.result.type === 'err') {
      expect(second.result.value.value).toBe(107n);
    }
  });

  it('rejects assignment without application (u108)', () => {
    // Creator makes bounty; attempts to assign wallet2 with no application
    simnet.callPublicFn('bounty-system','create-bounty', [
      Cl.stringUtf8('Assign Without Apply'),
      Cl.stringUtf8('Negative path'),
      Cl.uint(0),
      Cl.uint(7000),
      Cl.uint(150)
    ], wallet1);

    const assign = simnet.callPublicFn('bounty-system','assign-bounty', [
      Cl.uint(1),
      Cl.principal(wallet2)
    ], wallet1);
    expect(assign.result.type).toBe('err');
    if (assign.result.type === 'err') {
      expect(assign.result.value.value).toBe(108n);
    }
  });
});
