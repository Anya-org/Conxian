import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("oracle-aggregator account debug", () => {
  let simnet: any;
  let accounts: Map<string, any>;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
  });

  it("debugs account addresses", async () => {
    console.log("=== ALL ACCOUNTS ===");
    for (const [name, account] of accounts.entries()) {
      console.log(`${name}: ${account}`);
    }
  });
});
