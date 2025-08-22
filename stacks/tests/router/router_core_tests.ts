import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

// Core DEX router/factory happy paths and slippage bounds

describe("DEX Router + Factory core", () => {
  let simnet: any;
  let accounts: Map<string, any>;
  let deployer: any;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  it("registers pools via factory and swaps exact-in with slippage bound", () => {
    // Minimal two-token pool registration using factory + router
    const tokenX = `${deployer}.avg-token`;
    const tokenY = `${deployer}.avlp-token`;

    // Assume factory has a register method and router uses it or reads registry
    const reg = simnet.callPublicFn("dex-factory", "create-pool", [
      Cl.principal(tokenX),
      Cl.principal(tokenY),
      Cl.uint(30),      // lp-fee-bps
      Cl.uint(5)        // protocol-fee-bps (< lp-fee)
    ], deployer);
    expect(reg.result.type).toBe("ok");

    // Provide initial liquidity to the pool
    const liq = simnet.callPublicFn("dex-pool", "add-liquidity", [
      Cl.uint(10000),
      Cl.uint(10000),
      Cl.uint(1),
      Cl.uint(999999)
    ], deployer);
    expect(liq.result.type).toBe("ok");

    // Swap exact-in via router with slippage bound
    const amountIn = 1000;
    const deadline = 999999;
    const swap = simnet.callPublicFn("dex-router", "swap-exact-in", [
      Cl.principal(tokenX),
      Cl.principal(tokenY),
      Cl.uint(amountIn),
      Cl.uint(800), // min-amount-out slippage bound
      Cl.bool(true),
      Cl.uint(deadline)
    ], deployer);
    expect(swap.result.type).toBe("ok");
  });
});
