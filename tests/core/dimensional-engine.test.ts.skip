// ⚡ BOLT: Test for optimized pre-flight checks in dimensional-engine.clar
import { Cl, ClarityType, cvToHex } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { initSimnet } from "@stacks/clarinet-sdk";

const positionManagerContract = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.position-manager";
const dimensionalEngineContract = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.dimensional-engine";
const conxianProtocolContract = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.conxian-protocol";
const sip010TokenContract = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.mock-sip-010-token";
const collateralManagerContract = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.collateral-manager";
const riskManagerContract = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.risk-manager";

describe("dimensional-engine-optimization", () => {
  let simnet: any;
  let accounts: Map<string, any>;
  let deployer: any;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;

    // Register mock manager contracts before each test
    simnet.callPublicFn(
      conxianProtocolContract,
      "register-module",
      [Cl.stringAscii("position-manager"), Cl.principal(positionManagerContract)],
      deployer
    );
    simnet.callPublicFn(
      conxianProtocolContract,
      "register-module",
      [Cl.stringAscii("collateral-manager"), Cl.principal(collateralManagerContract)],
      deployer
    );
    simnet.callPublicFn(
      conxianProtocolContract,
      "register-module",
      [Cl.stringAscii("risk-manager"), Cl.principal(riskManagerContract)],
      deployer
    );
  });

  it("ensures open-position fails when the protocol is paused", () => {
    simnet.callPublicFn(
      conxianProtocolContract,
      "set-paused",
      [Cl.bool(true)],
      deployer
    );

    const { result } = simnet.callPublicFn(
      dimensionalEngineContract,
      "open-position",
      [
        Cl.principal(sip010TokenContract),
        Cl.uint(100),
        Cl.uint(2),
        Cl.bool(true),
        Cl.none(),
        Cl.none(),
      ],
      deployer
    );
    expect(result).toBeErr(Cl.uint(5000)); // ERR_CONTRACT_PAUSED
  });

  it("ensures open-position succeeds when the protocol is not paused", () => {
    simnet.callPublicFn(
      conxianProtocolContract,
      "set-paused",
      [Cl.bool(false)],
      deployer
    );

    const { result } = simnet.callPublicFn(
      dimensionalEngineContract,
      "open-position",
      [
        Cl.principal(sip010TokenContract),
        Cl.uint(100),
        Cl.uint(2),
        Cl.bool(true),
        Cl.none(),
        Cl.none(),
      ],
      deployer
    );
    expect(result).toBeOk(Cl.uint(1));
  });

  it("ensures close-position fails when the protocol is paused", () => {
    simnet.callPublicFn(
      conxianProtocolContract,
      "set-paused",
      [Cl.bool(true)],
      deployer
    );

    const { result } = simnet.callPublicFn(
      dimensionalEngineContract,
      "close-position",
      [
        Cl.uint(1),
        Cl.principal(sip010TokenContract),
        Cl.none(),
      ],
      deployer
    );
    expect(result).toBeErr(Cl.uint(5000)); // ERR_CONTRACT_PAUSED
  });

  it("ensures deposit-funds fails when the protocol is paused", () => {
    simnet.callPublicFn(
      conxianProtocolContract,
      "set-paused",
      [Cl.bool(true)],
      deployer
    );

    const { result } = simnet.callPublicFn(
      dimensionalEngineContract,
      "deposit-funds",
      [
        Cl.uint(100),
        Cl.contractPrincipal(deployer, "mock-sip-010-token"),
      ],
      deployer
    );
    expect(result).toBeErr(Cl.uint(5000)); // ERR_CONTRACT_PAUSED
  });

  it("ensures withdraw-funds fails when the protocol is paused", () => {
    simnet.callPublicFn(
      conxianProtocolContract,
      "set-paused",
      [Cl.bool(true)],
      deployer
    );

    const { result } = simnet.callPublicFn(
      dimensionalEngineContract,
      "withdraw-funds",
      [
        Cl.uint(100),
        Cl.contractPrincipal(deployer, "mock-sip-010-token"),
      ],
      deployer
    );
    expect(result).toBeErr(Cl.uint(5000)); // ERR_CONTRACT_PAUSED
  });
});
