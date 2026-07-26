import crypto from "crypto";
import { ec as EC } from "elliptic";
import { Cl, cvToValue } from "@stacks/transactions";
import { beforeAll, describe, expect, it } from "vitest";
import { initializeSimnet, simnet } from "../setup-test-env";

const MANAGER = "liquidity-manager";
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

describe("liquidity manager V2 execution integration", () => {
  let deployer: string;
  let owner: string;
  let other: string;
  let token0: any;
  let token1: any;
  const key = new EC("secp256k1").genKeyPair();

  function setCompliance(user: string) {
    const userHash = crypto.createHash("sha256").update(user).digest();
    expect(simnet.callPublicFn(
      "regulatory-adapter", "register-user-hash",
      [Cl.principal(user), Cl.buffer(userHash)], deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const hash = simnet.callReadOnlyFn(
      "regulatory-adapter", "get-sip018-hash",
      [Cl.principal(user), Cl.stringAscii("USA"), Cl.uint(1)], deployer,
    ).result as any;
    const hashBytes = Buffer.from(hash.value.value.replace(/^0x/, ""), "hex");
    const signature = key.sign(hashBytes, { canonical: true });
    const sig = Buffer.concat([
      Buffer.from(signature.r.toArray("be", 32)),
      Buffer.from(signature.s.toArray("be", 32)),
      Buffer.from([signature.recoveryParam]),
    ]);
    expect(simnet.callPublicFn(
      "regulatory-adapter", "verify-and-update-compliance",
      [Cl.principal(user), Cl.stringAscii("USA"), Cl.uint(1), Cl.buffer(sig)], deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
  }

  function createPool(active = true): bigint {
    const created = simnet.callPublicFn(
      POOL, "create-pool", [token0, token1, Cl.uint(3000), Cl.int(0)], deployer,
    ).result;
    expect(created.type).toBe("ok");
    const poolId = BigInt(created.value.value);
    if (!active) {
      expect(simnet.callPublicFn(
        POOL, "set-pool-active", [Cl.uint(poolId), Cl.bool(false)], deployer,
      ).result).toEqual(Cl.ok(Cl.bool(false)));
    }
    return poolId;
  }

  function open(poolId: bigint, caller = owner, lower = -120, upper = 120,
    max0 = 1_000_000n, max1 = 1_000_000n, minimum = 1n): any {
    return simnet.callPublicFn(
      MANAGER, "open-position-v2",
      [Cl.uint(poolId), token0, token1, Cl.int(lower), Cl.int(upper),
        Cl.uint(max0), Cl.uint(max1), Cl.uint(minimum)], caller,
    ).result;
  }

  beforeAll(async () => {
    await initializeSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    owner = accounts.get("wallet_1")!;
    other = accounts.get("wallet_2")!;
    token0 = contract(deployer, TOKEN0);
    token1 = contract(deployer, TOKEN1);

    const pubkey = Buffer.from(key.getPublic(true, "hex"), "hex");
    expect(simnet.callPublicFn(
      "regulatory-adapter", "update-authority",
      [Cl.principal(deployer), Cl.buffer(pubkey)], deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    setCompliance(owner);

    for (const user of [owner, other]) {
      expect(simnet.callPublicFn(TOKEN0, "mint", [Cl.uint(50_000_000), Cl.principal(user)], deployer).result)
        .toEqual(Cl.ok(Cl.bool(true)));
      expect(simnet.callPublicFn(TOKEN1, "mint", [Cl.uint(50_000_000), Cl.principal(user)], deployer).result)
        .toEqual(Cl.ok(Cl.bool(true)));
    }
  });

  it("opens one canonical lot and keeps custody, V2 state, and manager metadata exact", () => {
    const poolId = createPool();
    const before0 = simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(owner) ?? 0n;
    const before1 = simnet.getAssetsMap().get(`.${TOKEN1}.reward`)?.get(owner) ?? 0n;
    const opened = okTuple(open(poolId));
    const positionId = fieldUint(opened, "position-id");
    const amount0 = fieldUint(opened, "amount0");
    const amount1 = fieldUint(opened, "amount1");

    const managed = someTuple(simnet.callReadOnlyFn(
      MANAGER, "get-v2-managed-position", [Cl.uint(positionId)], owner,
    ).result);
    const canonical = someTuple(simnet.callReadOnlyFn(
      POOL, "get-position", [Cl.uint(positionId)], owner,
    ).result);
    expect(managed.owner.value).toBe(owner);
    expect(canonical.owner.value).toBe(owner);
    expect(fieldUint(managed, "pool-id")).toBe(poolId);
    expect(fieldUint(managed, "liquidity")).toBe(fieldUint(canonical, "liquidity"));
    expect(fieldUint(managed, "deposited-0")).toBe(fieldUint(canonical, "deposited-0"));
    expect(fieldUint(managed, "deposited-1")).toBe(fieldUint(canonical, "deposited-1"));
    expect((simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(owner) ?? 0n)).toBe(before0 - amount0);
    expect((simnet.getAssetsMap().get(`.${TOKEN1}.reward`)?.get(owner) ?? 0n)).toBe(before1 - amount1);
    expect(simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(`${deployer}.${MANAGER}`) ?? 0n).toBe(0n);
    expect(simnet.getAssetsMap().get(`.${TOKEN1}.reward`)?.get(`${deployer}.${MANAGER}`) ?? 0n).toBe(0n);
  });

  it("fails closed for wrong pair, inactive pool, invalid range/amount, and compliance", () => {
    const poolId = createPool();
    expect(open(poolId, owner, -120, 120, 1_000_000n, 1_000_000n, 1n).type).toBe("ok");
    expect(simnet.callPublicFn(
      MANAGER, "open-position-v2",
      [Cl.uint(poolId), token1, token0, Cl.int(-120), Cl.int(120),
        Cl.uint(1_000_000), Cl.uint(1_000_000), Cl.uint(1)], owner,
    ).result).toEqual(Cl.error(Cl.uint(2022)));
    expect(open(createPool(false))).toEqual(Cl.error(Cl.uint(2307)));
    expect(open(poolId, owner, -121, 120).type).toBe("err");
    expect(open(poolId, owner, -120, 120, 0n, 0n).type).toBe("err");
    expect(open(poolId, other)).toEqual(Cl.error(Cl.uint(2003)));
  });

  it("allows only the canonical owner to close once, including against legacy manager admin", () => {
    const poolId = createPool();
    const positionId = fieldUint(okTuple(open(poolId)), "position-id");
    const args = [Cl.uint(positionId), token0, token1, Cl.uint(0), Cl.uint(0)];
    expect(simnet.callPublicFn(MANAGER, "close-position-v2", args, other).result)
      .toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callPublicFn(MANAGER, "close-position-v2", args, deployer).result)
      .toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callPublicFn(MANAGER, "close-position-v2", args, owner).result.type).toBe("ok");
    const managed = someTuple(simnet.callReadOnlyFn(
      MANAGER, "get-v2-managed-position", [Cl.uint(positionId)], owner,
    ).result);
    expect(cvToValue(managed.active)).toBe(false);
    expect(simnet.callPublicFn(MANAGER, "close-position-v2", args, owner).result)
      .toEqual(Cl.error(Cl.uint(2020)));
  });

  it("atomically closes and reopens on successful rebalance", () => {
    const poolId = createPool();
    const oldId = fieldUint(okTuple(open(poolId)), "position-id");
    const result = okTuple(simnet.callPublicFn(
      MANAGER, "rebalance-position-v2",
      [Cl.uint(oldId), token0, token1, Cl.int(-60), Cl.int(180),
        Cl.uint(1_000_000), Cl.uint(1_000_000), Cl.uint(1), Cl.uint(0), Cl.uint(0)], owner,
    ).result);
    const newId = BigInt(result["new-position-id"].value);
    const oldManaged = someTuple(simnet.callReadOnlyFn(
      MANAGER, "get-v2-managed-position", [Cl.uint(oldId)], owner,
    ).result);
    const newManaged = someTuple(simnet.callReadOnlyFn(
      MANAGER, "get-v2-managed-position", [Cl.uint(newId)], owner,
    ).result);
    const oldCanonical = someTuple(simnet.callReadOnlyFn(POOL, "get-position", [Cl.uint(oldId)], owner).result);
    const newCanonical = someTuple(simnet.callReadOnlyFn(POOL, "get-position", [Cl.uint(newId)], owner).result);
    expect(cvToValue(oldManaged.active)).toBe(false);
    expect(cvToValue(oldCanonical.closed)).toBe(true);
    expect(cvToValue(newManaged.active)).toBe(true);
    expect(cvToValue(newCanonical.active)).toBe(true);
    expect(BigInt(oldManaged["replaced-by"].value.value)).toBe(newId);
    expect(BigInt(newManaged.replaces.value.value)).toBe(oldId);
  });

  it("rolls back balances, old lot, ticks, and metadata when replacement add fails", () => {
    const poolId = createPool();
    const oldId = fieldUint(okTuple(open(poolId)), "position-id");
    const before0 = simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(owner) ?? 0n;
    const before1 = simnet.getAssetsMap().get(`.${TOKEN1}.reward`)?.get(owner) ?? 0n;
    const beforePoolResult = simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(poolId)], owner).result;
    const beforePool = someTuple(beforePoolResult);
    const beforeCanonical = Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-position", [Cl.uint(oldId)], owner,
    ).result);
    const beforeManaged = Cl.prettyPrint(simnet.callReadOnlyFn(
      MANAGER, "get-v2-managed-position", [Cl.uint(oldId)], owner,
    ).result);
    const beforeLower = Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-tick", [Cl.uint(poolId), Cl.int(-120)], owner,
    ).result);
    const beforeUpper = Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-tick", [Cl.uint(poolId), Cl.int(120)], owner,
    ).result);
    const beforeTargetLower = Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-tick", [Cl.uint(poolId), Cl.int(-60)], owner,
    ).result);
    const beforeTargetUpper = Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-tick", [Cl.uint(poolId), Cl.int(180)], owner,
    ).result);

    const failed = simnet.callPublicFn(
      MANAGER, "rebalance-position-v2",
      [Cl.uint(oldId), token0, token1, Cl.int(-60), Cl.int(180),
        Cl.uint(1_000_000), Cl.uint(1_000_000), Cl.uint(1_000_000_000_000n),
        Cl.uint(0), Cl.uint(0)], owner,
    ).result;
    expect(failed.type).toBe("err");

    const oldManaged = someTuple(simnet.callReadOnlyFn(
      MANAGER, "get-v2-managed-position", [Cl.uint(oldId)], owner,
    ).result);
    const oldCanonical = someTuple(simnet.callReadOnlyFn(POOL, "get-position", [Cl.uint(oldId)], owner).result);
    const afterPool = someTuple(simnet.callReadOnlyFn(POOL, "get-pool", [Cl.uint(poolId)], owner).result);
    expect(cvToValue(oldManaged.active)).toBe(true);
    expect(cvToValue(oldManaged["replaced-by"])).toBe(null);
    expect(cvToValue(oldCanonical.active)).toBe(true);
    expect(cvToValue(oldCanonical.closed)).toBe(false);
    expect(fieldUint(afterPool, "position-count")).toBe(fieldUint(beforePool, "position-count"));
    expect(fieldUint(afterPool, "initialized-tick-count")).toBe(fieldUint(beforePool, "initialized-tick-count"));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-pool", [Cl.uint(poolId)], owner,
    ).result)).toBe(Cl.prettyPrint(beforePoolResult));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-position", [Cl.uint(oldId)], owner,
    ).result)).toBe(beforeCanonical);
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(
      MANAGER, "get-v2-managed-position", [Cl.uint(oldId)], owner,
    ).result)).toBe(beforeManaged);
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-tick", [Cl.uint(poolId), Cl.int(-120)], owner,
    ).result)).toBe(beforeLower);
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-tick", [Cl.uint(poolId), Cl.int(120)], owner,
    ).result)).toBe(beforeUpper);
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-tick", [Cl.uint(poolId), Cl.int(-60)], owner,
    ).result)).toBe(beforeTargetLower);
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-tick", [Cl.uint(poolId), Cl.int(180)], owner,
    ).result)).toBe(beforeTargetUpper);
    expect(simnet.getAssetsMap().get(`.${TOKEN0}.mock`)?.get(owner) ?? 0n).toBe(before0);
    expect(simnet.getAssetsMap().get(`.${TOKEN1}.reward`)?.get(owner) ?? 0n).toBe(before1);
  });

  it("proxies exact V2 PnL/IL independently of legacy oracle configuration", () => {
    const poolId = createPool();
    const positionId = fieldUint(okTuple(open(poolId)), "position-id");
    const directPnl = simnet.callReadOnlyFn(POOL, "get-position-pnl", [Cl.uint(positionId)], owner).result;
    const directIl = simnet.callReadOnlyFn(POOL, "get-exact-il", [Cl.uint(positionId)], owner).result;
    const managerPnl = simnet.callReadOnlyFn(MANAGER, "get-v2-position-pnl", [Cl.uint(positionId)], owner).result;
    const managerIl = simnet.callReadOnlyFn(MANAGER, "get-v2-exact-il", [Cl.uint(positionId)], owner).result;
    expect(managerPnl).toEqual(directPnl);
    expect(managerIl).toEqual(directIl);
    expect(Cl.prettyPrint(managerIl)).toContain('price-source: "pool-executable-state"');
    expect(Cl.prettyPrint(managerIl)).toContain("loss-only-il-token1");
    expect(Cl.prettyPrint(managerIl)).toContain("outperformance-token1");
    expect(simnet.callReadOnlyFn(MANAGER, "get-configured-oracle", [], owner).result)
      .toEqual(Cl.none());
  });
});
