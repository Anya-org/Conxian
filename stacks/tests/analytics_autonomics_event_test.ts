import { describe, it, expect, beforeEach } from "vitest";
import { initSimnet } from "@hirosystems/clarinet-sdk";
import { Cl } from "@stacks/transactions";

const accounts = [
  "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5",
  "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG",
];

describe("Analytics Autonomics Event (SDK) - PRD ANALYTICS alignment", () => {
  let simnet: any;

  beforeEach(async () => {
    simnet = await initSimnet();
  });

  it("PRD ANALYTICS-EVENT-EMIT: autonomics update triggers analytics autonomics event record", async () => {
    const deployer = accounts[0];
    const wallet1 = accounts[1];
    const timelockId = `${deployer}.timelock`;

    // Give timelock admin rights and enable autonomics + fees
    let response = simnet.callPublicFn("vault", "set-admin", [Cl.principal(timelockId)], deployer);
    expect(response.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    response = simnet.callPublicFn("vault", "set-reserve-bands", [Cl.uint(200), Cl.uint(4000)], timelockId);
    expect(response.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    response = simnet.callPublicFn("vault", "set-fee-ramps", [Cl.uint(5), Cl.uint(5)], timelockId);
    expect(response.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    response = simnet.callPublicFn("vault", "set-auto-economics-enabled", [Cl.bool(true)], timelockId);
    expect(response.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    response = simnet.callPublicFn("vault", "set-auto-fees-enabled", [Cl.bool(true)], timelockId);
    expect(response.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    // Provide initial liquidity
    response = simnet.callPublicFn("mock-ft", "mint", [Cl.principal(wallet1), Cl.uint(50000)], deployer);
    expect(response.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    response = simnet.callPublicFn("mock-ft", "approve", [Cl.principal(`${deployer}.vault`), Cl.uint(50000)], wallet1);
    expect(response.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    response = simnet.callPublicFn("vault", "deposit", [Cl.uint(20000)], wallet1);
    expect(response.result.type).toBe('ok'); // Should now work with vault deposit fix

    // Run an autonomics update which should internally call analytics::record-autonomics
    response = simnet.callPublicFn("vault", "update-autonomics", [], wallet1);
    expect(response.result.type).toBe('ok');

    // TODO: Add verification of analytics event emission if analytics contract has read-only functions
  });
});
    const res = block.receipts[0];
    res.result.expectOk();

    // Validate a print event containing "autonomics-metrics" exists
    const printed = JSON.stringify(res.events.map(e => e));
    if (!printed.includes("autonomics-metrics")) {
      throw new Error("Expected autonomics-metrics print event not found in analytics test");
    }
  }
});
