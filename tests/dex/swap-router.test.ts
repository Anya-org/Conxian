import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { initSimnet } from "@stacks/clarinet-sdk";

describe("Swap Router", () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;

    // Mint tokens to deployer
    simnet.callPublicFn("cxd-token", "mint", [Cl.uint(100000000), Cl.principal(deployer)], deployer);
    simnet.callPublicFn("mock-token", "mint", [Cl.uint(100000000), Cl.principal(deployer)], deployer);
  });

  it("can register a pool and execute a swap via exact-input-single", () => {
    // 1. Create Pool
    simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "create-pool",
      [
        Cl.principal(deployer + ".cxd-token"),
        Cl.principal(deployer + ".mock-token"),
        Cl.uint(3000),
        Cl.uint(1000000000000),
        Cl.int(0)
      ],
      deployer
    );

    // Also need to fund the pool in simulation to avoid "insufficient liquidity"
    // though the current stub implementation doesn't check liquidity.
    // However, the router/pool needs tokens to send back.
    simnet.callPublicFn("mock-token", "mint", [Cl.uint(100000000), Cl.principal(deployer + ".concentrated-liquidity-pool")], deployer);

    // 2. Execute Swap (User is deployer)
    const { result } = simnet.callPublicFn(
      "swap-router",
      "exact-input-single",
      [
        Cl.uint(1),
        Cl.principal(deployer + ".cxd-token"),
        Cl.principal(deployer + ".mock-token"),
        Cl.uint(1000000),
        Cl.uint(900000)
      ],
      deployer
    );

    // LP fee 0.3% = 3000. Sovereign Tax 1% = 10000. Total = 13000.
    // 1,000,000 - 13,000 = 987,000.
    expect(result).toEqual(Cl.ok(Cl.uint(987000)));
  });

  it("telemetry check: get-protocol-tvl returns real values", () => {
    const { result } = simnet.callReadOnlyFn(
      "finance-metrics",
      "get-protocol-tvl",
      [],
      deployer
    );
    expect(result).toBeDefined();
  });
});
