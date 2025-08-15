import { Clarinet, Tx, Chain, Account, types } from "clarinet";

Clarinet.test({
  name: "treasury: fees split between protocol and treasury; withdraw via timelock",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const w1 = accounts.get("wallet_1")!;
    const w2 = accounts.get("wallet_2")!;

    const vaultId = `${deployer.address}.vault`;
    const timelockId = `${deployer.address}.timelock`;

    // Mint to w1 and approve vault
    let block = chain.mineBlock([
      Tx.contractCall("mock-ft", "mint", [types.principal(w1.address), types.uint(10_000)], deployer.address),
      Tx.contractCall("mock-ft", "approve", [types.principal(vaultId), types.uint(10_000)], w1.address),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectOk().expectBool(true);

    // Baseline reserves
    let tres0 = chain.callReadOnlyFn("vault", "get-treasury-reserve", [], deployer.address);
    let pres0 = chain.callReadOnlyFn("vault", "get-protocol-reserve", [], deployer.address);

    // Deposit 1_000; fee 0.3% => 3; split 50/50 => treasury +1, protocol +2
    block = chain.mineBlock([
      Tx.contractCall("vault", "deposit", [types.uint(1_000)], w1.address),
    ]);
    block.receipts[0].result.expectOk().expectUint(997);

    let tres1 = chain.callReadOnlyFn("vault", "get-treasury-reserve", [], deployer.address);
    let pres1 = chain.callReadOnlyFn("vault", "get-protocol-reserve", [], deployer.address);
    // Assert deltas numerically below

    // Read numeric values
    const t0 = (tres0.result as any).value as bigint;
    const p0 = (pres0.result as any).value as bigint;
    const t1 = (tres1.result as any).value as bigint;
    const p1 = (pres1.result as any).value as bigint;

    if (t1 - t0 !== 1n || p1 - p0 !== 2n) {
      throw new Error(`unexpected fee split: treasury +(t1-t0)=${t1 - t0}, protocol +(p1-p0)=${p1 - p0}`);
    }

    // Make timelock admin of vault
    block = chain.mineBlock([
      Tx.contractCall("vault", "set-admin", [types.principal(timelockId)], deployer.address),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Queue withdraw-treasury of 1 token to wallet_2
    block = chain.mineBlock([
      Tx.contractCall("timelock", "queue-withdraw-treasury", [types.principal(w2.address), types.uint(1)], deployer.address),
    ]);
    const id = Number(block.receipts[0].result.expectOk().expectUint(0));

    // Advance min-delay blocks
    chain.mineEmptyBlock(20);

    // Execute withdrawal
    block = chain.mineBlock([
      Tx.contractCall("timelock", "execute-withdraw-treasury", [types.uint(id)], deployer.address),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Verify token balance of w2 increased by 1 and treasury reserve decreased by 1
    const balW2 = chain.callReadOnlyFn("mock-ft", "get-balance-of", [types.principal(w2.address)], deployer.address);
    const tres2 = chain.callReadOnlyFn("vault", "get-treasury-reserve", [], deployer.address);
    const b2 = (balW2.result as any).value as bigint;
    const t2 = (tres2.result as any).value as bigint;

    if (b2 < 1n) throw new Error(`wallet_2 did not receive tokens; got ${b2}`);
    if (t2 !== t1 - 1n) throw new Error(`treasury reserve mismatch after withdraw: expected ${t1 - 1n}, got ${t2}`);
  },
});
