import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

// Oracle median, staleness, and TWAP focused tests

describe("oracle-aggregator median/stale/TWAP", () => {
  let simnet: any;
  let accounts: Map<string, any>;
  let deployer: any;
  let w1: string;
  let w2: string;
  let w3: string;

  const setupPair = (base: string, quote: string, oracles: string[], min: number) => {
    const res = simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list(oracles.map(Cl.principal)),
        Cl.uint(min),
      ],
      deployer
    );
    expect(res.result.type).toBe("ok");
    // whitelist all declared oracles
    oracles.forEach((o) => {
      const add = simnet.callPublicFn(
        "oracle-aggregator",
        "add-oracle",
        [Cl.principal(base), Cl.principal(quote), Cl.principal(o)],
        deployer
      );
      expect(add.result.type).toBe("ok");
    });
  };

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  // Use stable, distinct principals (avoid SDK quirk where wallet_1 === deployer)
  w1 = "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5";
    // fallback addresses for more oracles
  // Use stable test principals known in repo tests
  w2 = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG";
  w3 = "ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC";
  });

  it("median: odd and even counts with outlier resistance", () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

  // Four declared oracles, but we'll initially submit from 3 (odd). Use min-sources=3 so first aggregate occurs on third submission
  setupPair(base, quote, [deployer, w1, w2, w3], 3);

    // submissions: 100, 10000 (outlier), 200
    simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(100)], deployer);
    simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(10000)], w1);
    const agg3 = simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(200)], w2);
    // median of [100,200,10000] = 200 (outlier-resistant)
    expect(agg3.result.type).toBe("ok");
    // read-only median
    const medOdd = simnet.callReadOnlyFn("oracle-aggregator", "get-median", [Cl.principal(base), Cl.principal(quote)], deployer);
    expect(medOdd.result).toEqual({ type: "ok", value: { type: "uint", value: 200n } });

  // Even case: add a 300. Relax deviation guard to 50% so 300 vs 200 passes
  const loosenDev = simnet.callPublicFn("oracle-aggregator", "set-params", [Cl.uint(10), Cl.uint(5000)], deployer);
  expect(loosenDev.result.type).toBe("ok");
  // Submit 300 from the fourth oracle declared at registration
    simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(300)], w3);
    const medEven = simnet.callReadOnlyFn("oracle-aggregator", "get-median", [Cl.principal(base), Cl.principal(quote)], deployer);
    // sorted [100,200,300,10000] -> median = (200+300)/2 = 250
    expect(medEven.result).toEqual({ type: "ok", value: { type: "uint", value: 250n } });
  });

  it("staleness: get-price returns ERR_STALE if aggregate older than max-stale", () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    setupPair(base, quote, [deployer, w1], 1);

    // Set tight max-stale = 1 block
    const setParams = simnet.callPublicFn("oracle-aggregator", "set-params", [Cl.uint(1), Cl.uint(2000)], deployer);
    expect(setParams.result.type).toBe("ok");

    // Submit price at height h
    const sub = simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(777)], deployer);
    expect(sub.result.type).toBe("ok");

    // Advance 2 blocks to exceed max-stale
    simnet.mineEmptyBlock();
    simnet.mineEmptyBlock();

    const price = simnet.callReadOnlyFn("oracle-aggregator", "get-price", [Cl.principal(base), Cl.principal(quote)], deployer);
    // Expect ERR_STALE (u106)
    expect(price.result).toEqual({ type: "err", value: { type: "uint", value: 106n } });
  });

  it("TWAP: history ring buffer averages recent aggregates", () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    setupPair(base, quote, [deployer, w1], 1);

  // Loosen deviation guard to allow increasing sequence without rejections
  const loosenDev = simnet.callPublicFn("oracle-aggregator", "set-params", [Cl.uint(10), Cl.uint(5000)], deployer);
  expect(loosenDev.result.type).toBe("ok");

  // Submit sequential prices that respect 50% deviation cap: 100, 150, 200, 250, 300
  const vals = [100, 150, 200, 250, 300];
    vals.forEach((v) => {
      const r = simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(v)], deployer);
      expect(r.result.type).toBe("ok");
      // Ensure an aggregate is written each time (min-sources=1)
      const p = simnet.callReadOnlyFn("oracle-aggregator", "get-price", [Cl.principal(base), Cl.principal(quote)], deployer);
      expect(p.result.type).toBe("ok");
      simnet.mineEmptyBlock();
    });

  // TWAP should be average of the 5 values = (100+150+200+250+300)/5 = 200
  const twap = simnet.callReadOnlyFn("oracle-aggregator", "get-twap", [Cl.principal(base), Cl.principal(quote)], deployer);
  expect(twap.result).toEqual({ type: "uint", value: 200n });
  });
});
