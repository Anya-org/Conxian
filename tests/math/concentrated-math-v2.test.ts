import { Cl, cvToValue } from "@stacks/transactions";
import { describe, expect, it } from "vitest";
import { simnet } from "../setup-test-env";

const MATH = "concentrated-math-v2";
const Q = 1_000_000_000_000n;
const MAX_UINT = (1n << 128n) - 1n;

function okValue(result: any): any {
  expect(result.type).toBe("ok");
  return result.value;
}

function tuple(result: any): Record<string, any> {
  const value = okValue(result);
  expect(value.type).toBe("tuple");
  return value.value;
}

function uint(result: any): bigint {
  return BigInt(okValue(result).value);
}

describe("concentrated math v2 linear tick grid", () => {
  const sender = () => simnet.getAccounts().get("deployer")!;

  it("maps the bounded linear grid injectively and floors inverse ticks", () => {
    expect(uint(simnet.callReadOnlyFn(MATH, "tick-to-sqrt-price", [Cl.int(-5000)], sender()).result))
      .toBe(500_000_000_000n);
    expect(uint(simnet.callReadOnlyFn(MATH, "tick-to-sqrt-price", [Cl.int(0)], sender()).result))
      .toBe(Q);
    expect(uint(simnet.callReadOnlyFn(MATH, "tick-to-sqrt-price", [Cl.int(10_000)], sender()).result))
      .toBe(2_000_000_000_000n);
    expect(cvToValue(okValue(simnet.callReadOnlyFn(
      MATH,
      "sqrt-price-to-tick",
      [Cl.uint(999_999_999_999n)],
      sender(),
    ).result))).toBe(-1n);
    expect(simnet.callReadOnlyFn(MATH, "tick-to-sqrt-price", [Cl.int(10_001)], sender()).result)
      .toEqual(Cl.error(Cl.uint(2200)));
  });

  it("returns hand-auditable below, inside, and above principal vectors", () => {
    const liquidity = 1_000_000n;
    const sa = 900_000_000_000n;
    const sb = 1_100_000_000_000n;
    const expected0Floor = liquidity * Q * (sb - sa) / (sb * sa);
    const expected1Floor = liquidity * (sb - sa) / Q;

    expect(uint(simnet.callReadOnlyFn(
      MATH, "amount0-delta", [Cl.uint(sa), Cl.uint(sb), Cl.uint(liquidity), Cl.bool(false)], sender(),
    ).result)).toBe(expected0Floor);
    expect(uint(simnet.callReadOnlyFn(
      MATH, "amount1-delta", [Cl.uint(sa), Cl.uint(sb), Cl.uint(liquidity), Cl.bool(false)], sender(),
    ).result)).toBe(expected1Floor);

    const below = tuple(simnet.callReadOnlyFn(
      MATH, "principal-at-price", [Cl.uint(800_000_000_000n), Cl.int(-1000), Cl.int(1000), Cl.uint(liquidity)], sender(),
    ).result);
    expect(BigInt(below.amount0.value)).toBe(expected0Floor);
    expect(BigInt(below.amount1.value)).toBe(0n);

    const inside = tuple(simnet.callReadOnlyFn(
      MATH, "principal-at-price", [Cl.uint(Q), Cl.int(-1000), Cl.int(1000), Cl.uint(liquidity)], sender(),
    ).result);
    expect(BigInt(inside.amount0.value)).toBe(liquidity * Q * (sb - Q) / (sb * Q));
    expect(BigInt(inside.amount1.value)).toBe(liquidity * (Q - sa) / Q);

    const above = tuple(simnet.callReadOnlyFn(
      MATH, "principal-at-price", [Cl.uint(1_200_000_000_000n), Cl.int(-1000), Cl.int(1000), Cl.uint(liquidity)], sender(),
    ).result);
    expect(BigInt(above.amount0.value)).toBe(0n);
    expect(BigInt(above.amount1.value)).toBe(expected1Floor);
  });

  it("ceil-rounds mint requirements and floor-rounds burn claims", () => {
    const floor = uint(simnet.callReadOnlyFn(
      MATH, "amount0-delta", [Cl.uint(Q), Cl.uint(1_010_000_000_000n), Cl.uint(100_000_001), Cl.bool(false)], sender(),
    ).result);
    const ceil = uint(simnet.callReadOnlyFn(
      MATH, "amount0-delta", [Cl.uint(Q), Cl.uint(1_010_000_000_000n), Cl.uint(100_000_001), Cl.bool(true)], sender(),
    ).result);
    expect(ceil).toBeGreaterThanOrEqual(floor);
    expect(ceil - floor).toBeLessThanOrEqual(1n);

    const quote = tuple(simnet.callReadOnlyFn(
      MATH, "quote-position", [Cl.uint(Q), Cl.int(-100), Cl.int(100), Cl.uint(1_000_000), Cl.uint(1_000_000)], sender(),
    ).result);
    expect(BigInt(quote.liquidity.value)).toBe(100_000_000n);
    expect(BigInt(quote.amount0.value)).toBeLessThanOrEqual(1_000_000n);
    expect(BigInt(quote.amount1.value)).toBe(1_000_000n);
  });

  it("guards add, sub, multiply, divide, and ceil-div boundaries", () => {
    expect(simnet.callReadOnlyFn(MATH, "checked-add-public", [Cl.uint(MAX_UINT), Cl.uint(1)], sender()).result)
      .toEqual(Cl.error(Cl.uint(2204)));
    expect(simnet.callReadOnlyFn(MATH, "checked-sub-public", [Cl.uint(0), Cl.uint(1)], sender()).result)
      .toEqual(Cl.error(Cl.uint(2204)));
    expect(simnet.callReadOnlyFn(MATH, "checked-mul-public", [Cl.uint(MAX_UINT), Cl.uint(2)], sender()).result)
      .toEqual(Cl.error(Cl.uint(2204)));
    expect(simnet.callReadOnlyFn(MATH, "checked-div-public", [Cl.uint(1), Cl.uint(0)], sender()).result)
      .toEqual(Cl.error(Cl.uint(2205)));
    expect(uint(simnet.callReadOnlyFn(MATH, "checked-ceil-div-public", [Cl.uint(10), Cl.uint(3)], sender()).result))
      .toBe(4n);
  });

  it("applies the declared exact-input next-price formulas", () => {
    const liquidity = 100_000_000n;
    const input = 1_000n;
    const token0Expected = (liquidity * Q * Q + (liquidity * Q + input * Q) - 1n)
      / (liquidity * Q + input * Q);
    expect(uint(simnet.callReadOnlyFn(
      MATH, "next-sqrt-from-token0", [Cl.uint(Q), Cl.uint(liquidity), Cl.uint(input)], sender(),
    ).result)).toBe(token0Expected);
    expect(uint(simnet.callReadOnlyFn(
      MATH, "next-sqrt-from-token1", [Cl.uint(Q), Cl.uint(liquidity), Cl.uint(input)], sender(),
    ).result)).toBe(Q + input * Q / liquidity);
  });
});
