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

    // Register existing pool implementation for the pair in factory
    const reg = simnet.callPublicFn("dex-factory", "register-pool", [
      Cl.principal(tokenX),
      Cl.principal(tokenY),
      Cl.contractPrincipal(deployer, "dex-pool"),
    ], deployer);
    expect(reg.result.type).toBe("ok");

    // Provide initial liquidity by passing the pool reference to router's direct function
    const liq = simnet.callPublicFn("dex-router", "add-liquidity-direct", [
      Cl.contractPrincipal(deployer, "dex-pool"),
      Cl.uint(10000),
      Cl.uint(10000),
      Cl.uint(1),
      Cl.uint(simnet.blockHeight + 10)
    ], deployer);
    expect(liq.result.type).toBe("ok");

    // Swap exact-in via router with slippage bound
    const amountIn = 1000;
    const deadline = simnet.blockHeight + 10;
    const swap = simnet.callPublicFn("dex-router", "swap-exact-in-direct", [
      Cl.contractPrincipal(deployer, "dex-pool"),
      Cl.uint(amountIn),
      Cl.uint(800), // min-amount-out slippage bound
      Cl.bool(true),
      Cl.uint(deadline)
    ], deployer);
    expect(swap.result.type).toBe("ok");
  });
});
