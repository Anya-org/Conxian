import { describe, it, expect, beforeAll } from "vitest";
import { Cl } from "@stacks/transactions";
import { initializeSimnet } from "./setup-test-env";

describe("ALEX CSF Integration", () => {
  let simnet: any;
  let deployer: any;

  beforeAll(async () => {
    simnet = await initializeSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it("should allow registering ALEX adapter as a CSF protocol", () => {
    const admin = simnet.callReadOnlyFn("conxian-protocol", "get-protocol-admin", [], deployer).result;
    const registerCall = simnet.callPublicFn(
      "dex-factory",
      "register-csf-protocol",
      [
        Cl.principal(`${deployer}.alex-adapter`),
        Cl.stringAscii("ALEX Lab Mainnet")
      ],
      deployer
    );
    expect(registerCall.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it("should execute a swap through the ALEX adapter via swap-router", () => {
    const swapCall = simnet.callPublicFn(
      "swap-router",
      "csf-swap",
      [
        Cl.principal(`${deployer}.alex-adapter`),
        Cl.principal(`${deployer}.cxd-token`),
        Cl.principal(`${deployer}.mock-token`),
        Cl.uint(1000000n),
        Cl.uint(900000n)
      ],
      deployer
    );
    expect(swapCall.result).toEqual(Cl.ok(Cl.uint(1000000n)));
  });

  it("should return health telemetry from ALEX adapter", () => {
    const healthCall = simnet.callReadOnlyFn(
      "alex-adapter",
      "get-csf-health",
      [],
      deployer
    );
    expect(healthCall.result).toEqual(
      Cl.ok(Cl.tuple({
        tvl: Cl.uint(100000000000n),
        utilization: Cl.uint(50n),
        "is-active": Cl.bool(true)
      }))
    );
  });
});
