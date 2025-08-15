import { Clarinet, Tx, Chain, Account, types } from "clarinet";

Clarinet.test({
  name: "dao: holder can propose pause; timelock queues and executes; vault paused",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const w1 = accounts.get("wallet_1")!;

    const daoId = `${deployer.address}.dao`;
    const tlId = `${deployer.address}.timelock`;
    const vaultId = `${deployer.address}.vault`;

    // Wire ownerships: timelock admin -> DAO, vault admin -> timelock
    let b = chain.mineBlock([
      Tx.contractCall("timelock", "set-admin", [types.principal(daoId)], deployer.address),
      Tx.contractCall("vault", "set-admin", [types.principal(tlId)], deployer.address),
    ]);
    b.receipts[0].result.expectOk().expectBool(true);
    b.receipts[1].result.expectOk().expectBool(true);

    // Give w1 governance power
    b = chain.mineBlock([
      Tx.contractCall("gov-token", "mint", [types.principal(w1.address), types.uint(10)], deployer.address),
    ]);
    b.receipts[0].result.expectOk().expectBool(true);

    // Propose pause via DAO (min threshold is 1 by default)
    b = chain.mineBlock([
      Tx.contractCall("dao", "propose-pause", [types.bool(true)], w1.address),
    ]);
    const qId = Number(b.receipts[0].result.expectOk().expectUint(0));

    // Advance min delay and execute
    chain.mineEmptyBlock(20);
    b = chain.mineBlock([
      Tx.contractCall("timelock", "execute-set-paused", [types.uint(qId)], deployer.address),
    ]);
    b.receipts[0].result.expectOk().expectBool(true);

    // Verify vault paused
    const paused = chain.callReadOnlyFn("vault", "get-paused", [], deployer.address);
    paused.result.expectBool(true);
  },
});
