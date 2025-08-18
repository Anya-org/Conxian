import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("oracle-aggregator account debug", () => {
  let simnet: any;
  let accounts: Map<string, any>;

  beforeEach(async () => {
    // Try explicit path to Clarinet.toml
    simnet = await initSimnet("./Clarinet.toml");
    accounts = simnet.getAccounts();
  });

  it("debugs account addresses", async () => {
    console.log("=== ALL ACCOUNTS ===");
    console.log("Total accounts found:", accounts.size);
    for (const [name, account] of accounts.entries()) {
      console.log(`${name}: ${account}`);
    }
    
    console.log("\n=== SIMNET INFO ===");
    console.log("Simnet deployer:", simnet.deployer);
    
    // Try to access accounts by name
    const deployer = accounts.get("deployer");
    const wallet1 = accounts.get("wallet_1");
    const wallet2 = accounts.get("wallet_2");
    const wallet3 = accounts.get("wallet_3");
    
    console.log("\n=== INDIVIDUAL ACCESS ===");
    console.log("Deployer from map:", deployer);
    console.log("Wallet_1 from map:", wallet1);
    console.log("Wallet_2 from map:", wallet2);
    console.log("Wallet_3 from map:", wallet3);
  });
});
