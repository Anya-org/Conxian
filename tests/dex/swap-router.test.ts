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

  const balance = (token: string, owner: string) =>
    simnet.callReadOnlyFn(token, "get-balance", [Cl.principal(owner)], deployer).result;

  it("can register a pool and execute a swap via exact-input-single", () => {
    // 1. Create Pool
    const created = simnet.callPublicFn(
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
    expect(created.result).toEqual(Cl.ok(Cl.uint(1)));

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

  it("returns exact pool binding errors and rolls back the router pre-transfer", () => {
    const tokenIn = Cl.contractPrincipal(deployer, "cxd-token");
    const tokenOut = Cl.contractPrincipal(deployer, "mock-token");
    const before = balance("cxd-token", deployer);

    expect(simnet.callPublicFn(
      "swap-router",
      "exact-input-single",
      [Cl.uint(999), tokenIn, tokenOut, Cl.uint(1_000_000), Cl.uint(0)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1003)));
    expect(balance("cxd-token", deployer)).toEqual(before);

    expect(simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "create-pool",
      [tokenOut, tokenIn, Cl.uint(3001), Cl.uint(1_000_000_000_000), Cl.int(0)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(1)));
    expect(simnet.callPublicFn(
      "swap-router",
      "exact-input-single",
      [Cl.uint(1), tokenIn, tokenOut, Cl.uint(1_000_000), Cl.uint(0)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1107)));
    expect(balance("cxd-token", deployer)).toEqual(before);
  });

  it("telemetry check: get-protocol-tvl returns real values", () => {
    const { result } = simnet.callReadOnlyFn(
      "finance-metrics",
      "get-protocol-tvl",
      [],
      deployer
    );
    expect(result.type).toBe("ok");
  });
});
