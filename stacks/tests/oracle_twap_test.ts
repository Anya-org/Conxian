import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("oracle-aggregator TWAP", () => {
  let simnet: any;
  let accounts: Map<string, string>;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  it("computes average over rolling history", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    simnet.callPublicFn("oracle-aggregator", "register-pair", [
      Cl.principal(base), Cl.principal(quote), Cl.list([Cl.principal(deployer)]), Cl.uint(1)
    ], deployer);
    simnet.callPublicFn("oracle-aggregator", "add-oracle", [Cl.principal(base), Cl.principal(quote), Cl.principal(deployer)], deployer);

    // Submit a few prices across blocks to record history (equal-weighted)
    simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(900)], deployer);
    simnet.callPublicFn("state-anchor", "anchor-state", [Cl.bufferFromHex("0101")], deployer);
    simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(1000)], deployer);
    simnet.callPublicFn("state-anchor", "anchor-state", [Cl.bufferFromHex("0202")], deployer);
    simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(1100)], deployer);

    const twap = simnet.callReadOnlyFn("oracle-aggregator", "get-twap", [Cl.principal(base), Cl.principal(quote)], deployer);
    // Average of 900, 1000, 1100 = 1000
    expect(twap.result).toEqual({ type: 'uint', value: 1000n });
  });
});
