import { Cl } from "@stacks/transactions";
import { beforeEach, describe, expect, it } from "vitest";
import { simnet } from "../setup-test-env";

describe("Concentrated Liquidity System", () => {
  let deployer: string;
  const MATH = "math-lib-concentrated";
  const SCALE = 1_000_000_000_000n;
  const STEP = 49_998_750n;

  beforeEach(() => {
    deployer = simnet.getAccounts().get("deployer")!;
  });

  const priceAtTick = (tick: number) =>
    tick >= 0 ? SCALE + BigInt(tick) * STEP : SCALE - BigInt(-tick) * STEP;

  const read = (name: string, args: any[]) =>
    simnet.callReadOnlyFn(MATH, name, args, deployer).result;

  it("uses the documented 1e12 scale for tick zero", () => {
    expect(read("get-sqrt-ratio-at-tick", [Cl.int(0)])).toEqual(Cl.uint(SCALE));
    expect(read("get-price-scale", [])).toEqual(Cl.uint(SCALE));
  });

  it("bounds execution ticks while preserving the wider validation API", () => {
    expect(read("is-valid-tick", [Cl.int(887272)])).toEqual(Cl.bool(true));
    expect(read("is-supported-execution-tick", [Cl.int(-10000)])).toEqual(Cl.bool(true));
    expect(read("is-supported-execution-tick", [Cl.int(10000)])).toEqual(Cl.bool(true));
    expect(read("is-supported-execution-tick", [Cl.int(-10001)])).toEqual(Cl.bool(false));
    expect(read("is-supported-execution-tick", [Cl.int(10001)])).toEqual(Cl.bool(false));
    expect(read("get-sqrt-ratio-at-tick-checked", [Cl.int(-10000)]))
      .toEqual(Cl.ok(Cl.uint(500_012_500_000n)));
    expect(read("get-sqrt-ratio-at-tick-checked", [Cl.int(10000)]))
      .toEqual(Cl.ok(Cl.uint(1_499_987_500_000n)));
    expect(read("get-sqrt-ratio-at-tick-checked", [Cl.int(-10001)]))
      .toEqual(Cl.error(Cl.uint(2001)));
    expect(read("get-sqrt-ratio-at-tick-checked", [Cl.int(10001)]))
      .toEqual(Cl.error(Cl.uint(2001)));
  });

  it("keeps every raw legacy ABI-shape wrapper non-trapping with documented fallbacks", () => {
    expect(read("get-sqrt-ratio-at-tick", [Cl.int(-887272)])).toEqual(Cl.uint(0));
    expect(read("get-sqrt-ratio-at-tick", [Cl.int(887272)])).toEqual(Cl.uint(0));
    expect(read("get-sqrt-ratio-at-tick", [Cl.int(-887273)])).toEqual(Cl.uint(0));
    expect(read("get-sqrt-ratio-at-tick", [Cl.int(887273)])).toEqual(Cl.uint(0));
    expect(read("get-tick-at-sqrt-ratio", [Cl.uint(0)])).toEqual(Cl.int(0));
    expect(read("get-amount0-delta", [Cl.uint(0), Cl.uint(SCALE), Cl.uint(1)]))
      .toEqual(Cl.uint(0));
    expect(read("get-amount1-delta", [Cl.uint(SCALE), Cl.uint(SCALE), Cl.uint(1)]))
      .toEqual(Cl.uint(0));
    expect(read("get-amount0-delta", [Cl.uint(priceAtTick(-1)), Cl.uint(priceAtTick(1)), Cl.uint(0)]))
      .toEqual(Cl.uint(0));
  });

  it("keeps the retained math alias in parity with the canonical contract", () => {
    for (const tick of [-10000, -1, 0, 1, 10000, 887272]) {
      const args = [Cl.int(tick)];
      expect(simnet.callReadOnlyFn("concentrated-math", "get-sqrt-ratio-at-tick", args, deployer).result)
        .toEqual(read("get-sqrt-ratio-at-tick", args));
    }
  });

  it("floors inverse ticks on negative and positive grids", () => {
    for (const tick of [-10000, -100, -10, -1, 0, 1, 10, 100, 10000]) {
      expect(read("get-tick-at-sqrt-ratio-checked", [Cl.uint(priceAtTick(tick))]))
        .toEqual(Cl.ok(Cl.int(tick)));
    }
    expect(read("get-tick-at-sqrt-ratio-checked", [Cl.uint(SCALE - 1n)]))
      .toEqual(Cl.ok(Cl.int(-1)));
    expect(read("get-tick-at-sqrt-ratio-checked", [Cl.uint(priceAtTick(-10) + 1n)]))
      .toEqual(Cl.ok(Cl.int(-10)));
    expect(read("get-tick-at-sqrt-ratio-checked", [Cl.uint(priceAtTick(-10) - 1n)]))
      .toEqual(Cl.ok(Cl.int(-11)));
    expect(read("get-tick-at-sqrt-ratio-checked", [Cl.uint(priceAtTick(10) - 1n)]))
      .toEqual(Cl.ok(Cl.int(9)));
    expect(read("get-tick-at-sqrt-ratio-checked", [Cl.uint(priceAtTick(10) + STEP - 1n)]))
      .toEqual(Cl.ok(Cl.int(10)));
  });

  it("keeps checked inverse monotonic and satisfies floor round trips", () => {
    const prices = [
      priceAtTick(-10000),
      priceAtTick(-100) + 1n,
      priceAtTick(-1),
      SCALE - 1n,
      SCALE,
      SCALE + 1n,
      priceAtTick(100) - 1n,
      priceAtTick(10000),
    ];
    const ticks = prices.map((price) => {
      const result: any = read("get-tick-at-sqrt-ratio-checked", [Cl.uint(price)]);
      expect(result.type).toBe("ok");
      expect(result.value.type).toBe("int");
      const tick = Number(result.value.value);
      expect(priceAtTick(tick)).toBeLessThanOrEqual(price);
      if (tick < 10000) expect(price).toBeLessThan(priceAtTick(tick + 1));
      return tick;
    });
    for (let index = 1; index < ticks.length; index += 1) {
      expect(ticks[index]).toBeGreaterThanOrEqual(ticks[index - 1]);
    }
  });

  it("returns deterministic round-down and round-up amount deltas", () => {
    const lower = Cl.uint(999_500_012_500n);
    const upper = Cl.uint(1_000_499_987_500n);
    const liquidity = Cl.uint(1_000_000);

    expect(read("get-amount0-delta-down", [lower, upper, liquidity])).toEqual(Cl.ok(Cl.uint(999)));
    expect(read("get-amount0-delta-up", [lower, upper, liquidity])).toEqual(Cl.ok(Cl.uint(1000)));
    expect(read("get-amount1-delta-down", [lower, upper, liquidity])).toEqual(Cl.ok(Cl.uint(999)));
    expect(read("get-amount1-delta-up", [lower, upper, liquidity])).toEqual(Cl.ok(Cl.uint(1000)));
  });

  it("orders checked rounding and accepts reversed prices at maximum supported bounds", () => {
    const low = Cl.uint(priceAtTick(-10000));
    const high = Cl.uint(priceAtTick(10000));
    const maxLiquidity = Cl.uint(100_000_000_000_000n);

    for (const [downName, upName] of [
      ["get-amount0-delta-down", "get-amount0-delta-up"],
      ["get-amount1-delta-down", "get-amount1-delta-up"],
    ]) {
      const down: any = read(downName, [low, high, maxLiquidity]);
      const up: any = read(upName, [low, high, maxLiquidity]);
      expect(down.type).toBe("ok");
      expect(up.type).toBe("ok");
      expect(down.value.value).toBeLessThanOrEqual(up.value.value);
      expect(read(downName, [high, low, maxLiquidity])).toEqual(down);
      expect(read(upName, [high, low, maxLiquidity])).toEqual(up);
    }
  });

  it("rejects zero ranges and unsupported prices or liquidity before multiplication", () => {
    const price = Cl.uint(SCALE);
    expect(read("get-amount0-delta-down", [price, price, Cl.uint(1)]))
      .toEqual(Cl.error(Cl.uint(2004)));
    expect(read("get-amount1-delta-up", [Cl.uint(priceAtTick(-10)), Cl.uint(priceAtTick(10)), Cl.uint(100_000_000_000_001n)]))
      .toEqual(Cl.error(Cl.uint(2003)));
    expect(read("get-amount0-delta-down", [Cl.uint(1), Cl.uint(priceAtTick(10)), Cl.uint(1)]))
      .toEqual(Cl.error(Cl.uint(2002)));
    expect(read("get-tick-at-sqrt-ratio-checked", [Cl.uint(priceAtTick(-10000) - 1n)]))
      .toEqual(Cl.error(Cl.uint(2002)));
    expect(read("get-tick-at-sqrt-ratio-checked", [Cl.uint(priceAtTick(10000) + 1n)]))
      .toEqual(Cl.error(Cl.uint(2002)));
  });
});
