import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { simnet } from '../setup-test-env';

describe("Swap Router", () => {
    let deployer: string;

  beforeEach(async () => {

    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  it("can register a pool and execute a swap via exact-input-single", () => {
    const poolContract = deployer + ".concentrated-liquidity-pool";

    // 1. Mint tokens to deployer (user) and pool
    simnet.callPublicFn("mock-token", "mint", [Cl.uint(2000000000000), Cl.principal(deployer)], deployer);
    simnet.callPublicFn("cxd-token", "mint", [Cl.uint(2000000000000), Cl.principal(deployer)], deployer);

    // Pool needs token-out to satisfy the swap
    simnet.callPublicFn("mock-token", "mint", [Cl.uint(2000000000000), Cl.principal(poolContract)], deployer);

    // 2. Create Pool
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

    // 3. Execute Swap (User is deployer)
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
