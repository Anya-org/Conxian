import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("oracle-aggregator proper authorization test", () => {
  let simnet: any;
  let accounts: Map<string, any>;
  let deployer: any;
  let wallet1: any;
  let wallet2: any;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
    wallet2 = accounts.get("wallet_2")!;
  });

  it("tests authorization with different accounts", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    console.log("=== ACCOUNT ADDRESSES ===");
    console.log("deployer:", deployer);
    console.log("wallet1:", wallet1);
    console.log("wallet2:", wallet2);

    // Register pair with wallet1 as oracle
    const registerResult = simnet.callPublicFn(
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
    console.log("Register result:", registerResult.result);

    // Add wallet1 to whitelist
    const addResult = simnet.callPublicFn(
      "oracle-aggregator",
      "add-oracle",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.principal(wallet1)
      ],
      deployer
    );
    console.log("Add oracle result:", addResult.result);

    console.log("=== TESTING AUTHORIZED SUBMISSION ===");
    // Submit as wallet1 (should work)
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
    console.log("Authorized result:", JSON.stringify(authorizedResult.result, null, 2));

    console.log("=== TESTING UNAUTHORIZED SUBMISSION ===");
    // Submit as wallet2 (should fail - not whitelisted)
    const unauthorizedResult = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1500)
      ],
      wallet2
    );
    console.log("Unauthorized result:", JSON.stringify(unauthorizedResult.result, null, 2));

    console.log("=== TESTING DEPLOYER SUBMISSION ===");
    // Submit as deployer (should fail - not whitelisted)
    const deployerResult = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(2000)
      ],
      deployer
    );
    console.log("Deployer result:", JSON.stringify(deployerResult.result, null, 2));
  });
});
