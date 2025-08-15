import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Bounty System: Can create bounties with valid parameters",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'create-bounty', [
                types.utf8("Fix Critical Bug"),
                types.utf8("Fix the critical security vulnerability in the vault contract"),
                types.uint(1), // SECURITY category
                types.uint(100000), // 100k reward
                types.uint(1008) // 1 week deadline
            ], wallet1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
        
        // Verify bounty was created
        const bountyResult = chain.callReadOnlyFn('bounty-system', 'get-bounty', [types.uint(1)], deployer.address);
        const bounty = bountyResult.result.expectSome().expectTuple();
        assertEquals(bounty['title'], types.utf8("Fix Critical Bug"));
        assertEquals(bounty['reward-amount'], types.uint(100000));
        assertEquals(bounty['creator'], wallet1.address);
        assertEquals(bounty['status'], types.uint(0)); // OPEN
    },
});

Clarinet.test({
    name: "Bounty System: Can add milestones to bounties",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create bounty first
        let block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'create-bounty', [
                types.utf8("Development Task"),
                types.utf8("Implement new feature"),
                types.uint(0), // DEV category
                types.uint(50000),
                types.uint(2016) // 2 weeks
            ], wallet1.address)
        ]);
        
        // Add milestones
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'add-milestone', [
                types.uint(1), // bounty-id
                types.utf8("Design Phase"),
                types.uint(30) // 30% of reward
            ], wallet1.address),
            Tx.contractCall('bounty-system', 'add-milestone', [
                types.uint(1),
                types.utf8("Implementation Phase"),
                types.uint(50) // 50% of reward
            ], wallet1.address),
            Tx.contractCall('bounty-system', 'add-milestone', [
                types.uint(1),
                types.utf8("Testing Phase"),
                types.uint(20) // 20% of reward
            ], wallet1.address)
        ]);
        
        assertEquals(block.receipts.length, 3);
        block.receipts.forEach(receipt => {
            assertEquals(receipt.result.expectOk(), types.uint(1) || types.uint(2) || types.uint(3));
        });
        
        // Verify milestone was added
        const milestoneResult = chain.callReadOnlyFn('bounty-system', 'get-milestone', [
            types.uint(1), types.uint(1)
        ], deployer.address);
        const milestone = milestoneResult.result.expectSome().expectTuple();
        assertEquals(milestone['description'], types.utf8("Design Phase"));
        assertEquals(milestone['reward-percentage'], types.uint(30));
    },
});

Clarinet.test({
    name: "Bounty System: Can apply for and assign bounties",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!; // Creator
        const wallet2 = accounts.get('wallet_2')!; // Applicant
        
        // Create bounty
        let block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'create-bounty', [
                types.utf8("Documentation Update"),
                types.utf8("Update API documentation"),
                types.uint(2), // DOCS category
                types.uint(25000),
                types.uint(1008)
            ], wallet1.address)
        ]);
        
        // Apply for bounty
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'apply-for-bounty', [
                types.uint(1),
                types.utf8("I have extensive experience in technical documentation and can complete this in 5 days"),
                types.uint(720) // Estimated 5 days
            ], wallet2.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Assign bounty to applicant
        block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'assign-bounty', [
                types.uint(1),
                types.principal(wallet2.address)
            ], wallet1.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Verify bounty is assigned
        const bountyResult = chain.callReadOnlyFn('bounty-system', 'get-bounty', [types.uint(1)], deployer.address);
        const bounty = bountyResult.result.expectSome().expectTuple();
        assertEquals(bounty['assignee'], types.some(types.principal(wallet2.address)));
        assertEquals(bounty['status'], types.uint(1)); // ASSIGNED
    },
});

Clarinet.test({
    name: "Bounty System: Milestone submission and review workflow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!; // Creator
        const wallet2 = accounts.get('wallet_2')!; // Contributor
        
        // Setup: Create bounty, add milestone, apply, and assign
        let block = chain.mineBlock([
            Tx.contractCall('bounty-system', 'create-bounty', [
                types.utf8("Feature Development"),
                types.utf8("Implement new analytics feature"),
                types.uint(0), // DEV
                types.uint(75000),
                types.uint(1440)
            ], wallet1.address)
        ]);
        
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
    },
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
