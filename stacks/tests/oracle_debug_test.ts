import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("oracle-aggregator debug", () => {
  let simnet: any;
  let accounts: Map<string, string>;
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    
    // From GitHub research: Standard test addresses commonly used in Clarinet
    // These are the expected addresses for the standard mnemonics
    wallet1 = "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5"; // wallet_1 standard address
    wallet2 = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"; // wallet_2 standard address  
    wallet3 = "ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC"; // wallet_3 standard address
    
    console.log("=== ACCOUNT DEBUG ===");
    console.log("All accounts from simnet:", Array.from(accounts.keys()));
    for (const [name, address] of accounts.entries()) {
      console.log(`${name}: ${address}`);
    }
    console.log("Using predefined wallet addresses:");
    console.log("deployer:", deployer);
    console.log("wallet1:", wallet1);
    console.log("wallet2:", wallet2);
    console.log("wallet3:", wallet3);
    console.log("Are accounts distinct?");
    console.log("deployer !== wallet1:", deployer !== wallet1);
    console.log("deployer !== wallet2:", deployer !== wallet2);
    console.log("deployer !== wallet3:", deployer !== wallet3);
    console.log("wallet1 !== wallet2:", wallet1 !== wallet2);
    console.log("wallet1 !== wallet3:", wallet1 !== wallet3);
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
    
    // Use basic assertion since custom matchers may not be loaded
    expect(registerResult.result.type).toBe('ok');

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
    expect(addResult.result.type).toBe('ok');

    console.log("=== STEP 3: Submit price as authorized oracle ===");
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
    console.log("Submit result (authorized):", JSON.stringify(submitResult.result, null, 2));
    expect(submitResult.result.type).toBe('ok');

    // Choose an unauthorized wallet (different from deployer)
    const unauthorizedWallet = wallet2; // Use wallet2 as unauthorized wallet
    console.log("=== STEP 4: Try unauthorized submission ===");
    console.log("unauthorized wallet address:", unauthorizedWallet);
    console.log("deployer address:", deployer);
    console.log("Accounts are different:", unauthorizedWallet !== deployer);
    
    // Verify the unauthorized wallet is NOT whitelisted
    const checkWhitelist = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-oracle",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.principal(unauthorizedWallet)
      ],
      deployer
    );
    console.log("unauthorized wallet whitelist status:", JSON.stringify(checkWhitelist.result, null, 2));
    // Result type 'false' indicates boolean false value
    expect(checkWhitelist.result.type).toBe('false');
    
    // This should fail with ERR_NOT_ORACLE (u102) since wallet is not whitelisted
    const unauthorizedResult = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1500)
      ],
      unauthorizedWallet
    );
    console.log("Unauthorized result:", JSON.stringify(unauthorizedResult.result, null, 2));
    expect(unauthorizedResult.result.type).toBe('err');
    expect(unauthorizedResult.result.value.value).toBe(102n); // ERR_NOT_ORACLE

    console.log("=== STEP 5: Try deviation error with another wallet ===");
    
    // Use wallet3 for deviation test
    const deviationWallet = wallet3;
    
    // First add this wallet to whitelist to test deviation
    const addDevWalletResult = simnet.callPublicFn(
      "oracle-aggregator",
      "add-oracle",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.principal(deviationWallet)
      ],
      deployer
    );
    console.log("Add deviation wallet oracle result:", addDevWalletResult.result);
    expect(addDevWalletResult.result.type).toBe('ok');
    
    // Now try submitting a price that exceeds max deviation (20% = 2000 bps)
    // Current price is 1000, so max allowed is 1200 (20% increase) or 800 (20% decrease)
    // Submitting 1500 should trigger ERR_DEVIATION (u107)
    const deviationResult = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1500)  // 50% increase over 1000, exceeds 20% limit
      ],
      deviationWallet
    );
    console.log("Deviation test result:", JSON.stringify(deviationResult.result, null, 2));
    expect(deviationResult.result.type).toBe('err');
    expect(deviationResult.result.value.value).toBe(107n); // ERR_DEVIATION

    console.log("=== STEP 6: Submit valid price within deviation ===");
    
    // Submit a price within 20% deviation (1100 = 10% increase)
    const validDeviationResult = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1100)  // 10% increase, within 20% limit
      ],
      deviationWallet
    );
    console.log("Valid deviation result:", JSON.stringify(validDeviationResult.result, null, 2));
    expect(validDeviationResult.result.type).toBe('ok');

    console.log("=== STEP 7: Get final price ===");
    const priceResult = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "get-price",
      [
        Cl.principal(base),
        Cl.principal(quote)
      ],
      deployer
    );
    console.log("Final price result:", JSON.stringify(priceResult.result, null, 2));

    console.log("=== STEP 8: Get median ===");
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
