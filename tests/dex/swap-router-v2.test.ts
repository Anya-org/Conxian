import { Cl } from "@stacks/transactions";
import { beforeAll, describe, expect, it } from "vitest";
import { initializeSimnet, simnet } from "../setup-test-env";

const ROUTER = "swap-router";
const POOL = "concentrated-liquidity-pool-v2";
const TOKEN0 = "mock-token";
const TOKEN1 = "mock-reward-token";

function contract(deployer: string, name: string): any {
  return Cl.contractPrincipal(deployer, name);
}

function okTuple(result: any): Record<string, any> {
  expect(result.type, Cl.prettyPrint(result)).toBe("ok");
  expect(result.value.type).toBe("tuple");
  return result.value.value;
}

function someTuple(result: any): Record<string, any> {
  expect(result.type, Cl.prettyPrint(result)).toBe("some");
  expect(result.value.type).toBe("tuple");
  return result.value.value;
}

function fieldUint(tuple: Record<string, any>, key: string): bigint {
  return BigInt(tuple[key].value);
}

describe("swap router V2 direct custody", () => {
  let deployer: string;
  let lp: string;
  let trader: string;
  let recipient: string;
  let token0: any;
  let token1: any;

  function createFundedPool(): bigint {
    const created = simnet.callPublicFn(
      POOL, "create-pool", [token0, token1, Cl.uint(3000), Cl.int(0)], deployer,
    ).result;
    expect(created.type).toBe("ok");
    const poolId = BigInt(created.value.value);
    expect(simnet.callPublicFn(
      POOL, "add-liquidity",
      [Cl.uint(poolId), token0, token1, Cl.int(-120), Cl.int(120),
        Cl.uint(5_000_000), Cl.uint(5_000_000), Cl.uint(1)], lp,
    ).result.type).toBe("ok");
    return poolId;
  }

  function route(poolId: bigint, input: any, output: any, amount: bigint,
    limit: bigint, minimum: bigint, to = trader): any {
    return simnet.callPublicFn(
      ROUTER, "exact-input-single-v2",
      [Cl.uint(poolId), input, output, Cl.uint(amount), Cl.uint(limit),
        Cl.uint(minimum), Cl.principal(to)], trader,
    ).result;
  }

  beforeAll(async () => {
    await initializeSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    lp = accounts.get("wallet_1")!;
    trader = accounts.get("wallet_2")!;
    recipient = accounts.get("wallet_3")!;
    token0 = contract(deployer, TOKEN0);
    token1 = contract(deployer, TOKEN1);
    for (const user of [lp, trader]) {
      expect(simnet.callPublicFn(TOKEN0, "mint", [Cl.uint(50_000_000), Cl.principal(user)], deployer).result)
        .toEqual(Cl.ok(Cl.bool(true)));
      expect(simnet.callPublicFn(TOKEN1, "mint", [Cl.uint(50_000_000), Cl.principal(user)], deployer).result)
        .toEqual(Cl.ok(Cl.bool(true)));
    }
  });

  it("derives and executes both canonical directions without router custody", () => {
    const poolId = createFundedPool();
    const router = `${deployer}.${ROUTER}`;
    const before0 = simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(trader) ?? 0n;
    const down = okTuple(route(poolId, token0, token1, 10_000n, 988_000_000_000n, 1n));
    expect(fieldUint(down, "amount-out")).toBeGreaterThan(0n);
    expect(simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(trader) ?? 0n).toBe(before0 - 10_000n);
    expect(simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(router) ?? 0n).toBe(0n);
    expect(simnet.getAssetsMap().get(`.${TOKEN1}.reward`)?.get(router) ?? 0n).toBe(0n);

    const pool = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(poolId)], trader).result);
    const current = fieldUint(pool, "sqrt-price");
    const up = okTuple(route(poolId, token1, token0, 5_000n, current + 12_000_000_000n, 1n));
    expect(fieldUint(up, "amount-out")).toBeGreaterThan(0n);
    expect(simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(router) ?? 0n).toBe(0n);
    expect(simnet.getAssetsMap().get(`.${TOKEN1}.reward`)?.get(router) ?? 0n).toBe(0n);
  });

  it("rejects invalid pairs and wrong-direction limits before token movement", () => {
    const poolId = createFundedPool();
    const before = simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(trader) ?? 0n;
    expect(route(poolId, token0, token0, 100n, 988_000_000_000n, 1n))
      .toEqual(Cl.error(Cl.uint(2301)));
    expect(route(poolId, token0, token1, 100n, 1_012_000_000_000n, 1n))
      .toEqual(Cl.error(Cl.uint(2316)));
    expect(simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(trader) ?? 0n).toBe(before);
  });

  it("rolls back min-out failure and preserves pool and user balances", () => {
    const poolId = createFundedPool();
    const beforeBalance = simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(trader) ?? 0n;
    const beforePool = Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-pool", [Cl.uint(poolId)], trader,
    ).result);
    expect(route(poolId, token0, token1, 10_000n, 988_000_000_000n, 10_000_000n).type)
      .toBe("err");
    expect(simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(trader) ?? 0n).toBe(beforeBalance);
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-pool", [Cl.uint(poolId)], trader,
    ).result)).toBe(beforePool);
  });

  it("pays an alternate recipient directly and leaves the router empty", () => {
    const poolId = createFundedPool();
    const beforeRecipient = simnet.getAssetsMap().get(`.${TOKEN1}.reward`)?.get(recipient) ?? 0n;
    const swapped = okTuple(route(poolId, token0, token1, 10_000n, 988_000_000_000n, 1n, recipient));
    expect(simnet.getAssetsMap().get(`.${TOKEN1}.reward`)?.get(recipient) ?? 0n)
      .toBe(beforeRecipient + fieldUint(swapped, "amount-out"));
    expect(simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(`${deployer}.${ROUTER}`) ?? 0n).toBe(0n);
    expect(simnet.getAssetsMap().get(`.${TOKEN1}.reward`)?.get(`${deployer}.${ROUTER}`) ?? 0n).toBe(0n);
  });

  it("preserves router pause and V2 source-isolation policy", () => {
    const poolId = createFundedPool();
    expect(simnet.callPublicFn(
      "enhanced-circuit-breaker", "toggle-contract-pause",
      [contract(deployer, ROUTER)], deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(route(poolId, token0, token1, 100n, 988_000_000_000n, 1n))
      .toEqual(Cl.error(Cl.uint(503)));
    expect(simnet.callPublicFn(
      "enhanced-circuit-breaker", "toggle-contract-pause",
      [contract(deployer, ROUTER)], deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));

    expect(simnet.callPublicFn(
      "enhanced-circuit-breaker", "toggle-isolation",
      [contract(deployer, POOL)], deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(route(poolId, token0, token1, 100n, 988_000_000_000n, 1n))
      .toEqual(Cl.error(Cl.uint(504)));
    expect(simnet.callPublicFn(
      "enhanced-circuit-breaker", "toggle-isolation",
      [contract(deployer, POOL)], deployer,
    ).result).toEqual(Cl.ok(Cl.bool(false)));
  });

  it("keeps the legacy exact-input-single ABI and behavior available", () => {
    const created = simnet.callPublicFn(
      "concentrated-liquidity-pool", "create-pool",
      [token0, token1, Cl.uint(3000), Cl.uint(1_000_000_000_000n), Cl.int(0)], deployer,
    ).result;
    expect(created.type).toBe("ok");
    expect(simnet.callPublicFn(
      TOKEN1, "mint", [Cl.uint(1_000_000), contract(deployer, "concentrated-liquidity-pool")], deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const result = simnet.callPublicFn(
      ROUTER, "exact-input-single",
      [Cl.uint(BigInt(created.value.value)), token0, token1, Cl.uint(1_000), Cl.uint(1)], trader,
    ).result;
    expect(result.type).toBe("ok");
    expect(BigInt(result.value.value)).toBeGreaterThan(0n);
  });
});
