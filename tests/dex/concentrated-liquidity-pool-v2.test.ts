import { Cl, cvToValue } from "@stacks/transactions";
import { beforeAll, describe, expect, it } from "vitest";
import { simnet } from "../setup-test-env";

const POOL = "concentrated-liquidity-pool-v2";
const TOKEN0 = "mock-token";
const TOKEN1 = "mock-reward-token";

function contract(deployer: string, name: string): any {
  return Cl.contractPrincipal(deployer, name);
}

function okTuple(result: any): Record<string, any> {
  expect(result.type).toBe("ok");
  expect(result.value.type).toBe("tuple");
  return result.value.value;
}

function someTuple(result: any): Record<string, any> {
  expect(result.type).toBe("some");
  expect(result.value.type).toBe("tuple");
  return result.value.value;
}

function fieldUint(tuple: Record<string, any>, key: string): bigint {
  return BigInt(tuple[key].value);
}

describe("concentrated liquidity pool v2 custody and execution", () => {
  let deployer: string;
  let lp: string;
  let trader: string;
  let token0: any;
  let token1: any;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    lp = accounts.get("wallet_1")!;
    trader = accounts.get("wallet_2")!;
    token0 = contract(deployer, TOKEN0);
    token1 = contract(deployer, TOKEN1);
    for (const owner of [lp, trader]) {
      expect(simnet.callPublicFn(TOKEN0, "mint", [Cl.uint(50_000_000_000), Cl.principal(owner)], deployer).result)
        .toEqual(Cl.ok(Cl.bool(true)));
      expect(simnet.callPublicFn(TOKEN1, "mint", [Cl.uint(50_000_000_000), Cl.principal(owner)], deployer).result)
        .toEqual(Cl.ok(Cl.bool(true)));
    }
  });

  function createPool(initialTick = 0): bigint {
    const result = simnet.callPublicFn(
      POOL,
      "create-pool",
      [token0, token1, Cl.uint(3000), Cl.int(initialTick)],
      deployer,
    ).result;
    expect(result.type, Cl.prettyPrint(result)).toBe("ok");
    return BigInt(result.value.value);
  }

  function add(poolId: bigint, lower = -120, upper = 120): Record<string, any> {
    return okTuple(simnet.callPublicFn(
      POOL,
      "add-liquidity",
      [Cl.uint(poolId), token0, token1, Cl.int(lower), Cl.int(upper),
        Cl.uint(1_000_000), Cl.uint(1_000_000), Cl.uint(1)],
      lp,
    ).result);
  }

  it("derives price from tick and rejects mismatched convenience inputs", () => {
    const poolId = createPool();
    const pool = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(poolId)], deployer).result);
    expect(fieldUint(pool, "sqrt-price")).toBe(1_000_000_000_000n);
    expect(cvToValue(pool["current-tick"])).toBe(0n);
    expect(simnet.callPublicFn(
      POOL,
      "create-pool-checked",
      [token0, token1, Cl.uint(3000), Cl.uint(1_000_000_000_001n), Cl.int(0)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(2303)));
    expect(simnet.callPublicFn(POOL, "create-pool", [token0, token1, Cl.uint(2500), Cl.int(0)], deployer).result)
      .toEqual(Cl.error(Cl.uint(2302)));
  });

  it("couples both custody transfers and rolls all state back on token-1 failure", () => {
    const poolId = createPool();
    expect(simnet.callPublicFn(TOKEN1, "set-fail-transfer", [Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const before0 = simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(lp) ?? 0n;
    expect(simnet.callPublicFn(
      POOL,
      "add-liquidity",
      [Cl.uint(poolId), token0, token1, Cl.int(-120), Cl.int(120),
        Cl.uint(1_000_000), Cl.uint(1_000_000), Cl.uint(1)],
      lp,
    ).result.type).toBe("err");
    expect(simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(lp) ?? 0n).toBe(before0);
    const pool = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(poolId)], deployer).result);
    expect(fieldUint(pool, "position-count")).toBe(0n);
    expect(fieldUint(pool, "initialized-tick-count")).toBe(0n);
    expect(simnet.callPublicFn(TOKEN1, "set-fail-transfer", [Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("records position IDs as canonical entitlement and conserves tick gross/net", () => {
    const poolId = createPool();
    const minted = add(poolId);
    const positionId = fieldUint(minted, "position-id");
    const liquidity = fieldUint(minted, "liquidity");
    const position = someTuple(simnet.callReadOnlyFn(POOL, "get-position", [Cl.uint(positionId)], lp).result);
    expect(position.owner.value).toBe(lp);
    expect(fieldUint(position, "liquidity")).toBe(liquidity);
    expect(cvToValue(position.active)).toBe(true);

    const lower = someTuple(simnet.callReadOnlyFn(POOL, "get-tick", [Cl.uint(poolId), Cl.int(-120)], lp).result);
    const upper = someTuple(simnet.callReadOnlyFn(POOL, "get-tick", [Cl.uint(poolId), Cl.int(120)], lp).result);
    expect(fieldUint(lower, "liquidity-gross")).toBe(liquidity);
    expect(cvToValue(lower["liquidity-net"])).toBe(liquidity);
    expect(fieldUint(upper, "liquidity-gross")).toBe(liquidity);
    expect(cvToValue(upper["liquidity-net"])).toBe(-liquidity);
  });

  it("executes exact input in both directions and reconciles principal, fees, and custody", () => {
    const poolId = createPool();
    add(poolId);

    const upward = okTuple(simnet.callPublicFn(
      POOL,
      "swap-exact-input",
      [Cl.uint(poolId), token1, token0, Cl.bool(false), Cl.uint(10_000),
        Cl.uint(1_012_000_000_000n), Cl.uint(1), Cl.principal(trader)],
      trader,
    ).result);
    expect(fieldUint(upward, "amount-in")).toBe(10_000n);
    expect(fieldUint(upward, "amount-out")).toBeGreaterThan(0n);
    expect(fieldUint(upward, "sqrt-price")).toBeGreaterThan(1_000_000_000_000n);

    const downward = okTuple(simnet.callPublicFn(
      POOL,
      "swap-exact-input",
      [Cl.uint(poolId), token0, token1, Cl.bool(true), Cl.uint(5_000),
        Cl.uint(988_000_000_000n), Cl.uint(1), Cl.principal(trader)],
      trader,
    ).result);
    expect(fieldUint(downward, "amount-out")).toBeGreaterThan(0n);

    const reconciliation = okTuple(simnet.callPublicFn(
      POOL, "get-reconciliation", [Cl.uint(poolId), token0, token1], deployer,
    ).result);
    expect(fieldUint(reconciliation, "custody-shortfall-0")).toBe(0n);
    expect(fieldUint(reconciliation, "custody-shortfall-1")).toBe(0n);
    expect(fieldUint(reconciliation, "protocol-fees-0") + fieldUint(reconciliation, "protocol-fees-1"))
      .toBeGreaterThan(0n);
  });

  it("handles fee-rounding dust with stable zero-output and price-limit errors", () => {
    const poolId = createPool();
    add(poolId);
    const before = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(poolId)], trader).result);

    expect(simnet.callPublicFn(
      POOL,
      "swap-exact-input",
      [Cl.uint(poolId), token1, token0, Cl.bool(false), Cl.uint(1),
        Cl.uint(1_012_000_000_000n), Cl.uint(0), Cl.principal(trader)],
      trader,
    ).result).toEqual(Cl.error(Cl.uint(2322)));
    const afterDust = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(poolId)], trader).result);
    expect(fieldUint(afterDust, "sqrt-price")).toBe(fieldUint(before, "sqrt-price"));

    expect(simnet.callPublicFn(
      POOL,
      "swap-exact-input",
      [Cl.uint(poolId), token0, token1, Cl.bool(true), Cl.uint(100),
        Cl.uint(499_999_999_999n), Cl.uint(0), Cl.principal(trader)],
      trader,
    ).result).toEqual(Cl.error(Cl.uint(2316)));
    expect(simnet.callPublicFn(
      POOL,
      "swap-exact-input",
      [Cl.uint(poolId), token1, token0, Cl.bool(false), Cl.uint(100),
        Cl.uint(2_000_000_000_001n), Cl.uint(0), Cl.principal(trader)],
      trader,
    ).result).toEqual(Cl.error(Cl.uint(2316)));
  });

  it("crosses eight initialized ticks atomically and rejects a ninth without state change", () => {
    const addAdjacentRanges = (count: number): { poolId: bigint; liquidities: bigint[] } => {
      const poolId = createPool();
      const liquidities: bigint[] = [];
      for (let i = 0; i < count; i += 1) {
        const lower = i * 60;
        const upper = lower + 60;
        const minted = okTuple(simnet.callPublicFn(
          POOL,
          "add-liquidity",
          [Cl.uint(poolId), token0, token1, Cl.int(lower), Cl.int(upper),
            Cl.uint(1_000_000), Cl.uint(1_000_000), Cl.uint(1)],
          lp,
        ).result);
        liquidities.push(fieldUint(minted, "liquidity"));
      }
      return { poolId, liquidities };
    };

    const grossToCross = (liquidity: bigint): bigint => {
      const net = (liquidity * 6_000_000_000n + 1_000_000_000_000n - 1n) / 1_000_000_000_000n;
      return (net * 1_000_000n + 997_000n - 1n) / 997_000n;
    };

    const eight = addAdjacentRanges(9);
    const exactEightInput = eight.liquidities.slice(0, 8).reduce((sum, l) => sum + grossToCross(l), 0n);
    const crossed = okTuple(simnet.callPublicFn(
      POOL,
      "swap-exact-input",
      [Cl.uint(eight.poolId), token1, token0, Cl.bool(false), Cl.uint(exactEightInput),
        Cl.uint(1_048_000_000_000n), Cl.uint(1), Cl.principal(trader)],
      trader,
    ).result);
    expect(fieldUint(crossed, "crossings")).toBe(8n);
    expect(fieldUint(crossed, "sqrt-price")).toBe(1_048_000_000_000n);
    const crossedPool = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(eight.poolId)], trader).result);
    expect(fieldUint(crossedPool, "active-liquidity")).toBe(eight.liquidities[8]);

    const nine = addAdjacentRanges(10);
    const exactNineInput = nine.liquidities.slice(0, 9).reduce((sum, l) => sum + grossToCross(l), 0n);
    const beforePool = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(nine.poolId)], trader).result);
    const beforeTrader = simnet.getAssetsMap().get(`.${TOKEN1}.reward`)?.get(trader) ?? 0n;
    expect(simnet.callPublicFn(
      POOL,
      "swap-exact-input",
      [Cl.uint(nine.poolId), token1, token0, Cl.bool(false), Cl.uint(exactNineInput),
        Cl.uint(1_054_000_000_000n), Cl.uint(1), Cl.principal(trader)],
      trader,
    ).result).toEqual(Cl.error(Cl.uint(2318)));
    const afterPool = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(nine.poolId)], trader).result);
    expect(fieldUint(afterPool, "sqrt-price")).toBe(fieldUint(beforePool, "sqrt-price"));
    expect(simnet.getAssetsMap().get(`.${TOKEN1}.reward`)?.get(trader) ?? 0n).toBe(beforeTrader);
  });

  it("assigns fees only to active ranges before and after a crossing", () => {
    const poolId = createPool();
    const first = okTuple(simnet.callPublicFn(
      POOL, "add-liquidity",
      [Cl.uint(poolId), token0, token1, Cl.int(0), Cl.int(60),
        Cl.uint(1_000_000), Cl.uint(1_000_000), Cl.uint(1)], lp,
    ).result);
    const second = okTuple(simnet.callPublicFn(
      POOL, "add-liquidity",
      [Cl.uint(poolId), token0, token1, Cl.int(60), Cl.int(120),
        Cl.uint(1_000_000), Cl.uint(1_000_000), Cl.uint(1)], lp,
    ).result);

    okTuple(simnet.callPublicFn(
      POOL, "swap-exact-input",
      [Cl.uint(poolId), token1, token0, Cl.bool(false), Cl.uint(10_000),
        Cl.uint(1_006_000_000_000n), Cl.uint(1), Cl.principal(trader)], trader,
    ).result);
    const inactiveBefore = okTuple(simnet.callPublicFn(
      POOL, "collect-fees", [Cl.uint(fieldUint(second, "position-id")), token0, token1, Cl.principal(lp)], lp,
    ).result);
    expect(fieldUint(inactiveBefore, "amount0") + fieldUint(inactiveBefore, "amount1")).toBe(0n);

    const pool = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(poolId)], lp).result);
    const firstLiquidity = fieldUint(first, "liquidity");
    const currentSqrt = fieldUint(pool, "sqrt-price");
    const netToBoundary = (firstLiquidity * (1_006_000_000_000n - currentSqrt)
      + 1_000_000_000_000n - 1n) / 1_000_000_000_000n;
    const grossToBoundary = (netToBoundary * 1_000_000n + 997_000n - 1n) / 997_000n;
    okTuple(simnet.callPublicFn(
      POOL, "swap-exact-input",
      [Cl.uint(poolId), token1, token0, Cl.bool(false), Cl.uint(grossToBoundary + 10_000n),
        Cl.uint(1_012_000_000_000n), Cl.uint(1), Cl.principal(trader)], trader,
    ).result);
    const activeAfter = okTuple(simnet.callPublicFn(
      POOL, "collect-fees", [Cl.uint(fieldUint(second, "position-id")), token0, token1, Cl.principal(lp)], lp,
    ).result);
    expect(fieldUint(activeAfter, "amount1")).toBeGreaterThan(0n);
  });

  it("enforces the sixteen initialized-tick bound", () => {
    const poolId = createPool();
    for (let i = 0; i < 15; i += 1) {
      const lower = 600 + i * 60;
      expect(simnet.callPublicFn(
        POOL,
        "add-liquidity",
        [Cl.uint(poolId), token0, token1, Cl.int(lower), Cl.int(lower + 60),
          Cl.uint(1_000_000), Cl.uint(0), Cl.uint(1)],
        lp,
      ).result.type).toBe("ok");
    }
    const bounded = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(poolId)], lp).result);
    expect(fieldUint(bounded, "initialized-tick-count")).toBe(16n);
    expect(simnet.callPublicFn(
      POOL,
      "add-liquidity",
      [Cl.uint(poolId), token0, token1, Cl.int(1500), Cl.int(1560),
        Cl.uint(1_000_000), Cl.uint(0), Cl.uint(1)],
      lp,
    ).result).toEqual(Cl.error(Cl.uint(2310)));
  });

  it("collects fees idempotently, closes the full lot, and deinitializes final ticks", () => {
    const poolId = createPool();
    const minted = add(poolId);
    const positionId = fieldUint(minted, "position-id");
    simnet.callPublicFn(
      POOL,
      "swap-exact-input",
      [Cl.uint(poolId), token1, token0, Cl.bool(false), Cl.uint(20_000),
        Cl.uint(1_012_000_000_000n), Cl.uint(1), Cl.principal(trader)],
      trader,
    );

    const first = okTuple(simnet.callPublicFn(
      POOL, "collect-fees", [Cl.uint(positionId), token0, token1, Cl.principal(lp)], lp,
    ).result);
    expect(fieldUint(first, "amount0") + fieldUint(first, "amount1")).toBeGreaterThan(0n);
    const second = okTuple(simnet.callPublicFn(
      POOL, "collect-fees", [Cl.uint(positionId), token0, token1, Cl.principal(lp)], lp,
    ).result);
    expect(fieldUint(second, "amount0") + fieldUint(second, "amount1")).toBe(0n);

    const closed = okTuple(simnet.callPublicFn(
      POOL,
      "remove-liquidity",
      [Cl.uint(positionId), token0, token1, Cl.uint(0), Cl.uint(0), Cl.principal(lp)],
      lp,
    ).result);
    expect(fieldUint(closed, "amount0") + fieldUint(closed, "amount1")).toBeGreaterThan(0n);
    expect(simnet.callPublicFn(
      POOL,
      "remove-liquidity",
      [Cl.uint(positionId), token0, token1, Cl.uint(0), Cl.uint(0), Cl.principal(lp)],
      lp,
    ).result).toEqual(Cl.error(Cl.uint(2309)));
    const pool = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(poolId)], lp).result);
    expect(fieldUint(pool, "position-count")).toBe(0n);
    expect(fieldUint(pool, "initialized-tick-count")).toBe(0n);
    const closedPnl = okTuple(simnet.callReadOnlyFn(POOL, "get-position-pnl", [Cl.uint(positionId)], lp).result);
    expect(cvToValue(closedPnl.closed)).toBe(true);
    expect(fieldUint(closedPnl, "valuation-sqrt-price")).toBeGreaterThan(0n);
  });

  it("reuses deinitialized tick slots without exhausting the bounded list", () => {
    const poolId = createPool();
    for (let cycle = 0; cycle < 8; cycle += 1) {
      const lower = 600 + cycle * 120;
      const minted = add(poolId, lower, lower + 60);
      const positionId = fieldUint(minted, "position-id");
      expect(simnet.callPublicFn(
        POOL,
        "remove-liquidity",
        [Cl.uint(positionId), token0, token1, Cl.uint(0), Cl.uint(0), Cl.principal(lp)],
        lp,
      ).result.type).toBe("ok");
      const pool = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(poolId)], lp).result);
      expect(fieldUint(pool, "initialized-tick-count")).toBe(0n);
    }
    const reminted = add(poolId, 1620, 1680);
    expect(fieldUint(reminted, "liquidity")).toBeGreaterThan(0n);
    const pool = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(poolId)], lp).result);
    expect(fieldUint(pool, "initialized-tick-count")).toBe(2n);
  });

  it("classifies direct token donations only as reconciliation surplus", () => {
    const poolId = createPool();
    add(poolId);
    expect(simnet.callPublicFn(TOKEN0, "mint", [Cl.uint(777), contract(deployer, POOL)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const reconciliation = okTuple(simnet.callPublicFn(
      POOL, "get-reconciliation", [Cl.uint(poolId), token0, token1], deployer,
    ).result);
    expect(fieldUint(reconciliation, "donation-surplus-0")).toBe(777n);
    expect(fieldUint(reconciliation, "custody-shortfall-0")).toBe(0n);
  });

  it("reports exact PnL semantics and never labels outperformance as positive IL", () => {
    const poolId = createPool();
    const minted = add(poolId);
    const pnl = okTuple(simnet.callReadOnlyFn(
      POOL, "get-position-pnl", [Cl.uint(fieldUint(minted, "position-id"))], lp,
    ).result);
    expect(cvToValue(pnl["price-source"])).toBe("pool-executable-state");
    expect(cvToValue(pnl["calculation-version"])).toBe("clp-v2-linear-v1");
    const negative = cvToValue(pnl["pnl-negative"]);
    if (!negative) expect(fieldUint(pnl, "loss-only-il-token1")).toBe(0n);
  });

  it("keeps protocol fee release and CSF compatibility fail-closed", () => {
    expect(simnet.callPublicFn(POOL, "release-protocol-fees-disabled", [], deployer).result)
      .toEqual(Cl.error(Cl.uint(2321)));
    expect(simnet.callPublicFn(
      POOL, "register-liquidity-marker", [Cl.stringAscii("not-supported")], deployer,
    ).result).toEqual(Cl.error(Cl.uint(2320)));
  });
});
