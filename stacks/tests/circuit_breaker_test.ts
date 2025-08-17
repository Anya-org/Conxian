import { Clarinet, Tx, Chain, Account, types } from "clarinet";

Clarinet.test({
  name: "Circuit Breaker: triggers on volatility threshold and records state",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;

    // Initially not triggered
    let status = chain.callReadOnlyFn("circuit-breaker", "risk-summary", [], deployer.address);
    status.result.expectOk();

    // Manually trigger breaker
    let block = chain.mineBlock([
      Tx.contractCall("circuit-breaker", "trigger-circuit-breaker", [types.uint(1), types.uint(2500)], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Verify triggered
    const triggered = chain.callReadOnlyFn("circuit-breaker", "is-circuit-breaker-triggered", [types.uint(1)], deployer.address);
    triggered.result.expectBool(true);
  }
});

Clarinet.test({
  name: "Circuit Breaker: monitors price volatility and auto-triggers when threshold exceeded",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const pool = deployer.address + ".vault"; // reuse an existing contract principal as mock pool id

    // Seed a window with a start price 1000
    chain.mineBlock([
      Tx.contractCall("circuit-breaker", "monitor-price-volatility", [types.principal(pool), types.uint(1000)], deployer.address)
    ]);

    // Large move to drive >20% volatility (e.g., price to 1400)
    chain.mineBlock([
      Tx.contractCall("circuit-breaker", "monitor-price-volatility", [types.principal(pool), types.uint(1400)], deployer.address)
    ]);

    const triggered = chain.callReadOnlyFn("circuit-breaker", "is-circuit-breaker-triggered", [types.uint(1)], deployer.address);
    triggered.result.expectBool(true);
  }
});

Clarinet.test({
  name: "Circuit Breaker: emergency pause and resume toggles system state",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;

    let block = chain.mineBlock([
      Tx.contractCall("circuit-breaker", "emergency-pause", [], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    let status = chain.callReadOnlyFn("circuit-breaker", "risk-summary", [], deployer.address);
    status.result.expectOk();

    block = chain.mineBlock([
      Tx.contractCall("circuit-breaker", "emergency-resume", [], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});
