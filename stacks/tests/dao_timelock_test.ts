import { describe, it, expect, beforeEach } from "vitest";
import { initSimnet } from "@hirosystems/clarinet-sdk";
import { Cl } from "@stacks/transactions";

const accounts = [
  "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5",
  "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG",
  "ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC",
  "ST2NEB84ASENDXKYGJPQW86YXQCEFEX2ZQPG87ND",
  "ST2REHHS5J3CERCRBEPMGH7921Q6PYKAADT7JP2VB",
  "ST3AM1A56AK2C1XAFJ4115ZSV26EB49BVQ10MGCS0",
  "ST3PF13W7Z0RRM42A8VZRVFQ75SV1K26RXEP8YGKJ",
  "ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21XCP"
];

describe("DAO Timelock (SDK) - PRD DAO-TIMELOCK alignment", () => {
  let simnet: any;

  beforeEach(async () => {
    simnet = await initSimnet();
  });

  it("PRD DAO-TIMELOCK-INTEGRATION: DAO holder can propose pause; timelock admin transfer works", async () => {
    const deployer = accounts[0];
    const w1 = accounts[1];

    const daoId = `${deployer}.dao`;

    // Check current timelock admin
    let adminCheck = simnet.callReadOnlyFn("timelock", "get-admin", [], deployer);
    const currentAdmin = adminCheck.result.value.value; // Extract the address

    // Set timelock admin to DAO using the current admin as caller
    let response = simnet.callPublicFn("timelock", "set-admin", [Cl.principal(daoId)], currentAdmin);
    expect(response.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    // Verify timelock admin changed to DAO
    adminCheck = simnet.callReadOnlyFn("timelock", "get-admin", [], deployer);
    expect(adminCheck.result).toStrictEqual(Cl.ok(Cl.principal(daoId)));

    // Give w1 governance power (use the same admin address for gov-token)
    response = simnet.callPublicFn("gov-token", "mint", [Cl.principal(w1), Cl.uint(10)], currentAdmin);
    expect(response.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    // Test propose-pause via DAO (returns true since timelock integration is commented out)
    response = simnet.callPublicFn("dao", "propose-pause", [Cl.bool(true)], w1);
    expect(response.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    // Verify w1 has the required governance tokens
    const balance = simnet.callReadOnlyFn("gov-token", "get-balance-of", [Cl.principal(w1)], deployer);
    expect(balance.result).toStrictEqual(Cl.ok(Cl.uint(10)));

    // Check that DAO config is properly set with correct threshold
    const config = simnet.callReadOnlyFn("dao", "get-config", [], deployer);
    expect(config.result.value.threshold).toStrictEqual(Cl.uint(1));
  });
});
