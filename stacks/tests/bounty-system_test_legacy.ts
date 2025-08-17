import { describe, it, beforeEach, expect } from 'vitest';
import { initSimnet } from '@hirosystems/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Bounty System (SDK) - PRD BOUNTY alignment', () => {
  let simnet: any; let accounts: Map<string, any>; let deployer: string; let wallet1: string; let wallet2: string;
  beforeEach(async () => { 
    simnet = await initSimnet(); 
    accounts = simnet.getAccounts(); 
    deployer = accounts.get('deployer')!; 
    wallet1 = accounts.get('wallet_1')!; 
    wallet2 = accounts.get('wallet_2') || 'STB44HYPYAT2BB2QE513NSP81HTMYWBJP02HPGK6'; 
  });

  it('PRD BOUNTY-CREATE: Can create bounties with valid parameters', () => {
    const createBounty = simnet.callPublicFn('bounty-system', 'create-bounty', [
        Cl.stringUtf8("Fix Critical Bug"),
        Cl.stringUtf8("Fix the critical security vulnerability in the vault contract"),
        Cl.uint(1), // SECURITY category
        Cl.uint(100000), // 100k reward
        Cl.uint(1008) // 1 week deadline
    ], wallet1);
    
    expect(createBounty.result.type).toBe('ok');
    expect((createBounty.result as any).value.value).toBe(1n);
    
    // Verify bounty was created
    const bountyResult = simnet.callReadOnlyFn('bounty-system', 'get-bounty', [Cl.uint(1)], deployer);
    expect(bountyResult.result.type).toBe('some');
    const bounty = (bountyResult.result as any).value.value;
    expect(bounty['title'].value).toBe("Fix Critical Bug");
    expect(bounty['reward-amount'].value).toBe(100000n);
    expect(bounty['creator'].value).toBe(wallet1);
    expect(bounty['status'].value).toBe(0n); // OPEN
  });

  it('PRD BOUNTY-MILESTONE: Can add milestones to bounties', () => {
    // Create bounty first
    simnet.callPublicFn('bounty-system', 'create-bounty', [
        Cl.stringUtf8("Development Task"),
        Cl.stringUtf8("Implement new feature"),
        Cl.uint(0), // DEV category
        Cl.uint(50000),
        Cl.uint(2016) // 2 weeks
    ], wallet1);
    
    // Add milestones
    const milestone1 = simnet.callPublicFn('bounty-system', 'add-milestone', [
        Cl.uint(1), // bounty-id
        Cl.stringUtf8("Design Phase"),
        Cl.uint(30) // 30% of reward
    ], wallet1);
    const milestone2 = simnet.callPublicFn('bounty-system', 'add-milestone', [
        Cl.uint(1),
        Cl.stringUtf8("Implementation Phase"),
        Cl.uint(50) // 50% of reward
    ], wallet1);
    const milestone3 = simnet.callPublicFn('bounty-system', 'add-milestone', [
        Cl.uint(1),
        Cl.stringUtf8("Testing Phase"),
        Cl.uint(20) // 20% of reward
    ], wallet1);
    
    expect(milestone1.result.type).toBe('ok');
    expect(milestone2.result.type).toBe('ok');
    expect(milestone3.result.type).toBe('ok');
    
    // Verify milestone was added
    const milestoneResult = simnet.callReadOnlyFn('bounty-system', 'get-milestone', [
        Cl.uint(1), Cl.uint(1)
    ], deployer);
    expect(milestoneResult.result.type).toBe('some');
    const milestone = (milestoneResult.result as any).value.value;
    expect(milestone['description'].value).toBe("Design Phase");
    expect(milestone['reward-percentage'].value).toBe(30n);
  });

  it('PRD BOUNTY-APPLY: Can apply for and assign bounties', () => {
    // Create bounty first
    simnet.callPublicFn('bounty-system', 'create-bounty', [
        Cl.stringUtf8("Documentation Update"),
        Cl.stringUtf8("Update API documentation"),
        Cl.uint(2), // DOCS category
        Cl.uint(25000),
        Cl.uint(1008)
    ], wallet1);
    
    // Apply for bounty
    const application = simnet.callPublicFn('bounty-system', 'apply-for-bounty', [
        Cl.uint(1),
        Cl.stringUtf8("I have extensive experience in technical documentation and can complete this in 5 days"),
        Cl.uint(720) // Estimated 5 days
    ], wallet2);
    expect(application.result.type).toBe('ok');
    
    // Assign bounty
    const assignment = simnet.callPublicFn('bounty-system', 'assign-bounty', [
        Cl.uint(1),
        Cl.principal(wallet2)
    ], wallet1);
    expect(assignment.result.type).toBe('ok');
    
    // Verify bounty status changed
    const bountyResult = simnet.callReadOnlyFn('bounty-system', 'get-bounty', [Cl.uint(1)], deployer);
    expect(bountyResult.result.type).toBe('some');
    const bounty = (bountyResult.result as any).value.value;
    expect(bounty['status'].value).toBe(1n); // ASSIGNED
    // Note: assignee verification may require different shape handling
  });

  it('PRD BOUNTY-AUTH: Unauthorized assignment attempts fail', () => {
    // Create bounty with wallet1
    simnet.callPublicFn('bounty-system', 'create-bounty', [
        Cl.stringUtf8("Test Bounty"),
        Cl.stringUtf8("Test Description"),
        Cl.uint(0),
        Cl.uint(10000),
        Cl.uint(1008)
    ], wallet1);
    
    // Try to assign from unauthorized user (wallet2)
    const unauthorizedAssign = simnet.callPublicFn('bounty-system', 'assign-bounty', [
        Cl.uint(1),
        Cl.principal(wallet2)
    ], wallet2); // Wrong sender - only creator can assign
    
    expect(unauthorizedAssign.result.type).toBe('err'); // Should fail authorization
  });
});
        
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'add-milestone', [
                types.uint(1),
                types.utf8("MVP Implementation"),
                types.uint(100) // Full reward for single milestone
            ], wallet1.address)
        ]);
        
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'apply-for-bounty', [
                types.uint(1),
                types.utf8("Ready to implement this feature"),
                types.uint(1000)
            ], wallet2.address)
        ]);
        
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'assign-bounty', [
                types.uint(1),
                types.principal(wallet2.address)
            ], wallet1.address)
        ]);
        
        // Submit milestone
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'submit-milestone', [
                types.uint(1), // bounty-id
                types.uint(1), // milestone-id
                types.utf8("Feature implemented with tests. PR: https://github.com/repo/pull/123")
            ], wallet2.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Review and approve milestone
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'review-milestone', [
                types.uint(1),
                types.uint(1),
                types.bool(true) // Approve
            ], wallet1.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Verify milestone status
        const milestoneResult = chain.callReadOnlyFn('bounty-system', 'get-milestone', [
            types.uint(1), types.uint(1)
        ], deployer.address);
        const milestone = milestoneResult.result.expectSome().expectTuple();
        assertEquals(milestone['status'], types.uint(2)); // APPROVED
    }
});

Clarinet.test({
    name: "Bounty System: Complete bounty and update contributor stats",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Setup complete bounty workflow
        let block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'create-bounty', [
                types.utf8("Bug Fix"),
                types.utf8("Fix memory leak issue"),
                types.uint(1), // SECURITY
                types.uint(30000),
                types.uint(720)
            ], wallet1.address)
        ]);
        
        // Add milestone, apply, assign, submit, approve
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'add-milestone', [
                types.uint(1),
                types.utf8("Bug Fixed"),
                types.uint(100)
            ], wallet1.address)
        ]);
        
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'apply-for-bounty', [
                types.uint(1),
                types.utf8("I can fix this bug"),
                types.uint(500)
            ], wallet2.address)
        ]);
        
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'assign-bounty', [
                types.uint(1),
                types.principal(wallet2.address)
            ], wallet1.address)
        ]);
        
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'submit-milestone', [
                types.uint(1),
                types.uint(1),
                types.utf8("Bug fixed and tested")
            ], wallet2.address)
        ]);
        
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'review-milestone', [
                types.uint(1),
                types.uint(1),
                types.bool(true)
            ], wallet1.address)
        ]);
        
        // Complete bounty
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'complete-bounty', [
                types.uint(1)
            ], wallet1.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Verify bounty completion
        const bountyResult = chain.callReadOnlyFn('bounty-system', 'get-bounty', [types.uint(1)], deployer.address);
        const bounty = bountyResult.result.expectSome().expectTuple();
        assertEquals(bounty['status'], types.uint(4)); // COMPLETED
        
        // Verify contributor stats updated
        const contributorResult = chain.callReadOnlyFn('bounty-system', 'get-contributor', [
            types.principal(wallet2.address)
        ], deployer.address);
        const contributor = contributorResult.result.expectSome().expectTuple();
        assertEquals(contributor['total-bounties-completed'], types.uint(1));
        assertEquals(contributor['total-rewards-earned'], types.uint(30000));
    },
});

Clarinet.test({
    name: "Bounty System: Cannot apply for own bounty",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create bounty
        let block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'create-bounty', [
                types.utf8("Self Application Test"),
                types.utf8("Testing self application prevention"),
                types.uint(0),
                types.uint(10000),
                types.uint(500)
            ], wallet1.address)
        ]);
        
        // Try to apply for own bounty
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'apply-for-bounty', [
                types.uint(1),
                types.utf8("Trying to apply for my own bounty"),
                types.uint(300)
            ], wallet1.address)
        ]);
        
        assertEquals(block.receipts[0].result.expectErr(), types.uint(106)); // cannot-apply-to-own-bounty
    },
});

Clarinet.test({
    name: "Bounty System: Can cancel bounties",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create bounty
        let block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'create-bounty', [
                types.utf8("Cancellation Test"),
                types.utf8("This bounty will be cancelled"),
                types.uint(0),
                types.uint(20000),
                types.uint(1000)
            ], wallet1.address)
        ]);
        
        // Cancel bounty
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'cancel-bounty', [
                types.uint(1)
            ], wallet1.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Verify bounty is cancelled
        const bountyResult = chain.callReadOnlyFn('bounty-system', 'get-bounty', [types.uint(1)], wallet1.address);
        const bounty = bountyResult.result.expectSome().expectTuple();
        assertEquals(bounty['status'], types.uint(5)); // CANCELLED
    },
});
