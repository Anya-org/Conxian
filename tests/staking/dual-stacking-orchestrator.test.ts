import { readFileSync } from "node:fs";
import { beforeAll, describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";
import { simnet } from "../setup-test-env";

const ORCHESTRATOR = "dual-stacking-orchestrator";
const OPERATOR = "native-stacking-operator";
const TOKEN = "mock-token";
const POX_ADAPTER = "mock-pox-adapter";
const STACKING_ADAPTER = "mock-stacking-adapter";

const proof = (byte: number) => Cl.buffer(Buffer.alloc(32, byte));
const principal = (deployer: string, contractName: string) =>
  Cl.contractPrincipal(deployer, contractName);

function tupleUint(result: any, key: string): number {
  const tuple = result.value?.value ?? result.value;
  return Number(tuple[key].value);
}

function resultUint(result: any): number {
  return Number(result.value.value);
}

function currentBurnHeight(): number {
  return simnet.mineEmptyBlocks(0);
}

describe("dual stacking and delegated native operator", () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;
  let poxAdapter: any;
  let stackingAdapter: any;
  let token: any;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
    wallet2 = accounts.get("wallet_2")!;
    wallet3 = accounts.get("wallet_3")!;

    poxAdapter = principal(deployer, POX_ADAPTER);
    stackingAdapter = principal(deployer, STACKING_ADAPTER);
    token = principal(deployer, TOKEN);

    expect(simnet.callPublicFn(OPERATOR, "initialize", [Cl.principal(deployer)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "set-pox-adapter", [poxAdapter], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "set-keeper", [Cl.principal(wallet2), Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "set-operator", [Cl.principal(deployer)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(ORCHESTRATOR, "initialize", [Cl.principal(deployer)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-native-token", [token], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-reward-token", [token], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-native-operator", [Cl.principal(deployer)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-native-cooldown", [Cl.uint(3)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-allocation-cap", [Cl.uint(120)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-liquid-reserve", [Cl.uint(0), Cl.uint(0)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    for (const recipient of [deployer, wallet1, wallet2, wallet3]) {
      expect(simnet.callPublicFn(TOKEN, "mint", [Cl.uint(1_000_000), Cl.principal(recipient)], deployer).result)
        .toEqual(Cl.ok(Cl.bool(true)));
    }
  });

  it("enforces one-time initialization, admin authorization, and adapter binding", () => {
    expect(simnet.callPublicFn(OPERATOR, "initialize", [Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1002)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-liquid-reserve", [Cl.uint(1), Cl.uint(1)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1100)));

    // The stacking adapter is a valid trait implementation but is not the
    // registered adapter for this call, so no position is created.
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(10), Cl.uint(10), token],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1106)));
  });

  it("opens positions, enforces risk/exposure caps, and preserves ownership", () => {
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "register-adapter",
      [stackingAdapter, Cl.uint(5000), Cl.uint(500)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(80), Cl.uint(80), token],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(1)));

    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(50), Cl.uint(50), token],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(1110)));

    expect(simnet.callPublicFn(ORCHESTRATOR, "set-allocation-cap", [Cl.uint(200)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(40), Cl.uint(40), token],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.uint(2)));

    const position = simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(1)], deployer).result;
    expect(Cl.prettyPrint(position)).toContain(wallet1);
    expect(Cl.prettyPrint(position)).toContain("native-amount: u80");
    expect(simnet.callReadOnlyFn(ORCHESTRATOR, "get-cycle-weight", [Cl.uint(0)], deployer).result)
      .toEqual(Cl.uint(240));
    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result, "total-exposure"))
      .toBe(120);
  });

  it("records delegated PoX commitments with replay-resistant IDs and exact unlock boundaries", () => {
    expect(simnet.callPublicFn(
      OPERATOR,
      "register-delegation",
      [Cl.uint(500), poxAdapter],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const base = currentBurnHeight();
    expect(simnet.callPublicFn(
      POX_ADAPTER,
      "set-cycle",
      [Cl.uint(1), Cl.uint(0), Cl.uint(10), Cl.uint(base)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const auth = proof(1);
    expect(simnet.callPublicFn(
      OPERATOR,
      "commit-delegation",
      [Cl.principal(wallet1), Cl.uint(400), Cl.uint(10), auth, poxAdapter],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.uint(1)));
    expect(simnet.callPublicFn(
      OPERATOR,
      "commit-delegation",
      [Cl.principal(wallet1), Cl.uint(400), Cl.uint(10), auth, poxAdapter],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(1011)));

    const commit = simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(1)], deployer).result;
    const unlockHeight = tupleUint(commit, "unlock-height");
    expect(currentBurnHeight()).toBeLessThan(unlockHeight);
    expect(simnet.callPublicFn(OPERATOR, "finalize-commit", [Cl.uint(1)], wallet3).result)
      .toEqual(Cl.error(Cl.uint(1013)));

    const current = currentBurnHeight();
    if (current < unlockHeight) simnet.mineEmptyBlocks(unlockHeight - current);
    expect(simnet.callPublicFn(OPERATOR, "finalize-commit", [Cl.uint(1)], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(tupleUint(simnet.callReadOnlyFn(OPERATOR, "get-cycle-ledger", [Cl.uint(1)], deployer).result, "matured"))
      .toBe(400);
  });

  it("supports premature revocation and matured native unlocks without local PoX cycle constants", () => {
    expect(simnet.callPublicFn(
      OPERATOR,
      "register-delegation",
      [Cl.uint(250), poxAdapter],
      wallet3,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const base = currentBurnHeight();
    expect(simnet.callPublicFn(
      POX_ADAPTER,
      "set-cycle",
      [Cl.uint(2), Cl.uint(0), Cl.uint(10), Cl.uint(base)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      OPERATOR,
      "commit-delegation",
      [Cl.principal(wallet3), Cl.uint(100), Cl.uint(20), proof(2), poxAdapter],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.uint(2)));
    expect(simnet.callPublicFn(OPERATOR, "revoke-delegation", [poxAdapter], wallet3).result)
      .toEqual(Cl.error(Cl.uint(1009)));
    expect(simnet.callPublicFn(OPERATOR, "revoke-commit", [Cl.uint(2)], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "revoke-delegation", [poxAdapter], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      OPERATOR,
      "register-delegation",
      [Cl.uint(50), poxAdapter],
      wallet3,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    // Native exit uses the configured internal cooldown, while the PoX leg
    // remains based on adapter-returned heights.
    const request = simnet.callPublicFn(
      ORCHESTRATOR,
      "request-native-unstake",
      [Cl.uint(1), stackingAdapter],
      wallet1,
    );
    expect(request.result.type).toBe("ok");
    const nativeUnlock = resultUint(request.result);
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "finalize-native-unstake",
      [Cl.uint(1), stackingAdapter, token],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1114)));
    const current = currentBurnHeight();
    if (current < nativeUnlock) simnet.mineEmptyBlocks(nativeUnlock - current);
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "finalize-native-unstake",
      [Cl.uint(1), stackingAdapter, token],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(80)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "finalize-native-unstake",
      [Cl.uint(1), stackingAdapter, token],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1113)));
  });

  it("enforces the liquid reserve and aggregates pro-rata one-time rewards", () => {
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-liquid-reserve", [Cl.uint(1000), Cl.uint(0)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "request-native-unstake", [Cl.uint(2), stackingAdapter], wallet2).result)
      .toBeDefined();
    const pos2 = simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(2)], deployer).result;
    const nativeUnlock = tupleUint(pos2, "native-unlock-height");
    const current = currentBurnHeight();
    if (current < nativeUnlock) simnet.mineEmptyBlocks(nativeUnlock - current);
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "finalize-native-unstake",
      [Cl.uint(2), stackingAdapter, token],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(1116)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-liquid-reserve", [Cl.uint(0), Cl.uint(0)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "finalize-native-unstake",
      [Cl.uint(2), stackingAdapter, token],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.uint(40)));

    expect(simnet.callPublicFn(ORCHESTRATOR, "set-reward-cycle", [Cl.uint(0)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    // Position 1 and 2 have weights 160 and 80, so 240 reward units split
    // exactly into 160 and 80.
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "fund-reward",
      [Cl.uint(0), Cl.uint(240), token],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(240)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "claim-reward",
      [Cl.uint(1), Cl.uint(0), token],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(160)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "claim-reward",
      [Cl.uint(1), Cl.uint(0), token],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1115)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "fund-reward",
      [Cl.uint(0), Cl.uint(1), token],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1118)));
  });

  it("supports pro-rata STX rewards with one-time claims", () => {
    simnet.mintSTX(deployer, 1_000n);
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "fund-stx-reward",
      [Cl.uint(0), Cl.uint(90)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(90)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-stx-reward", [Cl.uint(1), Cl.uint(0)], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(60)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-stx-reward", [Cl.uint(2), Cl.uint(0)], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(30)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-stx-reward", [Cl.uint(2), Cl.uint(0)], wallet2).result)
      .toEqual(Cl.error(Cl.uint(1115)));
  });

  it("records and claims BTC settlement attestations as accounting-only entitlements", () => {
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "record-pox-commit",
      [Cl.uint(2), Cl.uint(2), Cl.uint(currentBurnHeight() + 5), Cl.uint(22)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const btcProof = proof(7);
    expect(simnet.callPublicFn(
      OPERATOR,
      "record-btc-settlement",
      [Cl.uint(2), Cl.principal(wallet2), Cl.uint(12), btcProof],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "record-btc-entitlement",
      [Cl.uint(2), Cl.uint(2), Cl.uint(12), btcProof],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "record-btc-entitlement",
      [Cl.uint(2), Cl.uint(2), Cl.uint(12), btcProof],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1118)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-btc-entitlement", [Cl.uint(2)], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(12)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-btc-entitlement", [Cl.uint(2)], wallet2).result)
      .toEqual(Cl.error(Cl.uint(1115)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-btc-entitlement", [Cl.uint(2)], deployer).result))
      .toContain("claimed: true");

    const positionAfterCommit = simnet.callReadOnlyFn(
      ORCHESTRATOR,
      "get-position",
      [Cl.uint(2)],
      deployer,
    ).result;
    const poxUnlock = tupleUint(positionAfterCommit, "pox-unlock-height");
    const current = currentBurnHeight();
    if (current < poxUnlock) simnet.mineEmptyBlocks(poxUnlock - current);
    expect(simnet.callPublicFn(ORCHESTRATOR, "finalize-pox-exit", [Cl.uint(2)], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("pauses new risk while preserving claims and matured exits", () => {
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-reward-cycle", [Cl.uint(1)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(10), Cl.uint(10), token],
      wallet3,
    ).result).toEqual(Cl.ok(Cl.uint(3)));
    expect(simnet.callPublicFn(
      OPERATOR,
      "register-delegation",
      [Cl.uint(5), poxAdapter],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-paused", [Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-reward", [Cl.uint(2), Cl.uint(0), token], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(80)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(10), Cl.uint(10), token],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(1103)));

    expect(simnet.callPublicFn(OPERATOR, "set-paused", [Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "revoke-delegation", [poxAdapter], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    const request = simnet.callPublicFn(
      ORCHESTRATOR,
      "request-native-unstake",
      [Cl.uint(3), stackingAdapter],
      wallet3,
    );
    const nativeUnlock = resultUint(request.result);
    const current = currentBurnHeight();
    if (current < nativeUnlock) simnet.mineEmptyBlocks(nativeUnlock - current);
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "finalize-native-unstake",
      [Cl.uint(3), stackingAdapter, token],
      wallet3,
    ).result).toEqual(Cl.ok(Cl.uint(10)));

    expect(simnet.callPublicFn(OPERATOR, "set-paused", [Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-paused", [Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("does not corrupt custody or position IDs when an adapter call fails", () => {
    const beforeBalance = simnet.callReadOnlyFn(TOKEN, "get-balance", [Cl.principal(wallet3)], deployer).result;
    const beforeConfig = simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result;
    const nextPositionId = tupleUint(beforeConfig, "next-position-id");

    expect(simnet.callPublicFn(STACKING_ADAPTER, "set-failures", [Cl.bool(true), Cl.bool(false), Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(10), Cl.uint(10), token],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(9101)));
    expect(simnet.callReadOnlyFn(TOKEN, "get-balance", [Cl.principal(wallet3)], deployer).result)
      .toEqual(beforeBalance);
    expect(simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(nextPositionId)], deployer).result)
      .toEqual(Cl.none());
    expect(simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result)
      .toEqual(expect.objectContaining({ type: "tuple" }));
    expect(simnet.callPublicFn(STACKING_ADAPTER, "set-failures", [Cl.bool(false), Cl.bool(false), Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("keeps new contracts free of hardcoded network principals and unwrap-panic", () => {
    for (const file of [
      "contracts/traits/stacking-traits.clar",
      "contracts/staking/native-stacking-operator.clar",
      "contracts/staking/dual-stacking-orchestrator.clar",
      "contracts/test-helpers/mock-pox-adapter.clar",
      "contracts/test-helpers/mock-stacking-adapter.clar",
    ]) {
      const source = readFileSync(file, "utf8");
      expect(source).not.toMatch(/\bS[TP][0-9A-Z]{38,}/);
      expect(source).not.toContain("unwrap-panic");
    }
  });
});
