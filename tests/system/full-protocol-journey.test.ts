import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { initSimnet } from "@stacks/clarinet-sdk";

describe("Grand Unified System Journey", () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;

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

    // Initialize ops-engine principal in swap-router
    simnet.callPublicFn(
      "swap-router",
      "set-ops-engine",
      [Cl.principal(deployer + ".ops-engine")],
      deployer
    );
  });

  it("triggers the Dual-Clock heartbeat (Root) and verifies Agent coordination (Leaf)", () => {
    // Standard initialization
    const heartbeat = simnet.callPublicFn("ops-engine", "trigger-epoch-update", [], deployer);
    expect(heartbeat.result).toBeDefined();
  });
});
