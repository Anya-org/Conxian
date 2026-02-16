import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { initSimnet } from "@stacks/clarinet-sdk";

const CONTRACT_NAME = "proposal-registry";

describe("Proposal Registry", () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  it("allows adding a proposal", () => {
    const { result } = simnet.callPublicFn(
      CONTRACT_NAME,
      "add-proposal",
      [
        Cl.principal(deployer + ".mock-proposal"),
        Cl.uint(1), // council-id
        Cl.uint(100), // start-block
        Cl.uint(200)  // end-block
      ],
      deployer
    );
    expect(result).toEqual(Cl.ok(Cl.uint(1)));
  });
});
