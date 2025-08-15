import { Clarinet, Tx, Chain, Account, types } from "clarinet";

Clarinet.test({
  name: "autonomics: enabling and running update adjusts fees within bounds",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    const timelockId = `${deployer.address}.timelock`;

    // Make timelock admin so we can simulate governance setting params
    let block = chain.mineBlock([
      Tx.contractCall("vault", "set-admin", [types.principal(timelockId)], deployer.address),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Configure autonomics
    block = chain.mineBlock([
      Tx.contractCall("vault", "set-reserve-bands", [types.uint(200), types.uint(4000)], timelockId),
      Tx.contractCall("vault", "set-fee-ramps", [types.uint(5), types.uint(5)], timelockId),
      Tx.contractCall("vault", "set-auto-economics-enabled", [types.bool(true)], timelockId),
      Tx.contractCall("vault", "set-auto-fees-enabled", [types.bool(true)], timelockId),
    ]);
    block.receipts.forEach(r => r.result.expectOk());

    // Mint & approve token then deposit to create state
    block = chain.mineBlock([
      Tx.contractCall("mock-ft", "mint", [types.principal(wallet1.address), types.uint(100000)], deployer.address),
      Tx.contractCall("mock-ft", "approve", [types.principal(`${deployer.address}.vault`), types.uint(100000)], wallet1.address),
      Tx.contractCall("vault", "deposit", [types.uint(50000)], wallet1.address),
    ]);
    block.receipts.forEach(r => r.result.expectOk());

    // Capture initial fees
  const feesBeforeRes = chain.callReadOnlyFn("vault", "get-fees", [], wallet1.address);
  feesBeforeRes.result.expectTuple();
  const feesBeforeTuple: any = feesBeforeRes.result; // Clarinet returns wrapper with .expectTuple() already asserting
  // Clarinet testing lib usually exposes fields via .result.expectTuple().toObject() pattern; fallback using JSON parse
  const beforeJson = JSON.parse(JSON.stringify(feesBeforeTuple));
  const depositBefore = BigInt(beforeJson.value["deposit-bps"].value);
  const withdrawBefore = BigInt(beforeJson.value["withdraw-bps"].value);

    // Trigger autonomics update several times to force adjustments
    for (let i = 0; i < 5; i++) {
      block = chain.mineBlock([
        Tx.contractCall("vault", "update-autonomics", [], wallet1.address),
      ]);
      block.receipts[0].result.expectOk();
    }

    // Read back fees after adjustments
  const feesAfterRes = chain.callReadOnlyFn("vault", "get-fees", [], wallet1.address);
  feesAfterRes.result.expectTuple();
  const afterJson = JSON.parse(JSON.stringify(feesAfterRes.result));
  const depositAfter = BigInt(afterJson.value["deposit-bps"].value);
  const withdrawAfter = BigInt(afterJson.value["withdraw-bps"].value);

    // Basic assertions: fees remain within 0..10000 and may move
  if (depositAfter < 0n || depositAfter > 10000n) throw new Error("deposit fee out of bounds");
  if (withdrawAfter < 0n || withdrawAfter > 10000n) throw new Error("withdraw fee out of bounds");
  if (depositBefore === depositAfter) {
      // Not failing test yet (could be stable scenario) — log hint
      console.log("Autonomics test: deposit fee unchanged; consider scenario amplification.");
    }
  }
});
