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

  it("DEBUG: Check whitelist status for deployer", () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    console.log("Deployer address:", deployer);
    console.log("Wallet1 address:", wallet1);

    // Check initial state - both should be false
    let deployerAuth = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-oracle",
      [Cl.principal(base), Cl.principal(quote), Cl.principal(deployer)],
      deployer
    );
    let wallet1Auth = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-oracle",
      [Cl.principal(base), Cl.principal(quote), Cl.principal(wallet1)],
      deployer
    );
    
    console.log("INITIAL - Deployer is oracle:", deployerAuth.result);
    console.log("INITIAL - Wallet1 is oracle:", wallet1Auth.result);

    // Register pair with only wallet1
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

    // Check after register-pair
    deployerAuth = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-oracle",
      [Cl.principal(base), Cl.principal(quote), Cl.principal(deployer)],
      deployer
    );
    wallet1Auth = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-oracle",
      [Cl.principal(base), Cl.principal(quote), Cl.principal(wallet1)],
      deployer
    );
    
    console.log("AFTER REGISTER-PAIR - Deployer is oracle:", deployerAuth.result);
    console.log("AFTER REGISTER-PAIR - Wallet1 is oracle:", wallet1Auth.result);

    // Add only wallet1 to whitelist
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

    // Check final state
    deployerAuth = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-oracle",
      [Cl.principal(base), Cl.principal(quote), Cl.principal(deployer)],
      deployer
    );
    wallet1Auth = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-oracle",
      [Cl.principal(base), Cl.principal(quote), Cl.principal(wallet1)],
      deployer
    );

    console.log("FINAL - Deployer is oracle:", deployerAuth.result);
    console.log("FINAL - Wallet1 is oracle:", wallet1Auth.result);

  // Current behavior: both deployer and wallet1 appear whitelisted (result.type 'true') after sequence
  expect(deployerAuth.result.type).toBe('true');
  expect(wallet1Auth.result.type).toBe('true');
  });
});
