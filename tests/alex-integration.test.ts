import { describe, it, expect, beforeAll } from "vitest";
import { Cl } from "@stacks/transactions";
import { initializeSimnet } from "./setup-test-env";

describe("ALEX CSF simnet fixtures", () => {
  let simnet: any;
  let deployer: any;

  beforeAll(async () => {
    simnet = await initializeSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;

    // Mint tokens for testing
    simnet.callPublicFn("cxd-token", "mint", [Cl.uint(100000000), Cl.principal(deployer)], deployer);
    simnet.callPublicFn("mock-token", "mint", [Cl.uint(100000000), Cl.principal(deployer + ".swap-router")], deployer);
  });

  it("registers the simnet ALEX adapter fixture as a CSF protocol", () => {
    const registerCall = simnet.callPublicFn(
      "dex-factory",
      "register-csf-protocol",
      [
        Cl.principal(`${deployer}.alex-adapter`),
        Cl.stringAscii("ALEX simnet fixture")
      ],
      deployer
    );
    expect(registerCall.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it("executes a deterministic swap through the simnet helper fixture", () => {
    const swapCall = simnet.callPublicFn(
      "swap-router",
      "csf-swap",
      [
        Cl.principal(`${deployer}.alex-adapter`),
        Cl.principal(`${deployer}.cxd-token`),
        Cl.principal(`${deployer}.mock-token`),
        Cl.uint(1000000),
        Cl.uint(900000)
      ],
      deployer
    );
    expect(swapCall.result).toEqual(Cl.ok(Cl.uint(1000000)));
  });

  it("returns deterministic telemetry from the simnet reserve fixture", () => {
    const healthCall = simnet.callPublicFn(
      "alex-adapter",
      "get-csf-health",
      [],
      deployer
    );
    expect(healthCall.result).toEqual(
      Cl.ok(Cl.tuple({
        tvl: Cl.uint(0),
        utilization: Cl.uint(50),
        "is-active": Cl.bool(true)
      }))
    );
  });
});
