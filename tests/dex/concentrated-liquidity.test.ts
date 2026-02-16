import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { initSimnet } from "@stacks/clarinet-sdk";

describe("Concentrated Liquidity System", () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  it("should calculate sqrt ratio for tick 0", () => {
    const { result } = simnet.callReadOnlyFn(
      "math-lib-concentrated",
      "get-sqrt-ratio-at-tick",
      [Cl.int(0)],
      deployer
    );
    // Returns raw uint
    expect(result).toEqual(Cl.uint(1000000000000));
  });
});
