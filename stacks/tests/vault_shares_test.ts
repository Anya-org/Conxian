import { Clarinet, Tx, Chain, Account, types } from "clarinet";

Clarinet.test({
  name: "vault (shares): two users deposit equal amounts -> equal shares and balances",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const w1 = accounts.get("wallet_1")!;
    const w2 = accounts.get("wallet_2")!;
    const vaultContract = `${deployer.address}.vault`;

    // Mint tokens to both wallets and approve vault
    let block = chain.mineBlock([
      Tx.contractCall("mock-ft", "mint", [types.principal(w1.address), types.uint(1000)], deployer.address),
      Tx.contractCall("mock-ft", "mint", [types.principal(w2.address), types.uint(1000)], deployer.address),
      Tx.contractCall("mock-ft", "approve", [types.principal(vaultContract), types.uint(1000)], w1.address),
      Tx.contractCall("mock-ft", "approve", [types.principal(vaultContract), types.uint(1000)], w2.address),
      // Each deposits 1000
      Tx.contractCall("vault", "deposit", [types.uint(1000)], w1.address),
      Tx.contractCall("vault", "deposit", [types.uint(1000)], w2.address),
    ]);

    // fee on 1000 @30 bps = floor(1000*30/10000) = 3; credited = 997
    block.receipts[4].result.expectOk().expectUint(997);
    block.receipts[5].result.expectOk().expectUint(997);

    let b1 = chain.callReadOnlyFn("vault", "get-balance", [types.principal(w1.address)], w1.address);
    let b2 = chain.callReadOnlyFn("vault", "get-balance", [types.principal(w2.address)], w2.address);
    b1.result.expectUint(997);
    b2.result.expectUint(997);

    const tvl = chain.callReadOnlyFn("vault", "get-total-balance", [], deployer.address);
    tvl.result.expectUint(1994);

    // Shares should mirror credited deposits on first two deposits
    const s1 = chain.callReadOnlyFn("vault", "get-shares", [types.principal(w1.address)], w1.address);
    const s2 = chain.callReadOnlyFn("vault", "get-shares", [types.principal(w2.address)], w2.address);
    const ts = chain.callReadOnlyFn("vault", "get-total-shares", [], deployer.address);
    s1.result.expectUint(997);
    s2.result.expectUint(997);
    ts.result.expectUint(1994);
  },
});

Clarinet.test({
  name: "vault (shares): withdraw rounding uses ceil on shares burn and preserves NAV",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const w1 = accounts.get("wallet_1")!;
    const vaultContract = `${deployer.address}.vault`;

    // Setup: w1 gets 100 and approves
    let block = chain.mineBlock([
      Tx.contractCall("mock-ft", "mint", [types.principal(w1.address), types.uint(100)], deployer.address),
      Tx.contractCall("mock-ft", "approve", [types.principal(vaultContract), types.uint(100)], w1.address),
      Tx.contractCall("vault", "deposit", [types.uint(100)], w1.address),
    ]);
    // fee = floor(100*30/10000)=0; credited=100
    block.receipts[2].result.expectOk().expectUint(100);

    // Withdraw 1 unit; fee withdraw 10 bps => floor(1*10/10000)=0; payout = 1
    block = chain.mineBlock([
      Tx.contractCall("vault", "withdraw", [types.uint(1)], w1.address),
    ]);
    block.receipts[0].result.expectOk().expectUint(1);

    // NAV decreases by exactly 1
    const tvl = chain.callReadOnlyFn("vault", "get-total-balance", [], deployer.address);
    tvl.result.expectUint(99);

    // Balance equals 99
    const b1 = chain.callReadOnlyFn("vault", "get-balance", [types.principal(w1.address)], w1.address);
    b1.result.expectUint(99);
  },
});
