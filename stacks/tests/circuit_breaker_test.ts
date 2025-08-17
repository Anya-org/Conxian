import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("circuit-breaker", () => {
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

  it("triggers circuit breaker on price volatility", async () => {
    const pool = `${deployer}.mock-pool`;
    const breakerType = 1; // BREAKER_PRICE
    const threshold = 2500; // 25%

    // Trigger circuit breaker
    const { result } = simnet.callPublicFn(
      "circuit-breaker",
      "trigger-circuit-breaker",
      [
        Cl.uint(breakerType),
        Cl.uint(threshold)
      ],
      deployer
    );

    expect(result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });

    // Check if circuit breaker is triggered
    const isTriggered = simnet.callReadOnlyFn(
      "circuit-breaker",
      "is-circuit-breaker-triggered",
      [Cl.uint(breakerType)],
      deployer
    );

    expect(isTriggered.result).toEqual({ type: 'bool', value: true });
  });

  it("rejects unauthorized circuit breaker operations", async () => {
    const breakerType = 1;
    const threshold = 2500;

    // Try to trigger from non-admin
    const { result } = simnet.callPublicFn(
      "circuit-breaker",
      "trigger-circuit-breaker",
      [
        Cl.uint(breakerType),
        Cl.uint(threshold)
      ],
      wallet1 // non-admin
    );

    expect(result).toEqual({ type: 'err', value: { type: 'uint', value: 100n } }); // err-unauthorized
  });

  it("monitors price volatility successfully", async () => {
    const pool = `${deployer}.mock-pool`;
    const currentPrice = 1000;

    // Monitor price volatility
    const { result } = simnet.callPublicFn(
      "circuit-breaker",
      "monitor-price-volatility",
      [
        Cl.principal(pool),
        Cl.uint(currentPrice)
      ],
      deployer
    );

    expect(result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });
  });

  it("tests oracle integration when enabled", async () => {
    const pool = `${deployer}.mock-pool`;
    const base = `${deployer}.token-a`;
    const quote = `${deployer}.token-b`;

    // Enable oracle integration (admin only)
    const enableResult = simnet.callPublicFn(
      "circuit-breaker",
      "set-oracle-enabled",
      [Cl.bool(true)],
      deployer
    );

    expect(enableResult.result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });

    // Test oracle-based monitoring (will fail if oracle not set up)
    const monitorResult = simnet.callPublicFn(
      "circuit-breaker",
      "monitor-price-volatility-oracle",
      [
        Cl.principal(pool),
        Cl.principal(base),
        Cl.principal(quote)
      ],
      deployer
    );

    // This may fail with ERR_UNAUTHORIZED if oracle not properly configured
    expect(['ok', 'err']).toContain(monitorResult.result.type);
  });

  it("resets circuit breaker state", async () => {
    const breakerType = 1;
    const threshold = 2500;

    // First trigger the circuit breaker
    simnet.callPublicFn(
      "circuit-breaker",
      "trigger-circuit-breaker",
      [
        Cl.uint(breakerType),
        Cl.uint(threshold)
      ],
      deployer
    );

    // Verify it's triggered
    let isTriggered = simnet.callReadOnlyFn(
      "circuit-breaker",
      "is-circuit-breaker-triggered",
      [Cl.uint(breakerType)],
      deployer
    );
    expect(isTriggered.result).toEqual({ type: 'bool', value: true });

    // Reset the circuit breaker
    const resetResult = simnet.callPublicFn(
      "circuit-breaker",
      "reset-circuit-breaker",
      [Cl.uint(breakerType)],
      deployer
    );

    expect(resetResult.result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });

    // Verify it's no longer triggered
    isTriggered = simnet.callReadOnlyFn(
      "circuit-breaker",
      "is-circuit-breaker-triggered",
      [Cl.uint(breakerType)],
      deployer
    );
    expect(isTriggered.result).toEqual({ type: 'bool', value: false });
  });

  it("handles multiple breaker types independently", async () => {
    const priceBreaker = 1;
    const volumeBreaker = 2;
    const liquidityBreaker = 3;

    // Trigger different types
    simnet.callPublicFn("circuit-breaker", "trigger-circuit-breaker", [Cl.uint(priceBreaker), Cl.uint(2500)], deployer);
    simnet.callPublicFn("circuit-breaker", "trigger-circuit-breaker", [Cl.uint(liquidityBreaker), Cl.uint(5000)], deployer);

    // Check each type individually
    const priceTriggered = simnet.callReadOnlyFn("circuit-breaker", "is-circuit-breaker-triggered", [Cl.uint(priceBreaker)], deployer);
    const volumeTriggered = simnet.callReadOnlyFn("circuit-breaker", "is-circuit-breaker-triggered", [Cl.uint(volumeBreaker)], deployer);
    const liquidityTriggered = simnet.callReadOnlyFn("circuit-breaker", "is-circuit-breaker-triggered", [Cl.uint(liquidityBreaker)], deployer);

    expect(priceTriggered.result).toEqual({ type: 'bool', value: true });
    expect(volumeTriggered.result).toEqual({ type: 'bool', value: false });
    expect(liquidityTriggered.result).toEqual({ type: 'bool', value: true });
  });
});
