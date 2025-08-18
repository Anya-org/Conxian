import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("oracle-aggregator debug", () => {
  let simnet: any;
  let accounts: Map<string, any>;
  let deployer: any;
  let wallet1: any;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  it("debugs price calculation and authorization", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    console.log("=== STEP 1: Register pair ===");
    const registerResult = simnet.callPublicFn(
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
    console.log("Register result:", registerResult.result);

    console.log("=== STEP 2: Add oracle to whitelist ===");
    const addResult = simnet.callPublicFn(
      "oracle-aggregator",
      "add-oracle",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.principal(deployer)
      ],
      deployer
    );
    console.log("Add oracle result:", addResult.result);

    console.log("=== STEP 3: Submit price ===");
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
    console.log("Submit events:", submitResult.events);

    console.log("=== STEP 4: Try unauthorized submission ===");
    const unauthorizedResult = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1500)
      ],
      wallet1  // wallet1 is NOT whitelisted
    );
    console.log("Unauthorized result:", JSON.stringify(unauthorizedResult.result, null, 2));
    expect(unauthorizedResult.result.type).toBe('err');
    if (unauthorizedResult.result.type === 'err') {
      expect(unauthorizedResult.result.value.value).toBe(102n); // ERR_NOT_ORACLE
    }

    console.log("=== STEP 5: Get price ===");
    const priceResult = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "get-price",
      [
        Cl.principal(base),
        Cl.principal(quote)
      ],
      deployer
    );
    console.log("Price result:", JSON.stringify(priceResult.result, null, 2));

    console.log("=== STEP 6: Get median ===");
    const medianResult = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "get-median",
      [
        Cl.principal(base),
        Cl.principal(quote)
      ],
      deployer
    );
    console.log("Median result:", JSON.stringify(medianResult.result, null, 2));
  });
});
