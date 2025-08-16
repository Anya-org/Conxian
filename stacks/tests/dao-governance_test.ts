import { Clarinet, Tx, Chain, Account, types } from "clarinet";

Clarinet.test({
    name: "DAO Governance: Can create proposals with sufficient tokens",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // First mint governance tokens to wallet1
        let block = chain.mineBlock([
            Tx.contractCall('gov-token', 'mint', [
                types.principal(wallet1.address),
                types.uint(200000) // Above proposal threshold
            ], deployer.address)
        ]);
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Create a proposal
        block = chain.mineBlock([
            Tx.contractCall('dao-governance', 'create-proposal', [
                types.utf8("Test Proposal"),
                types.utf8("This is a test proposal for parameter changes"),
                types.uint(0), // PARAM_CHANGE
                types.principal(deployer.address + ".vault"),
                types.ascii("set-fees"),
                types.list([types.uint(50), types.uint(20)]) // New fee parameters
            ], wallet1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
        
        // Verify proposal was created
        const proposalResult = chain.callReadOnlyFn('dao-governance', 'get-proposal', [types.uint(1)], deployer.address);
        const proposal = proposalResult.result.expectSome().expectTuple();
        assertEquals(proposal['proposer'], wallet1.address);
        assertEquals(proposal['title'], types.utf8("Test Proposal"));
    },
});

Clarinet.test({
    name: "DAO Governance: Cannot create proposals without sufficient tokens",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Try to create proposal without sufficient tokens
        let block = chain.mineBlock([
            Tx.contractCall('dao-governance', 'create-proposal', [
                types.utf8("Test Proposal"),
                types.utf8("This should fail"),
                types.uint(0),
                types.principal(deployer.address + ".vault"),
                types.ascii("set-fees"),
                types.list([types.uint(50), types.uint(20)])
            ], wallet1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectErr(), types.uint(101)); // insufficient-proposal-threshold
    },
});

Clarinet.test({
    name: "DAO Governance: Can vote on active proposals",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Mint tokens to both wallets
        let block = chain.mineBlock([
            Tx.contractCall('gov-token', 'mint', [
                types.principal(wallet1.address),
                types.uint(200000)
            ], deployer.address),
            Tx.contractCall('gov-token', 'mint', [
                types.principal(wallet2.address),
                types.uint(150000)
            ], deployer.address)
        ]);
        
        // Create proposal
        block = chain.mineBlock([
            Tx.contractCall('dao-governance', 'create-proposal', [
                types.utf8("Voting Test"),
                types.utf8("Test voting mechanism"),
                types.uint(0),
                types.principal(deployer.address + ".vault"),
                types.ascii("set-fees"),
                types.list([types.uint(40), types.uint(15)])
            ], wallet1.address)
        ]);
        
        // Advance to voting period (144 blocks)
        chain.mineEmptyBlockUntil(chain.blockHeight + 144);
        
        // Cast votes
        block = chain.mineBlock([
            Tx.contractCall('dao-governance', 'cast-vote', [
                types.uint(1),
                types.uint(1) // Vote FOR
            ], wallet1.address),
            Tx.contractCall('dao-governance', 'cast-vote', [
                types.uint(1),
                types.uint(0) // Vote AGAINST
            ], wallet2.address)
        ]);
        
        assertEquals(block.receipts.length, 2);
        assertEquals(block.receipts[0].result.expectOk(), true);
        assertEquals(block.receipts[1].result.expectOk(), true);
        
        // Check proposal state
        const proposalResult = chain.callReadOnlyFn('dao-governance', 'get-proposal', [types.uint(1)], deployer.address);
        const proposal = proposalResult.result.expectSome().expectTuple();
        assertEquals(proposal['for-votes'], types.uint(200000));
        assertEquals(proposal['against-votes'], types.uint(150000));
    },
});

Clarinet.test({
    name: "DAO Governance: Can queue and execute successful proposals",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Setup: mint tokens and create proposal
        let block = chain.mineBlock([
            Tx.contractCall('gov-token', 'mint', [
                types.principal(wallet1.address),
                types.uint(500000) // Majority of supply
            ], deployer.address)
        ]);
        
        block = chain.mineBlock([
            Tx.contractCall('dao-governance', 'create-proposal', [
                types.utf8("Execute Test"),
                types.utf8("Test proposal execution"),
                types.uint(0),
                types.principal(deployer.address + ".vault"),
                types.ascii("set-fees"),
                types.list([types.uint(35), types.uint(12)])
            ], wallet1.address)
        ]);
        
        // Advance to voting period and vote
        chain.mineEmptyBlockUntil(chain.blockHeight + 144);
        
        block = chain.mineBlock([
            Tx.contractCall('dao-governance', 'cast-vote', [
                types.uint(1),
                types.uint(1) // Vote FOR with majority
            ], wallet1.address)
        ]);
        
        // Advance past voting period
        chain.mineEmptyBlockUntil(chain.blockHeight + 1008);
        
        // Queue proposal
        block = chain.mineBlock([
            Tx.contractCall('dao-governance', 'queue-proposal', [
                types.uint(1)
            ], wallet1.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Advance past execution delay
        chain.mineEmptyBlockUntil(chain.blockHeight + 144);
        
        // Execute proposal
        block = chain.mineBlock([
            Tx.contractCall('dao-governance', 'execute-proposal', [
                types.uint(1)
            ], wallet1.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
    },
});

Clarinet.test({
    name: "DAO Governance: Vote delegation works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Mint tokens to wallet1
        let block = chain.mineBlock([
            Tx.contractCall('gov-token', 'mint', [
                types.principal(wallet1.address),
                types.uint(100000)
            ], deployer.address)
        ]);
        
        // Delegate vote from wallet1 to wallet2
        block = chain.mineBlock([
            Tx.contractCall('dao-governance', 'delegate-vote', [
                types.principal(wallet2.address)
            ], wallet1.address)
        ]);
        
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Verify delegation
        const delegationResult = chain.callReadOnlyFn('dao-governance', 'get-delegation', [
            types.principal(wallet1.address)
        ], deployer.address);
        const delegation = delegationResult.result.expectSome().expectTuple();
        assertEquals(delegation['delegate'], wallet2.address);
    },
});

Clarinet.test({
    name: "DAO Governance: Emergency pause works",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Emergency pause should work from multisig
        let block = chain.mineBlock([
            Tx.contractCall('dao-governance', 'emergency-pause', [], deployer.address)
        ]);
        
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Verify vault is paused
        const pausedResult = chain.callReadOnlyFn('vault', 'get-paused', [], deployer.address);
        assertEquals(pausedResult.result, types.bool(true));
    },
});
