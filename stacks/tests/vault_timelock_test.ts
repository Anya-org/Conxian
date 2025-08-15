import { Clarinet, Tx, Chain, Account, types } from "clarinet";

Clarinet.test({
  name: "vault: deposit then withdraw updates balances correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    const vaultContract = `${deployer.address}.vault`;

    // Mint tokens to wallet_1 and approve vault to spend
    let block = chain.mineBlock([
      Tx.contractCall(
        "mock-ft",
        "mint",
        [types.principal(wallet1.address), types.uint(1000)],
        deployer.address
      ),
      Tx.contractCall(
        "mock-ft",
        "approve",
        [types.principal(vaultContract), types.uint(1000)],
        wallet1.address
      ),
      // Deposit 600
      Tx.contractCall("vault", "deposit", [types.uint(600)], wallet1.address),
    ]);

    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectOk().expectBool(true);
    // fee-deposit-bps = 30 (0.30%), fee = 600*30/10000 = 1, credited = 599
    block.receipts[2].result.expectOk().expectUint(599);

    // Check vault internal balance for wallet_1
    let res = chain.callReadOnlyFn(
      "vault",
      "get-balance",
      [types.principal(wallet1.address)],
      wallet1.address
    );
    res.result.expectUint(599);

    // Withdraw 100 (withdraw fee = 10 bps => 0 in integer math), payout 100
    block = chain.mineBlock([
      Tx.contractCall("vault", "withdraw", [types.uint(100)], wallet1.address),
    ]);
    block.receipts[0].result.expectOk().expectUint(100);

    res = chain.callReadOnlyFn(
      "vault",
      "get-balance",
      [types.principal(wallet1.address)],
      wallet1.address
    );
    res.result.expectUint(499);
  },
});

Clarinet.test({
  name: "timelock: can pause vault after delay",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const vaultId = `${deployer.address}.vault`;
    const timelockId = `${deployer.address}.timelock`;

    // Make timelock the admin of the vault
    let block = chain.mineBlock([
      Tx.contractCall("vault", "set-admin", [types.principal(timelockId)], deployer.address),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Queue set-paused (true)
    block = chain.mineBlock([
      Tx.contractCall("timelock", "queue-set-paused", [types.bool(true)], deployer.address),
    ]);
    // first queued id should be u0
    block.receipts[0].result.expectOk().expectUint(0);

    // Wait for min-delay (default 20 blocks)
    chain.mineEmptyBlock(20);

    // Execute the queued action
    block = chain.mineBlock([
      Tx.contractCall("timelock", "execute-set-paused", [types.uint(0)], deployer.address),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Verify paused flag in vault
    const paused = chain.callReadOnlyFn("vault", "get-paused", [], deployer.address);
    paused.result.expectBool(true);
  },
});
