import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("oracle-aggregator whitelist debug", () => {
  let simnet: any;
  let accounts: Map<string, string>;
  let deployer: string;
  let wallet1: string;
  let unauthorizedWallet: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    
    // Use distinct addresses to avoid account aliasing 
    wallet1 = "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5"; // Standard wallet_1 address
    unauthorizedWallet = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"; // Standard wallet_2 address
  });

  it("debugs whitelist state", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    console.log("=== INITIAL SETUP ===");
    console.log("deployer:", deployer);
    console.log("wallet1:", wallet1);
    console.log("unauthorizedWallet:", unauthorizedWallet);
    console.log("Are accounts distinct?");
    console.log("deployer !== wallet1:", deployer !== wallet1);
    console.log("deployer !== unauthorizedWallet:", deployer !== unauthorizedWallet);

    // Register pair with deployer as oracle
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

    // Add deployer to whitelist 
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

    console.log("=== CHECKING WHITELIST STATE ===");
    
    // Check if deployer is whitelisted
    const deployerWhitelistResult = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-oracle",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.principal(deployer)
      ],
      deployer
    );
    console.log("Deployer whitelist status:", JSON.stringify(deployerWhitelistResult.result, null, 2));

    // Check if wallet1 is whitelisted
    const wallet1WhitelistResult = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-oracle",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.principal(wallet1)
      ],
      deployer
    );
    console.log("Wallet1 whitelist status:", JSON.stringify(wallet1WhitelistResult.result, null, 2));

    console.log("=== TESTING SUBMISSIONS ===");

    // Submit as deployer (should work)
    const deployerSubmitResult = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1000)
      ],
      deployer
    );
    console.log("Deployer submit result:", JSON.stringify(deployerSubmitResult.result, null, 2));

    // Submit as unauthorizedWallet (should fail - not whitelisted)
    const unauthorizedSubmitResult = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1500)
      ],
      unauthorizedWallet
    );
    console.log("Unauthorized submit result:", JSON.stringify(unauthorizedSubmitResult.result, null, 2));
    expect(unauthorizedSubmitResult.result.type).toBe('err');
    if (unauthorizedSubmitResult.result.type === 'err') {
      expect(unauthorizedSubmitResult.result.value.value).toBe(102n); // ERR_NOT_ORACLE
    }
  });
});
