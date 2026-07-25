import { Cl } from "@stacks/transactions";
import { beforeEach, describe, expect, it } from "vitest";
import { simnet } from "../setup-test-env";

const CLP = "concentrated-liquidity-pool";
const SCALE = 1_000_000_000_000n;
const STEP = 49_998_750n;

describe("Concentrated Liquidity Pool", () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let token0: ReturnType<typeof Cl.contractPrincipal>;
  let token1: ReturnType<typeof Cl.contractPrincipal>;

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
    wallet2 = accounts.get("wallet_2")!;
    token0 = Cl.contractPrincipal(deployer, "cxd-token");
    token1 = Cl.contractPrincipal(deployer, "cxvg-token");
  });

  const priceAtTick = (tick: number) =>
    tick >= 0 ? SCALE + BigInt(tick) * STEP : SCALE - BigInt(-tick) * STEP;

  function createPool(
    first = token0,
    second = token1,
    fee = 3000,
    tick = 0,
    caller = deployer,
    price = priceAtTick(tick),
  ) {
    return simnet.callPublicFn(
      CLP,
      "create-pool",
      [first, second, Cl.uint(fee), Cl.uint(price), Cl.int(tick)],
      caller,
    );
  }

  function createdPoolId(result: any): bigint {
    expect(result.type).toBe("ok");
    expect(result.value.type).toBe("uint");
    return result.value.value;
  }

  function okTuple(result: any): Record<string, any> {
    expect(result.type).toBe("ok");
    expect(result.value.type).toBe("tuple");
    return result.value.value;
  }

  function poolCount(): bigint {
    const status = okTuple(simnet.callReadOnlyFn(CLP, "get-protocol-status", [], deployer).result);
    return status["pool-count"].value;
  }

  function balance(token: string, owner: string) {
    return simnet.callReadOnlyFn(token, "get-balance", [Cl.principal(owner)], deployer).result;
  }

  function balanceValue(token: string, owner: string): bigint {
    const result: any = balance(token, owner);
    expect(result.type).toBe("ok");
    expect(result.value.type).toBe("uint");
    return result.value.value;
  }

  it("is deployed", () => {
    expect(simnet.getContractSource(CLP)).toBeDefined();
  });

  it("prevents pool squatting and supports admin-configured registrar creation", () => {
    expect(createPool(token0, token1, 3000, 0, wallet1).result)
      .toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callReadOnlyFn(CLP, "get-pool-id", [token0, token1, Cl.uint(3000)], deployer).result)
      .toEqual(Cl.none());

    expect(simnet.callReadOnlyFn(CLP, "get-admin", [], deployer).result)
      .toEqual(Cl.ok(Cl.standardPrincipal(deployer)));
    expect(simnet.callReadOnlyFn(CLP, "get-pool-registrar", [], deployer).result)
      .toEqual(Cl.ok(Cl.standardPrincipal(deployer)));
    expect(simnet.callPublicFn(CLP, "set-pool-registrar", [Cl.standardPrincipal(wallet1)], wallet2).result)
      .toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callPublicFn(CLP, "set-pool-registrar", [Cl.standardPrincipal(wallet1)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(CLP, "get-pool-registrar", [], deployer).result)
      .toEqual(Cl.ok(Cl.standardPrincipal(wallet1)));

    expect(createPool(token0, token1, 3000, 0, wallet1).result).toEqual(Cl.ok(Cl.uint(1)));
    expect(createPool(token0, token1, 3001, 0, deployer).result).toEqual(Cl.ok(Cl.uint(2)));
    expect(createPool(token0, token1, 3002, 0, wallet2).result)
      .toEqual(Cl.error(Cl.uint(1000)));
  });

  it("authorizes only an explicitly injected contract registrar as immediate caller", () => {
    const forwarder = Cl.contractPrincipal(deployer, "mock-admin-forwarder");
    const expectedPoolId = poolCount() + 1n;
    expect(simnet.callPublicFn(CLP, "set-pool-registrar", [forwarder], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(createPool(token0, token1, 3050, 0, wallet1).result)
      .toEqual(Cl.error(Cl.uint(1000)));

    expect(simnet.callPublicFn(
      "mock-admin-forwarder",
      "forward-clp-create-pool",
      [token0, token1, Cl.uint(3050), Cl.uint(SCALE), Cl.int(0)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(expectedPoolId)));

    expect(simnet.callPublicFn(CLP, "set-pool-registrar", [Cl.standardPrincipal(wallet2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      "mock-admin-forwarder",
      "forward-clp-create-pool",
      [token0, token1, Cl.uint(3051), Cl.uint(SCALE), Cl.int(0)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1000)));
  });

  it("preserves get-pool ABI and returns only coherent configured pool state", () => {
    const poolId = createdPoolId(createPool(token0, token1, 3100).result);
    const expected = Cl.tuple({
      "token-0": token0,
      "token-1": token1,
      fee: Cl.uint(3100),
      liquidity: Cl.uint(0),
      "outstanding-shares": Cl.uint(0),
      "sqrt-price": Cl.uint(SCALE),
      tick: Cl.int(0),
    });

    expect(simnet.callReadOnlyFn(CLP, "get-pool", [Cl.uint(poolId)], deployer).result)
      .toEqual(Cl.ok(Cl.some(expected)));
    expect(simnet.callReadOnlyFn(CLP, "get-pool-state", [Cl.uint(poolId)], deployer).result)
      .toEqual(Cl.ok(expected));
    expect(simnet.callReadOnlyFn(CLP, "get-current-tick", [Cl.uint(poolId)], deployer).result)
      .toEqual(Cl.ok(Cl.int(0)));
    expect(simnet.callReadOnlyFn(CLP, "get-current-sqrt-price", [Cl.uint(poolId)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(SCALE)));
    expect(simnet.callReadOnlyFn(CLP, "get-pool-state", [Cl.uint(999)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1003)));
  });

  it("resolves both token orders, separates fees, rejects duplicates, and preserves nonce sequencing", () => {
    const before = poolCount();
    const firstId = before + 1n;
    const secondId = before + 2n;
    expect(createPool(token0, token1, 3101).result).toEqual(Cl.ok(Cl.uint(firstId)));
    expect(createPool(token0, token1, 3101).result).toEqual(Cl.error(Cl.uint(1104)));
    expect(createPool(token1, token0, 3101).result).toEqual(Cl.error(Cl.uint(1104)));
    expect(simnet.callReadOnlyFn(CLP, "get-pool-id", [token0, token1, Cl.uint(3101)], deployer).result)
      .toEqual(Cl.some(Cl.uint(firstId)));
    expect(simnet.callReadOnlyFn(CLP, "get-pool-id", [token1, token0, Cl.uint(3101)], deployer).result)
      .toEqual(Cl.some(Cl.uint(firstId)));
    expect(simnet.callReadOnlyFn(CLP, "get-pool-id", [token0, token1, Cl.uint(3102)], deployer).result)
      .toEqual(Cl.none());
    expect(createPool(token0, token1, 3102).result).toEqual(Cl.ok(Cl.uint(secondId)));
    expect(simnet.callReadOnlyFn(CLP, "get-pool-id", [token1, token0, Cl.uint(3102)], deployer).result)
      .toEqual(Cl.some(Cl.uint(secondId)));
    expect(poolCount()).toBe(secondId);
  });

  it("enforces fee, tick, pair, and coherent-price boundaries", () => {
    const before = poolCount();
    expect(createPool(token0, token0).result).toEqual(Cl.error(Cl.uint(1100)));
    expect(createPool(token0, token1, 0).result).toEqual(Cl.error(Cl.uint(1101)));
    expect(createPool(token0, token1, 10001).result).toEqual(Cl.error(Cl.uint(1101)));
    expect(createPool(token0, token1, 1, -10000).result).toEqual(Cl.ok(Cl.uint(before + 1n)));
    expect(createPool(token0, token1, 10000, 10000).result).toEqual(Cl.ok(Cl.uint(before + 2n)));
    expect(createPool(token0, token1, 2, -10001).result).toEqual(Cl.error(Cl.uint(1102)));
    expect(createPool(token0, token1, 3, 10001).result).toEqual(Cl.error(Cl.uint(1102)));
    expect(createPool(token0, token1, 4, 0, deployer, SCALE - 1n).result)
      .toEqual(Cl.error(Cl.uint(1103)));
  });

  it("previews exact below, boundary, inside, and above tuples for both rounding modes without mutation", () => {
    const belowId = createdPoolId(createPool(token0, token1, 4001, -20).result);
    const lowerId = createdPoolId(createPool(token0, token1, 4002, -10).result);
    const insideId = createdPoolId(createPool(token0, token1, 4003, 0).result);
    const upperId = createdPoolId(createPool(token0, token1, 4004, 10).result);
    const aboveId = createdPoolId(createPool(token0, token1, 4005, 20).result);
    const args = (id: bigint, roundUp = false) =>
      [Cl.uint(id), Cl.int(-10), Cl.int(10), Cl.uint(1_000_000), Cl.bool(roundUp)];
    const tuple = (amount0: bigint, amount1: bigint, roundUp: boolean) => ({
      "amount-0": Cl.uint(amount0),
      "amount-1": Cl.uint(amount1),
      approximation: Cl.stringAscii("bounded-linear-tick-model"),
      "round-up": Cl.bool(roundUp),
    });
    const regimes = [
      [belowId, tuple(999n, 0n, false), tuple(1000n, 0n, true)],
      [lowerId, tuple(999n, 0n, false), tuple(1000n, 0n, true)],
      [insideId, tuple(499n, 499n, false), tuple(500n, 500n, true)],
      [upperId, tuple(0n, 999n, false), tuple(0n, 1000n, true)],
      [aboveId, tuple(0n, 999n, false), tuple(0n, 1000n, true)],
    ] as const;

    for (const [id, expectedDown, expectedUp] of regimes) {
      const beforePool = simnet.callReadOnlyFn(CLP, "get-pool", [Cl.uint(id)], deployer).result;
      const beforeShares = simnet.callReadOnlyFn(CLP, "get-total-outstanding-shares", [], deployer).result;
      expect(okTuple(simnet.callReadOnlyFn(CLP, "preview-position-amounts", args(id), deployer).result))
        .toEqual(expectedDown);
      expect(okTuple(simnet.callReadOnlyFn(CLP, "preview-position-amounts", args(id, true), deployer).result))
        .toEqual(expectedUp);
      expect(simnet.callReadOnlyFn(CLP, "get-pool", [Cl.uint(id)], deployer).result).toEqual(beforePool);
      expect(simnet.callReadOnlyFn(CLP, "get-total-outstanding-shares", [], deployer).result)
        .toEqual(beforeShares);
    }
    expect(simnet.callReadOnlyFn(CLP, "preview-position-amounts", args(999n), deployer).result)
      .toEqual(Cl.error(Cl.uint(1003)));
  });

  it("keeps preview round-up equal to round-down for exactly divisible amount0 and amount1", () => {
    const amount0Pool = createdPoolId(createPool(token0, token1, 4010, -1).result);
    const amount1Pool = createdPoolId(createPool(token0, token1, 4011, 1).result);
    const preview = (poolId: bigint, liquidity: bigint, roundUp: boolean) => okTuple(
      simnet.callReadOnlyFn(
        CLP,
        "preview-position-amounts",
        [Cl.uint(poolId), Cl.int(0), Cl.int(1), Cl.uint(liquidity), Cl.bool(roundUp)],
        deployer,
      ).result,
    );

    expect(preview(amount0Pool, priceAtTick(1), false)["amount-0"]).toEqual(Cl.uint(STEP));
    expect(preview(amount0Pool, priceAtTick(1), true)["amount-0"]).toEqual(Cl.uint(STEP));
    expect(preview(amount1Pool, SCALE, false)["amount-1"]).toEqual(Cl.uint(STEP));
    expect(preview(amount1Pool, SCALE, true)["amount-1"]).toEqual(Cl.uint(STEP));
  });

  it("rejects unknown or mismatched swap bindings before moving balances and accepts only correct reverse orientation", () => {
    const poolId = createdPoolId(createPool(token0, token1, 4500).result);
    const clp = `${deployer}.${CLP}`;
    expect(simnet.callPublicFn("cxd-token", "mint", [Cl.uint(2_000_000), Cl.standardPrincipal(deployer)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn("cxvg-token", "mint", [Cl.uint(2_000_000), Cl.standardPrincipal(deployer)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn("cxd-token", "mint", [Cl.uint(2_000_000), Cl.contractPrincipal(deployer, CLP)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    const beforeUserCxd = balanceValue("cxd-token", deployer);
    const beforeUserCxvg = balanceValue("cxvg-token", deployer);
    const beforePoolCxd = balanceValue("cxd-token", clp);
    expect(simnet.callPublicFn(
      CLP,
      "swap",
      [Cl.uint(999), Cl.bool(true), Cl.uint(1_000_000), token0, token1, Cl.standardPrincipal(deployer)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1003)));
    expect(simnet.callPublicFn(
      CLP,
      "swap",
      [Cl.uint(poolId), Cl.bool(true), Cl.uint(1_000_000), token1, token0, Cl.standardPrincipal(deployer)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1107)));
    expect(balanceValue("cxd-token", deployer)).toBe(beforeUserCxd);
    expect(balanceValue("cxvg-token", deployer)).toBe(beforeUserCxvg);
    expect(balanceValue("cxd-token", clp)).toBe(beforePoolCxd);

    expect(simnet.callPublicFn(
      CLP,
      "swap",
      [Cl.uint(poolId), Cl.bool(false), Cl.uint(1_000_000), token1, token0, Cl.standardPrincipal(deployer)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(985_500)));
    expect(balanceValue("cxvg-token", deployer)).toBe(beforeUserCxvg - 1_000_000n);
    expect(balanceValue("cxd-token", deployer)).toBe(beforeUserCxd + 985_500n);
    expect(balanceValue("cxd-token", clp)).toBe(beforePoolCxd - 985_500n);
  });

  it("rejects invalid preview ranges and liquidity bounds", () => {
    const poolId = createdPoolId(createPool(token0, token1, 4020).result);
    const preview = (lower: number, upper: number, liquidity: bigint) => simnet.callReadOnlyFn(
      CLP,
      "preview-position-amounts",
      [Cl.uint(poolId), Cl.int(lower), Cl.int(upper), Cl.uint(liquidity), Cl.bool(false)],
      deployer,
    ).result;

    expect(preview(10, 10, 1n)).toEqual(Cl.error(Cl.uint(1105)));
    expect(preview(10, -10, 1n)).toEqual(Cl.error(Cl.uint(1105)));
    expect(preview(-10001, 10, 1n)).toEqual(Cl.error(Cl.uint(1105)));
    expect(preview(-10, 10001, 1n)).toEqual(Cl.error(Cl.uint(1105)));
    expect(preview(-10, 10, 0n)).toEqual(Cl.error(Cl.uint(1106)));
    expect(preview(-10, 10, 100_000_000_000_001n)).toEqual(Cl.error(Cl.uint(1106)));
  });

  it("bootstraps admin and registrar once, then keeps their lifecycles separate", () => {
    expect(simnet.callPublicFn(CLP, "initialize", [Cl.standardPrincipal(wallet1)], wallet2).result)
      .toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callPublicFn(CLP, "initialize", [Cl.standardPrincipal(wallet1)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(CLP, "get-admin", [], deployer).result)
      .toEqual(Cl.ok(Cl.standardPrincipal(wallet1)));
    expect(simnet.callReadOnlyFn(CLP, "get-pool-registrar", [], deployer).result)
      .toEqual(Cl.ok(Cl.standardPrincipal(wallet1)));

    expect(simnet.callPublicFn(CLP, "initialize", [Cl.standardPrincipal(wallet2)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1108)));
    expect(simnet.callPublicFn(CLP, "set-admin", [Cl.standardPrincipal(wallet2)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callPublicFn(CLP, "set-pool-registrar", [Cl.standardPrincipal(deployer)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1000)));

    expect(simnet.callPublicFn(CLP, "set-admin", [Cl.standardPrincipal(wallet2)], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(CLP, "get-admin", [], deployer).result)
      .toEqual(Cl.ok(Cl.standardPrincipal(wallet2)));
    expect(simnet.callReadOnlyFn(CLP, "get-pool-registrar", [], deployer).result)
      .toEqual(Cl.ok(Cl.standardPrincipal(wallet1)));
    expect(simnet.callPublicFn(CLP, "set-pool-registrar", [Cl.standardPrincipal(deployer)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callPublicFn(CLP, "set-pool-registrar", [Cl.standardPrincipal(deployer)], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });
});
