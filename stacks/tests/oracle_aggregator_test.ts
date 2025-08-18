import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("oracle-aggregator", () => {
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
    wallet2 = accounts.get("wallet_2") || "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"; // fallback address
  });

  it("registers trading pair with ACL whitelist", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Register trading pair with ACL (fix: min-sources should be <= oracles count)
    const { result } = simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list([Cl.principal(deployer), Cl.principal(wallet1)]), // 2 oracles
        Cl.uint(2) // min-sources = 2, matches oracle count
      ],
      deployer
    );

    expect(result).toEqual({ type: 'ok', value: { type: 'true' } });

    // Add oracle to whitelist
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

    expect(addResult.result).toEqual({ type: 'ok', value: { type: 'true' } });
  });

  it("allows whitelisted oracle to submit price", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Setup pair and whitelist
    simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list([Cl.principal(deployer), Cl.principal(wallet1)]), // 2 oracles
        Cl.uint(1) // min-sources = 1
      ],
      deployer
    );

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

    // Submit price from whitelisted oracle
    const { result } = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1000)
      ],
      wallet1
    );

    // The submit-price function returns aggregation results
    expect(result.type).toBe('ok');
    expect(result.value.type).toBe('tuple');
    expect(result.value.value.price).toEqual({ type: 'uint', value: 1000n });
  });

  it("rejects price submission from non-whitelisted oracle", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Register pair with only wallet1 as authorized oracle
    simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list([Cl.principal(wallet1)]), // Only wallet1 in oracles list
        Cl.uint(1)
      ],
      deployer
    );

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

    // Try to submit price from wallet2 (not whitelisted for this pair)
    const { result } = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1000)
      ],
      wallet2 // wallet2 is not whitelisted for this pair
    );

    expect(result).toEqual({ type: 'err', value: { type: 'uint', value: 102n } }); // err-not-oracle
  });

  it("gets current price after submission", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Setup
    simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list([Cl.principal(deployer), Cl.principal(wallet1)]),
        Cl.uint(1)
      ],
      deployer
    );

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

    // Submit price
    simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1000)
      ],
      wallet1
    );

    // Get current price
    const { result } = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "get-price",
      [
        Cl.principal(base),
        Cl.principal(quote)
      ],
      deployer
    );

    // Should return the submitted price
    expect(result.type).toBe('ok');
  });
});
