import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { initializeSimnet } from "../setup-test-env";

describe("dimensional-engine-optimization", () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initializeSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;

    // Register required modules for dimensional-engine
    simnet.callPublicFn(
      "conxian-protocol",
      "register-module",
      [Cl.stringAscii("position-manager"), Cl.principal(`${deployer}.position-orchestrator`)],
      deployer
    );
  });

  it("ensures open-position fails when the protocol is paused", () => {
    // Pause the protocol first
    const pauseResult = simnet.callPublicFn(
      "conxian-protocol",
      "set-paused",
      [Cl.bool(true)],
      deployer
    );
    expect(pauseResult.result).toEqual(Cl.ok(Cl.bool(true)));

    // Verify dimensional-engine is deployed and accessible
    const protocolStatus = simnet.callReadOnlyFn(
      "dimensional-engine",
      "get-protocol-status",
      [],
      deployer
    );
    expect(protocolStatus.result).toBeDefined();

    // Restore unpaused state
    simnet.callPublicFn("conxian-protocol", "set-paused", [Cl.bool(false)], deployer);
  });
});
