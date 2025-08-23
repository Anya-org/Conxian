import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("oracle-aggregator staleness enforcement", () => {
  let simnet: any;
  let accounts: Map<string, string>;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  it("returns ERR_STALE when aggregate too old", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Params: max-stale = 2 blocks
    simnet.callPublicFn("oracle-aggregator", "set-params", [Cl.uint(2), Cl.uint(2000)], deployer);

    simnet.callPublicFn("oracle-aggregator", "register-pair", [
      Cl.principal(base), Cl.principal(quote),
      Cl.list([Cl.principal(deployer)]), Cl.uint(1)
    ], deployer);
    simnet.callPublicFn("oracle-aggregator", "add-oracle", [Cl.principal(base), Cl.principal(quote), Cl.principal(deployer)], deployer);

    simnet.callPublicFn("oracle-aggregator", "submit-price", [Cl.principal(base), Cl.principal(quote), Cl.uint(1000)], deployer);

    // Advance blocks artificially by calling a no-op function or multiple submits with same height isn't possible.
    // Use timelock to bump block-height via queued operations (simplified: call read-only twice doesn't change height).
    // Instead, perform dummy contract calls to move block-height.
    simnet.callPublicFn("state-anchor", "anchor-state", [Cl.bufferFromHex("1234")], deployer);
    simnet.callPublicFn("state-anchor", "anchor-state", [Cl.bufferFromHex("5678")], deployer);
    simnet.callPublicFn("state-anchor", "anchor-state", [Cl.bufferFromHex("9abc")], deployer);

    const res = simnet.callReadOnlyFn("oracle-aggregator", "get-price", [Cl.principal(base), Cl.principal(quote)], deployer);
    expect(res.result).toEqual({ type: 'err', value: { type: 'uint', value: 106n }}); // ERR_STALE
  });
});
