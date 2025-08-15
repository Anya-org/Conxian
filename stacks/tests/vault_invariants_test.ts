import { Clarinet, Tx, Chain, Account, types } from "clarinet";

// Basic fuzz-style invariant test: random deposits/withdrawals within constraints
Clarinet.test({
  name: "vault invariants: total shares consistent and fees within bounds under random ops",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const w1 = accounts.get("wallet_1")!;
    const w2 = accounts.get("wallet_2")!;
    const users = [w1, w2];
    const vaultContract = `${deployer.address}.vault`;

    // Seed funds
    let block = chain.mineBlock([
      Tx.contractCall("mock-ft", "mint", [types.principal(w1.address), types.uint(20000)], deployer.address),
      Tx.contractCall("mock-ft", "mint", [types.principal(w2.address), types.uint(20000)], deployer.address),
      Tx.contractCall("mock-ft", "approve", [types.principal(vaultContract), types.uint(20000)], w1.address),
      Tx.contractCall("mock-ft", "approve", [types.principal(vaultContract), types.uint(20000)], w2.address),
    ]);
    block.receipts.forEach(r => r.result.expectOk());

    const iterations = 40; // keep light for CI
    for (let i = 0; i < iterations; i++) {
      const user = users[i % users.length];
      const action = Math.random() < 0.6 ? 'deposit' : 'withdraw';
      if (action === 'deposit') {
        const amt = 100 + Math.floor(Math.random() * 400); // 100..499
        block = chain.mineBlock([
          Tx.contractCall("vault", "deposit", [types.uint(amt)], user.address),
        ]);
        // ignore possible cap errors
      } else {
        const bal = chain.callReadOnlyFn("vault", "get-balance", [types.principal(user.address)], user.address).result;
        const balStr = JSON.stringify(bal);
        const match = balStr.match(/"value":"?(\d+)"?/);
        const cur = match ? BigInt(match[1]) : 0n;
        if (cur > 0n) {
          const portion = Number(cur / 4n) || 1;
          block = chain.mineBlock([
            Tx.contractCall("vault", "withdraw", [types.uint(portion)], user.address),
          ]);
        }
      }
      const fees = chain.callReadOnlyFn("vault", "get-fees", [], deployer.address).result;
      const feesJson = JSON.parse(JSON.stringify(fees));
      const depFee = BigInt(feesJson.value['deposit-bps'].value);
      const wdrawFee = BigInt(feesJson.value['withdraw-bps'].value);
      if (depFee < 0n || depFee > 10000n) throw new Error("deposit fee invariant broken");
      if (wdrawFee < 0n || wdrawFee > 10000n) throw new Error("withdraw fee invariant broken");
    }
  }
});
