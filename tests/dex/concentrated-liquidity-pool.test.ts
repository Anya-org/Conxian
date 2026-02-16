import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { initSimnet } from "@stacks/clarinet-sdk";

describe("Concentrated Liquidity Pool", () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  it("ensures that the contract is deployed", () => {
    const source = simnet.getContractSource("concentrated-liquidity-pool");
    expect(source).toBeDefined();
  });

  it("allows a user to create a pool", () => {
    const { result } = simnet.callPublicFn(
      "concentrated-liquidity-pool",
      "create-pool",
      [
        Cl.principal(deployer + ".cxd-token"),
        Cl.principal(deployer + ".cxs-token"),
        Cl.uint(3000),
        Cl.uint(1000000000000),
        Cl.int(0)
      ],
      deployer
    );
    expect(result).toEqual(Cl.ok(Cl.uint(1)));
  });
});
