import crypto from "crypto";
import { ec as EC } from "elliptic";
import { Cl, cvToValue } from "@stacks/transactions";
import { beforeAll, describe, expect, it } from "vitest";
import { initializeSimnet, simnet } from "../setup-test-env";

const INTERMEDIARY = "mock-clp-v2-intermediary";
const MANAGER = "liquidity-manager";
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

describe("CLP V2 intermediary tx-sender regression", () => {
  let deployer: string;
  let owner: string;
  let attacker: string;
  let recipient: string;
  let token0: any;
  let token1: any;
  const key = new EC("secp256k1").genKeyPair();

  function balance(asset: string, principal: string): bigint {
    return simnet.getAssetsMap().get(asset)?.get(principal) ?? 0n;
  }

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

  function createPool(): bigint {
    const created = simnet.callPublicFn(
      POOL, "create-pool", [token0, token1, Cl.uint(3000), Cl.int(0)], deployer,
    ).result;
    expect(created.type).toBe("ok");
    return BigInt(created.value.value);
  }

  function proxyOpen(poolId: bigint, caller = owner): any {
    return simnet.callPublicFn(
      INTERMEDIARY, "forward-open-position-v2",
      [Cl.uint(poolId), token0, token1, Cl.int(-120), Cl.int(120),
        Cl.uint(1_000_000), Cl.uint(1_000_000), Cl.uint(1)], caller,
    ).result;
  }

  beforeAll(async () => {
    await initializeSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    owner = accounts.get("wallet_1")!;
    attacker = accounts.get("wallet_2")!;
    recipient = accounts.get("wallet_3")!;
    token0 = contract(deployer, TOKEN0);
    token1 = contract(deployer, TOKEN1);

    const pubkey = Buffer.from(key.getPublic(true, "hex"), "hex");
    expect(simnet.callPublicFn(
      "regulatory-adapter", "update-authority",
      [Cl.principal(deployer), Cl.buffer(pubkey)], deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    setCompliance(owner);
    setCompliance(attacker);

    for (const user of [owner, attacker]) {
      expect(simnet.callPublicFn(
        TOKEN0, "mint", [Cl.uint(50_000_000), Cl.principal(user)], deployer,
      ).result).toEqual(Cl.ok(Cl.bool(true)));
      expect(simnet.callPublicFn(
        TOKEN1, "mint", [Cl.uint(50_000_000), Cl.principal(user)], deployer,
      ).result).toEqual(Cl.ok(Cl.bool(true)));
    }
  });

  it("opens through the intermediary from originating-user custody and records that user", () => {
    const poolId = createPool();
    const intermediary = `${deployer}.${INTERMEDIARY}`;
    const manager = `${deployer}.${MANAGER}`;
    const before0 = balance(`.${TOKEN0}.mock`, owner);
    const before1 = balance(`.${TOKEN1}.reward`, owner);
    const opened = okTuple(proxyOpen(poolId));
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
    expect(balance(`.${TOKEN0}.mock`, owner)).toBe(before0 - amount0);
    expect(balance(`.${TOKEN1}.reward`, owner)).toBe(before1 - amount1);
    expect(balance(`.${TOKEN0}.mock`, intermediary)).toBe(0n);
    expect(balance(`.${TOKEN1}.reward`, intermediary)).toBe(0n);
    expect(balance(`.${TOKEN0}.mock`, manager)).toBe(0n);
    expect(balance(`.${TOKEN1}.reward`, manager)).toBe(0n);
  });

  it("rejects intermediary-forwarded close and rebalance by a non-owner without state changes", () => {
    const poolId = createPool();
    const positionId = fieldUint(okTuple(proxyOpen(poolId)), "position-id");
    const before0 = balance(`.${TOKEN0}.mock`, owner);
    const before1 = balance(`.${TOKEN1}.reward`, owner);
    const beforeAttacker0 = balance(`.${TOKEN0}.mock`, attacker);
    const beforeAttacker1 = balance(`.${TOKEN1}.reward`, attacker);
    const beforeManaged = Cl.prettyPrint(simnet.callReadOnlyFn(
      MANAGER, "get-v2-managed-position", [Cl.uint(positionId)], owner,
    ).result);
    const beforeCanonical = Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-position", [Cl.uint(positionId)], owner,
    ).result);
    const beforePool = Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-pool", [Cl.uint(poolId)], owner,
    ).result);

    expect(simnet.callPublicFn(
      INTERMEDIARY, "forward-close-position-v2",
      [Cl.uint(positionId), token0, token1, Cl.uint(0), Cl.uint(0)], attacker,
    ).result).toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callPublicFn(
      INTERMEDIARY, "forward-rebalance-position-v2",
      [Cl.uint(positionId), token0, token1, Cl.int(-60), Cl.int(180),
        Cl.uint(1_000_000), Cl.uint(1_000_000), Cl.uint(1), Cl.uint(0), Cl.uint(0)], attacker,
    ).result).toEqual(Cl.error(Cl.uint(1000)));

    const managed = someTuple(simnet.callReadOnlyFn(
      MANAGER, "get-v2-managed-position", [Cl.uint(positionId)], owner,
    ).result);
    const canonical = someTuple(simnet.callReadOnlyFn(
      POOL, "get-position", [Cl.uint(positionId)], owner,
    ).result);
    expect(cvToValue(managed.active)).toBe(true);
    expect(cvToValue(canonical.active)).toBe(true);
    expect(cvToValue(canonical.closed)).toBe(false);
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(
      MANAGER, "get-v2-managed-position", [Cl.uint(positionId)], owner,
    ).result)).toBe(beforeManaged);
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-position", [Cl.uint(positionId)], owner,
    ).result)).toBe(beforeCanonical);
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(
      POOL, "get-pool", [Cl.uint(poolId)], owner,
    ).result)).toBe(beforePool);
    expect(balance(`.${TOKEN0}.mock`, owner)).toBe(before0);
    expect(balance(`.${TOKEN1}.reward`, owner)).toBe(before1);
    expect(balance(`.${TOKEN0}.mock`, attacker)).toBe(beforeAttacker0);
    expect(balance(`.${TOKEN1}.reward`, attacker)).toBe(beforeAttacker1);
  });

  it("swaps through the intermediary from the originating user to an explicit recipient", () => {
    const poolId = createPool();
    expect(simnet.callPublicFn(
      POOL, "add-liquidity",
      [Cl.uint(poolId), token0, token1, Cl.int(-120), Cl.int(120),
        Cl.uint(5_000_000), Cl.uint(5_000_000), Cl.uint(1)], owner,
    ).result.type).toBe("ok");

    const intermediary = `${deployer}.${INTERMEDIARY}`;
    const router = `${deployer}.${ROUTER}`;
    const beforeInput = balance(`.${TOKEN0}.mock`, attacker);
    const beforeOutput = balance(`.${TOKEN1}.reward`, recipient);
    const swapped = okTuple(simnet.callPublicFn(
      INTERMEDIARY, "forward-exact-input-single-v2",
      [Cl.uint(poolId), token0, token1, Cl.uint(10_000),
        Cl.uint(988_000_000_000n), Cl.uint(1), Cl.principal(recipient)], attacker,
    ).result);
    const amountOut = fieldUint(swapped, "amount-out");

    expect(amountOut).toBeGreaterThan(0n);
    expect(balance(`.${TOKEN0}.mock`, attacker)).toBe(beforeInput - 10_000n);
    expect(balance(`.${TOKEN1}.reward`, recipient)).toBe(beforeOutput + amountOut);
    expect(balance(`.${TOKEN0}.mock`, intermediary)).toBe(0n);
    expect(balance(`.${TOKEN1}.reward`, intermediary)).toBe(0n);
    expect(balance(`.${TOKEN0}.mock`, router)).toBe(0n);
    expect(balance(`.${TOKEN1}.reward`, router)).toBe(0n);
  });
});
