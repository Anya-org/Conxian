import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("oracle-aggregator median calculation debug", () => {
  let simnet: any;
  let accounts: Map<string, any>;
  let deployer: any;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  it("debugs step by step median calculation", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Register pair with deployer as oracle
    simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list([Cl.principal(deployer)]),
        Cl.uint(1)
      ],
      deployer
    );

    // Add deployer to whitelist
    simnet.callPublicFn(
      "oracle-aggregator",
      "add-oracle",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.principal(deployer)
      ],
      deployer
    );

    console.log("=== BEFORE FIRST SUBMISSION ===");
    
    // Check price-count
    const countBefore = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "get-price-count",
      [Cl.principal(base), Cl.principal(quote)],
      deployer
    );
    console.log("Price count before:", JSON.stringify(countBefore.result, null, 2));

    // Check median
    const medianBefore = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "get-median",
      [Cl.principal(base), Cl.principal(quote)],
      deployer
    );
    console.log("Median before:", JSON.stringify(medianBefore.result, null, 2));

    console.log("=== FIRST SUBMISSION ===");
    
    // Submit first price
    const submitResult = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1000)
      ],
      deployer
    );
    console.log("Submit result:", JSON.stringify(submitResult.result, null, 2));

    console.log("=== AFTER FIRST SUBMISSION ===");
    
    // Check price-count
    const countAfter = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "get-price-count",
      [Cl.principal(base), Cl.principal(quote)],
      deployer
    );
    console.log("Price count after:", JSON.stringify(countAfter.result, null, 2));

    // Check median
    const medianAfter = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "get-median",
      [Cl.principal(base), Cl.principal(quote)],
      deployer
    );
    console.log("Median after:", JSON.stringify(medianAfter.result, null, 2));

    // Check final price
    const priceAfter = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "get-price",
      [Cl.principal(base), Cl.principal(quote)],
      deployer
    );
    console.log("Price after:", JSON.stringify(priceAfter.result, null, 2));
  });
});
