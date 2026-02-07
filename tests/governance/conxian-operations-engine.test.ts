import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { initSimnet, type Simnet } from "@stacks/clarinet-sdk";
import { Cl } from "@stacks/transactions";

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe("Conxian Operations Engine", () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  // Helper to mint the Ops Council Seat (u5) to the Operations Engine Contract
  // The contract needs to hold the seat to vote.
  const mintOpsSeat = () => {
    // Operations Engine Principal
    const opsEngine = Cl.contractPrincipal(
      deployer,
      "ops-engine"
    );

    // Mint Seat u5 (Ops) to the contract
    const mint = simnet.callPublicFn(
      "enhanced-governance-nft",
      "mint-seat",
      [opsEngine, Cl.uint(5), Cl.uint(100), Cl.stringAscii("autonomous-agent")],
      deployer
    );
    expect(mint.result).toEqual(Cl.ok(Cl.uint(1)));
  };

  it("allows authorized operator to trigger emergency pause", () => {
    const exec = simnet.callPublicFn(
      "ops-engine",
      "trigger-emergency-pause",
      [],
      deployer
    );
    expect(exec.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it("prevents unauthorized users from triggering emergency pause", () => {
    const exec = simnet.callPublicFn(
      "ops-engine",
      "trigger-emergency-pause",
      [],
      wallet1
    );
    expect(exec.result).toEqual(Cl.error(Cl.uint(6000)));
  });

  it("allows authorized operator to trigger epoch update", () => {
    const exec = simnet.callPublicFn(
      "ops-engine",
      "trigger-epoch-update",
      [],
      deployer
    );
    expect(exec.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it("prevents unauthorized users from triggering epoch update", () => {
    const exec = simnet.callPublicFn(
      "ops-engine",
      "trigger-epoch-update",
      [],
      wallet1
    );
    expect(exec.result).toEqual(Cl.error(Cl.uint(6000)));
  });

  it("returns last action block", () => {
    const result = simnet.callReadOnlyFn(
      "ops-engine",
      "get-last-action",
      [],
      deployer
    );
    expect(result.result).toBeDefined();
  });
});
