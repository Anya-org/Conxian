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
    wallet2 = accounts.get("wallet_2")!;
  });

  it("registers trading pair with ACL whitelist", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Register trading pair with ACL
    const { result } = simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list([Cl.principal(deployer)]),
        Cl.uint(2)
      ],
      deployer
    );

    expect(result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });

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

    expect(addResult.result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });
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
        Cl.list([Cl.principal(deployer)]),
        Cl.uint(2)
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

    expect(result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });
  });

  it("rejects price submission from non-whitelisted oracle", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Register pair but don't whitelist wallet2
    simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list([Cl.principal(deployer)]),
        Cl.uint(2)
      ],
      deployer
    );

    // Try to submit price from non-whitelisted oracle
    const { result } = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1000)
      ],
      wallet2
    );

    expect(result).toEqual({ type: 'err', value: { type: 'uint', value: 1001n } }); // err-not-authorized
  });

  it("calculates TWAP from ring buffer history", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Setup
    simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list([Cl.principal(deployer)]),
        Cl.uint(2)
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

    // Submit multiple prices to build history
    const prices = [1000, 1100, 1200, 1300, 1400];
    for (const price of prices) {
      simnet.callPublicFn(
        "oracle-aggregator",
        "submit-price",
        [
          Cl.principal(base),
          Cl.principal(quote),
          Cl.uint(price)
        ],
        wallet1
      );
      simnet.mineBlock();
    }

    // Get TWAP
    const { result } = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "get-twap",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(3) // last 3 prices
      ],
      deployer
    );

    // Should average last 3 prices: (1200 + 1300 + 1400) / 3 = 1300
    expect(result).toEqual({ type: 'ok', value: { type: 'uint', value: 1300n } });
  });

  it("allows admin to pause/unpause pair", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Register pair
    simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list([Cl.principal(deployer)]),
        Cl.uint(2)
      ],
      deployer
    );

    // Pause pair
    const pauseResult = simnet.callPublicFn(
      "oracle-aggregator",
      "pause-pair",
      [
        Cl.principal(base),
        Cl.principal(quote)
      ],
      deployer
    );

    expect(pauseResult.result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });

    // Check pair is paused
    const statusResult = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-pair-paused",
      [
        Cl.principal(base),
        Cl.principal(quote)
      ],
      deployer
    );

    expect(statusResult.result).toEqual({ type: 'bool', value: true });
  });
});

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

    expect(addResult.result).toBeOk(Cl.bool(true));
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
        Cl.list([Cl.principal(deployer)]),
        Cl.uint(2)
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

    expect(result).toBeOk(Cl.bool(true));
  });

  it("rejects price submission from non-whitelisted oracle", async () => {
    const wallet2 = accounts.get("wallet_2")!;

    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Register pair but don't whitelist wallet2
    simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list([Cl.principal(deployer)]),
        Cl.uint(2)
      ],
      deployer
    );

    // Try to submit price from non-whitelisted oracle
    const { result } = simnet.callPublicFn(
      "oracle-aggregator",
      "submit-price",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(1000)
      ],
      wallet2
    );

    expect(result).toBeErr(Cl.uint(1001)); // err-not-authorized
  });

  it("calculates TWAP from ring buffer history", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Setup
    simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list([Cl.principal(deployer)]),
        Cl.uint(2)
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

    // Submit multiple prices to build history
    const prices = [1000, 1100, 1200, 1300, 1400];
    for (const price of prices) {
      simnet.callPublicFn(
        "oracle-aggregator",
        "submit-price",
        [
          Cl.principal(base),
          Cl.principal(quote),
          Cl.uint(price)
        ],
        wallet1
      );
      simnet.mineBlock();
    }

    // Get TWAP
    const { result } = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "get-twap",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.uint(3) // last 3 prices
      ],
      deployer
    );

    // Should average last 3 prices: (1200 + 1300 + 1400) / 3 = 1300
    expect(result).toBeOk(Cl.uint(1300));
  });

  it("allows admin to pause/unpause pair", async () => {
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Register pair
    simnet.callPublicFn(
      "oracle-aggregator",
      "register-pair",
      [
        Cl.principal(base),
        Cl.principal(quote),
        Cl.list([Cl.principal(deployer)]),
        Cl.uint(2)
      ],
      deployer
    );

    // Pause pair
    const pauseResult = simnet.callPublicFn(
      "oracle-aggregator",
      "pause-pair",
      [
        Cl.principal(base),
        Cl.principal(quote)
      ],
      deployer
    );

    expect(pauseResult.result).toBeOk(Cl.bool(true));

    // Check pair is paused
    const statusResult = simnet.callReadOnlyFn(
      "oracle-aggregator",
      "is-pair-paused",
      [
        Cl.principal(base),
        Cl.principal(quote)
      ],
      deployer
    );

    expect(statusResult.result).toBeBool(true);
  });
});
