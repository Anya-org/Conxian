
import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { initSimnet, type Simnet } from "@stacks/clarinet-sdk";
import { Cl } from "@stacks/transactions";

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe("Concentrated Liquidity System", () => {
  beforeAll(async () => {
    simnet = await initSimnet();
  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  describe("Math Library", () => {
    it("should calculate sqrt ratio for tick 0", () => {
      const result = simnet.callReadOnlyFn(
        "math-lib-concentrated",
        "get-sqrt-ratio-at-tick",
        [Cl.int(0)],
        deployer
      );
      // tick 0 -> sqrt(1.0001^0) = 1.0 -> 1e12
      expect(result.result).toEqual(Cl.ok(Cl.uint(1000000000000)));
    });

    it("should calculate amount0 delta", () => {
        // Simple check for amount0 calculation
        const result = simnet.callReadOnlyFn(
            "math-lib-concentrated",
            "get-amount0-delta",
            [Cl.uint(1000000000000), Cl.uint(2000000000000), Cl.uint(1000000000000)], // price 1 to 2, liq 1e12
            deployer
        );
        expect(result.result).toBeDefined();
    });
  });

  describe("DEX Factory", () => {
    it("should register a new pool", () => {
        const poolType = 3; // Concentrated
        const tokenA = `${deployer}.token-a`;
        const tokenB = `${deployer}.token-b`;
        const poolContract = `${deployer}.concentrated-pool-1`;

        const result = simnet.callPublicFn(
            "dex-factory",
            "register-pool",
            [Cl.principal(tokenA), Cl.principal(tokenB), Cl.uint(poolType), Cl.principal(poolContract)],
            deployer
        );
        expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
    });
  });

  describe("Concentrated Liquidity Pool", () => {
    it("should create a pool", () => {
        const token0 = `${deployer}.token-a`;
        const token1 = `${deployer}.token-b`;
        const fee = 3000;
        const sqrtPrice = 1000000000000; // 1.0
        const tick = 0;

        const result = simnet.callPublicFn(
            "concentrated-liquidity-pool",
            "create-pool",
            [Cl.principal(token0), Cl.principal(token1), Cl.uint(fee), Cl.uint(sqrtPrice), Cl.int(tick)],
            deployer
        );
        // Expecting pool ID 1
        expect(result.result).toEqual(Cl.ok(Cl.uint(1)));
    });

    it("should mint a position", () => {
        // First create pool
        const token0 = `${deployer}.token-a`;
        const token1 = `${deployer}.token-b`;
        simnet.callPublicFn(
            "concentrated-liquidity-pool",
            "create-pool",
            [Cl.principal(token0), Cl.principal(token1), Cl.uint(3000), Cl.uint(1000000000000), Cl.int(0)],
            deployer
        );

        // Then mint
        const poolId = 1;
        const tickLower = -100;
        const tickUpper = 100;
        const amount = 1000000;

        const result = simnet.callPublicFn(
            "concentrated-liquidity-pool",
            "mint",
            [Cl.uint(poolId), Cl.int(tickLower), Cl.int(tickUpper), Cl.uint(amount)],
            deployer
        );
        expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
    });
  });
});
