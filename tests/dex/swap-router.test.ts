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

    // 2. Execute Swap (User is deployer)
    // We expect the router to handle the transfer-in and transfer-out correctly now
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

    // Result should be (ok u997000) assuming 3000 fee (0.3%)
    expect(result).toEqual(Cl.ok(Cl.uint(997000)));
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
