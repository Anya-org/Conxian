import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Creator Token: Basic SIP-010 functionality works",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Test token metadata
        let result = chain.callReadOnlyFn('creator-token', 'get-name', [], deployer.address);
        assertEquals(result.result.expectOk(), types.ascii("AutoCreator"));
        
        result = chain.callReadOnlyFn('creator-token', 'get-symbol', [], deployer.address);
        assertEquals(result.result.expectOk(), types.ascii("ACTR"));
        
        result = chain.callReadOnlyFn('creator-token', 'get-decimals', [], deployer.address);
        assertEquals(result.result.expectOk(), types.uint(6));
        
        // Test minting (as bounty system)
        let block = chain.mineBlock([
            Tx.contractCall('creator-token', 'mint', [
                types.principal(wallet1.address),
                types.uint(100000)
            ], deployer.address) // Deployer acts as bounty system initially
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Check balance
        result = chain.callReadOnlyFn('creator-token', 'get-balance-of', [
            types.principal(wallet1.address)
        ], deployer.address);
        assertEquals(result.result.expectOk(), types.uint(100000));
        
        // Test transfer
        block = chain.mineBlock([
            Tx.contractCall('creator-token', 'transfer', [
                types.principal(wallet2.address),
                types.uint(25000)
            ], wallet1.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Verify balances after transfer
        result = chain.callReadOnlyFn('creator-token', 'get-balance-of', [
            types.principal(wallet1.address)
        ], deployer.address);
        assertEquals(result.result.expectOk(), types.uint(75000));
        
        result = chain.callReadOnlyFn('creator-token', 'get-balance-of', [
            types.principal(wallet2.address)
        ], deployer.address);
        assertEquals(result.result.expectOk(), types.uint(25000));
    },
});

Clarinet.test({
    name: "Creator Token: Vesting schedule creation and claiming",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create vesting schedule
        let block = chain.mineBlock([
            Tx.contractCall('creator-token', 'mint-with-vesting', [
                types.principal(wallet1.address),
                types.uint(100000), // 100k tokens
                types.uint(144), // 1 day cliff
                types.uint(1008) // 1 week vesting
            ], deployer.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1)); // schedule-id
        
        // Check vesting schedule
        let result = chain.callReadOnlyFn('creator-token', 'get-vesting-schedule', [
            types.principal(wallet1.address),
            types.uint(1)
        ], deployer.address);
        const schedule = result.result.expectSome().expectTuple();
        assertEquals(schedule['total-amount'], types.uint(100000));
        assertEquals(schedule['cliff-blocks'], types.uint(144));
        
        // Try to claim before cliff (should be 0)
        result = chain.callReadOnlyFn('creator-token', 'calculate-vested-amount', [
            types.principal(wallet1.address),
            types.uint(1)
        ], deployer.address);
        assertEquals(result.result, types.uint(0));
        
        // Advance past cliff
        chain.mineEmptyBlockUntil(chain.blockHeight + 144);
        
        // Check vested amount (should be some portion)
        result = chain.callReadOnlyFn('creator-token', 'calculate-vested-amount', [
            types.principal(wallet1.address),
            types.uint(1)
        ], deployer.address);
        // Should have some vested tokens now
        const vestedAmount = result.result.expectUint();
        assertEquals(vestedAmount > 0, true);
        
        // Claim vested tokens
        block = chain.mineBlock([
            Tx.contractCall('creator-token', 'claim-vested-tokens', [
                types.uint(1)
            ], wallet1.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), vestedAmount);
        
        // Check balance increased
        result = chain.callReadOnlyFn('creator-token', 'get-balance-of', [
            types.principal(wallet1.address)
        ], deployer.address);
        assertEquals(result.result.expectOk(), vestedAmount);
    },
});

Clarinet.test({
    name: "Creator Token: Only authorized contracts can mint",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Unauthorized user tries to mint
        let block = chain.mineBlock([
            Tx.contractCall('creator-token', 'mint', [
                types.principal(wallet2.address),
                types.uint(50000)
            ], wallet1.address) // Not authorized
        ]);
        assertEquals(block.receipts[0].result.expectErr(), types.uint(100)); // unauthorized
    },
});

Clarinet.test({
    name: "Creator Token: Burn functionality works",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Mint tokens first
        let block = chain.mineBlock([
            Tx.contractCall('creator-token', 'mint', [
                types.principal(wallet1.address),
                types.uint(100000)
            ], deployer.address)
        ]);
        
        // Check initial supply
        let result = chain.callReadOnlyFn('creator-token', 'get-total-supply', [], deployer.address);
        assertEquals(result.result.expectOk(), types.uint(100000));
        
        // Burn tokens
        block = chain.mineBlock([
            Tx.contractCall('creator-token', 'burn', [
                types.uint(30000)
            ], wallet1.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Check balance and supply after burn
        result = chain.callReadOnlyFn('creator-token', 'get-balance-of', [
            types.principal(wallet1.address)
        ], deployer.address);
        assertEquals(result.result.expectOk(), types.uint(70000));
        
        result = chain.callReadOnlyFn('creator-token', 'get-total-supply', [], deployer.address);
        assertEquals(result.result.expectOk(), types.uint(70000));
    },
});

Clarinet.test({
    name: "Creator Token: Allowance and transfer-from work",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        const wallet3 = accounts.get('wallet_3')!;
        
        // Mint tokens to wallet1
        let block = chain.mineBlock([
            Tx.contractCall('creator-token', 'mint', [
                types.principal(wallet1.address),
                types.uint(100000)
            ], deployer.address)
        ]);
        
        // Approve wallet2 to spend tokens
        block = chain.mineBlock([
            Tx.contractCall('creator-token', 'approve', [
                types.principal(wallet2.address),
                types.uint(40000)
            ], wallet1.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Check allowance
        let result = chain.callReadOnlyFn('creator-token', 'get-allowance', [
            types.principal(wallet1.address),
            types.principal(wallet2.address)
        ], deployer.address);
        assertEquals(result.result.expectOk(), types.uint(40000));
        
        // Transfer from wallet1 to wallet3 via wallet2
        block = chain.mineBlock([
            Tx.contractCall('creator-token', 'transfer-from', [
                types.principal(wallet1.address),
                types.principal(wallet3.address),
                types.uint(20000)
            ], wallet2.address)
        ]);
        assertEquals(block.receipts[0].result.expectOk(), true);
        
        // Check balances and remaining allowance
        result = chain.callReadOnlyFn('creator-token', 'get-balance-of', [
            types.principal(wallet1.address)
        ], deployer.address);
        assertEquals(result.result.expectOk(), types.uint(80000));
        
        result = chain.callReadOnlyFn('creator-token', 'get-balance-of', [
            types.principal(wallet3.address)
        ], deployer.address);
        assertEquals(result.result.expectOk(), types.uint(20000));
        
        result = chain.callReadOnlyFn('creator-token', 'get-allowance', [
            types.principal(wallet1.address),
            types.principal(wallet2.address)
        ], deployer.address);
        assertEquals(result.result.expectOk(), types.uint(20000)); // Reduced by spent amount
    },
});
