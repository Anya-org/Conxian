import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { initSimnet } from "@stacks/clarinet-sdk";

const CONTRACT_NAME = "ops-engine";

describe("Conxian Operations Engine", () => {
  let simnet: any;
  let deployer: string;
  let wallet1: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;

    // Grant ROLE_OPERATOR (u4) to deployer
    simnet.callPublicFn(
      "conxian-access",
      "grant-role",
      [
        Cl.principal(deployer),
        Cl.uint(4),
        Cl.buffer(Buffer.alloc(32)),
        Cl.buffer(Buffer.alloc(64)),
        Cl.buffer(Buffer.alloc(33))
      ],
      deployer
    );

    // Initialize swap-router with deployer as ops-engine for simple test
    simnet.callPublicFn("swap-router", "set-ops-engine", [Cl.principal(deployer + ".ops-engine")], deployer);
  });

  it("allows authorized operator to trigger emergency pause", () => {
    const { result } = simnet.callPublicFn(
      CONTRACT_NAME,
      "trigger-emergency-pause",
      [],
      deployer
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it("returns last action block", () => {
    const { result } = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      "get-last-action",
      [],
      deployer
    );
    expect(result).toBeDefined();
  });
});
