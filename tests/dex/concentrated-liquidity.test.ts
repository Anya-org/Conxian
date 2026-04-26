import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { simnet } from '../setup-test-env';

describe("Concentrated Liquidity System", () => {
    let deployer: string;

  beforeEach(async () => {

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
    // Returns raw uint - concentrated-math returns 1.0 = 1000000000000 for tick 0
    expect(result).toEqual(Cl.uint(1000000000000));
    // Just verify it's a uint type
    expect(result.type).toBeDefined();
  });
});
