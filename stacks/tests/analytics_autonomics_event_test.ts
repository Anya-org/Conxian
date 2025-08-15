import { Clarinet, Tx, Chain, Account, types } from "clarinet";

Clarinet.test({
  name: "analytics: autonomics update triggers analytics autonomics event record",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    const timelockId = `${deployer.address}.timelock`;

    // Give timelock admin rights and enable autonomics + fees
    let block = chain.mineBlock([
      Tx.contractCall("vault", "set-admin", [types.principal(timelockId)], deployer.address),
      Tx.contractCall("vault", "set-reserve-bands", [types.uint(200), types.uint(4000)], timelockId),
      Tx.contractCall("vault", "set-fee-ramps", [types.uint(5), types.uint(5)], timelockId),
      Tx.contractCall("vault", "set-auto-economics-enabled", [types.bool(true)], timelockId),
      Tx.contractCall("vault", "set-auto-fees-enabled", [types.bool(true)], timelockId),
    ]);
    block.receipts.forEach(r => r.result.expectOk());

    // Provide initial liquidity
    block = chain.mineBlock([
      Tx.contractCall("mock-ft", "mint", [types.principal(wallet1.address), types.uint(50000)], deployer.address),
      Tx.contractCall("mock-ft", "approve", [types.principal(`${deployer.address}.vault`), types.uint(50000)], wallet1.address),
      Tx.contractCall("vault", "deposit", [types.uint(20000)], wallet1.address),
    ]);
    block.receipts.forEach(r => r.result.expectOk());

    // Run an autonomics update which should internally call analytics::record-autonomics
    block = chain.mineBlock([
      Tx.contractCall("vault", "update-autonomics", [], wallet1.address),
    ]);
    const res = block.receipts[0];
    res.result.expectOk();

    // Validate a print event containing "autonomics-metrics" exists
    const printed = JSON.stringify(res.events.map(e => e));
    if (!printed.includes("autonomics-metrics")) {
      throw new Error("Expected autonomics-metrics print event not found in analytics test");
    }
  }
});
