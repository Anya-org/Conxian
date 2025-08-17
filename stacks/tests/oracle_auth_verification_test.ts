import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("oracle-aggregator authorization verification", () => {
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

  it("verifies authorization logic works", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;
    
    // Create a fake oracle address that's definitely not whitelisted
    const fakeOracle = "STC5KHM41H6WHAST7MWWDD807YSPRQKJ68T330BQ"; // Use same format but it's fake
    const fakeOracleClPrincipal = Cl.principal(fakeOracle);

    // Register pair with wallet1 as oracle (deployer = wallet1 in this environment)
    simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list([Cl.principal(wallet1)]),
        Cl.uint(1)
      ],
      deployer
    );

    // Add wallet1 to whitelist (deployer = wallet1)
    simnet.callPublicFn(
      "oracle-aggregator",
      "add-oracle",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.principal(wallet1)
      ],
      deployer
    );

    console.log("=== TESTING AUTHORIZATION FUNCTIONS ===");
    
    // Test is-oracle function with whitelisted oracle
    const isOracleWhitelisted = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-oracle",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.principal(wallet1)
      ],
      deployer
    );
    console.log("Wallet1 is-oracle result:", JSON.stringify(isOracleWhitelisted.result, null, 2));

    // Test is-oracle function with fake oracle (definitely not whitelisted)
    const isOracleFake = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-oracle",
      [
        Cl.principal(base),
        Cl.principal(quote),
        fakeOracleClPrincipal
      ],
      deployer
    );
    console.log("Fake oracle is-oracle result:", JSON.stringify(isOracleFake.result, null, 2));

    console.log("=== TESTING SUBMISSIONS ===");

    // Test authorized submission (wallet1)
    const authorizedResult = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1000)
      ],
      wallet1
    );
    console.log("Authorized submission result:", JSON.stringify(authorizedResult.result, null, 2));

    // To properly test authorization failure, I need to either:
    // 1. Remove wallet1 from whitelist and try again, or
    // 2. Create a different account scenario
    
    // Let's test removing from whitelist
    console.log("=== REMOVING FROM WHITELIST ===");
    const removeResult = simnet.callPublicFn(
      "oracle-aggregator",
      "remove-oracle",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.principal(wallet1)
      ],
      deployer
    );
    console.log("Remove oracle result:", JSON.stringify(removeResult.result, null, 2));

    // Check if wallet1 is still whitelisted
    const isOracleAfterRemoval = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-oracle",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.principal(wallet1)
      ],
      deployer
    );
    console.log("Wallet1 is-oracle after removal:", JSON.stringify(isOracleAfterRemoval.result, null, 2));

    // Now try to submit again (should fail)
    const unauthorizedResult = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(2000)
      ],
      wallet1
    );
    console.log("Unauthorized submission result:", JSON.stringify(unauthorizedResult.result, null, 2));

    // This should fail with ERR_NOT_ORACLE (102)
    expect(unauthorizedResult.result.type).toBe("err");
    if (unauthorizedResult.result.type === "err") {
      expect(unauthorizedResult.result.value.value).toBe(102n);
    }
  });
});
