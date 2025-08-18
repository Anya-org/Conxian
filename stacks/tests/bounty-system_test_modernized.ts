import { describe, it, expect, beforeEach } from 'vitest';
import { initSimnet } from '@hirosystems/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: any; let accounts: Map<string, any>; let deployer: any; let wallet1: any; let wallet2: any; let wallet3: any;

describe("Bounty System", () => {
  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  wallet2 = accounts.get('wallet_2')!;
  wallet3 = accounts.get('wallet_3')!;
  });

  it("should create and manage bounties", () => {
    // Create bounty
    const createBounty = simnet.callPublicFn('bounty-system', 'create-bounty', [
        Cl.stringUtf8("Bug Fix"),
        Cl.stringUtf8("Fix critical vulnerability"),
        Cl.uint(1), // Bug fix category
        Cl.uint(10000),
        Cl.uint(500)
    ], wallet1);

    expect(createBounty.result.type).toBe('ok');

    // Get bounty details
    const getBounty = simnet.callReadOnlyFn('bounty-system', 'get-bounty', [
        Cl.uint(1)
    ], wallet1);
    expect(getBounty.result.type).toBe('some');
    const bountyOpt = getBounty.result as any; // optional wrapper
    const bountyTuple = bountyOpt.value.value; // unwrap option then tuple
    expect(bountyTuple['title'].value).toBe('Bug Fix');
    expect(bountyTuple['reward-amount'].value).toBe(10000n);
  });

  it("should handle bounty applications", () => {
    // Create bounty first
    simnet.callPublicFn('bounty-system', 'create-bounty', [
        Cl.stringUtf8("Feature Request"),
        Cl.stringUtf8("Implement new feature"),
        Cl.uint(2), // Feature category
        Cl.uint(15000),
        Cl.uint(600)
    ], wallet1);

    // Applicant selection with fallback if aliasing persists
  const applicant = wallet2.address !== wallet1.address ? wallet2 : wallet3;
  expect(applicant.address).not.toBe(wallet1.address);

    // Apply for bounty
    const applyBounty = simnet.callPublicFn('bounty-system', 'apply-for-bounty', [
        Cl.uint(1),
        Cl.stringUtf8("I can implement this feature"),
        Cl.uint(500)
    ], applicant);

  expect(applyBounty.result.type).toBe('ok');

    // Assign bounty to applicant
    const assignBounty = simnet.callPublicFn('bounty-system', 'assign-bounty', [
        Cl.uint(1),
        Cl.principal(applicant)
    ], wallet1);

  expect(assignBounty.result.type).toBe('ok');
  });

  it("should enforce authorization checks", () => {
    // Create bounty
    simnet.callPublicFn('bounty-system', 'create-bounty', [
        Cl.stringUtf8("Auth Test"),
        Cl.stringUtf8("Testing authorization"),
        Cl.uint(0), // General category
        Cl.uint(5000),
        Cl.uint(300)
    ], wallet1);

    // Try to assign from unauthorized user (wallet2)
    const unauthorizedAssign = simnet.callPublicFn('bounty-system', 'assign-bounty', [
        Cl.uint(1),
        Cl.principal(wallet2)
    ], wallet2); // Wrong sender - only creator can assign
    expect(unauthorizedAssign.result.type).toBe('err');
    if (unauthorizedAssign.result.type === 'err') {
      expect(unauthorizedAssign.result.value.value).toBe(100n);
    }
  });
});
