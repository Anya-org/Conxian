import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("oracle-aggregator whitelist debug", () => {
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

  it("debugs whitelist state", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    console.log("=== INITIAL SETUP ===");
    console.log("deployer:", deployer);
    console.log("wallet1:", wallet1);

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

    // Submit as wallet1 (should fail)
    const wallet1SubmitResult = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1500)
      ],
      wallet1
    );
    console.log("Wallet1 submit result:", JSON.stringify(wallet1SubmitResult.result, null, 2));
    expect(wallet1SubmitResult.result.type).toBe('err');
    if (wallet1SubmitResult.result.type === 'err') {
      expect(wallet1SubmitResult.result.value.value).toBe(102n);
    }
  });
});
