import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("oracle-aggregator median edge cases", () => {
  let simnet: any;
  let accounts: Map<string, string>;
  let deployer: string;
  let w1: string; let w2: string; let w3: string; let w4: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    w1 = "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5";
    w2 = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG";
    w3 = "ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC";
    w4 = "ST2NEB84ASENDXKYGJPQW86YXQCEFEX2ZQPG87ND";
  });

  it("median odd/even and outlier resistance", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Register with 4 potential oracles, min-sources = 3
    simnet.callPublicFn("oracle-aggregator", "register-pair", [
      Cl.principal(base), Cl.principal(quote),
      Cl.list([Cl.principal(deployer), Cl.principal(w1), Cl.principal(w2), Cl.principal(w3)]),
      Cl.uint(3)
    ], deployer);

    // Whitelist three oracles
    for (const o of [deployer, w1, w2, w3]) {
      simnet.callPublicFn("oracle-aggregator", "add-oracle", [Cl.principal(base), Cl.principal(quote), Cl.principal(o)], deployer);
    }

    // Submit three prices: 900, 1000, 1100 -> median = 1000
    simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(900)], deployer);
    simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(1000)], w1);
    const r3 = simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(1100)], w2);
    expect(r3.result.type).toBe('ok');

    const medOdd = simnet.callReadOnlyFn("oracle-aggregator", "get-median", [Cl.principal(base), Cl.principal(quote)], deployer);
    expect(medOdd.result).toEqual({ type: 'ok', value: { type: 'uint', value: 1000n }});

    // Add an outlier 100000, median with four sorted values [900,1000,1100,100000] = avg of 1000 and 1100 = 1050
    const r4 = simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(100000)], w3);
    expect(r4.result.type).toBe('ok');
    const medEven = simnet.callReadOnlyFn("oracle-aggregator", "get-median", [Cl.principal(base), Cl.principal(quote)], deployer);
    expect(medEven.result).toEqual({ type: 'ok', value: { type: 'uint', value: 1050n }});
  });
});
