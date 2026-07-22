import { beforeAll, describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";
import { simnet } from "../setup-test-env";

const ORCHESTRATOR = "dual-stacking-orchestrator";
const OPERATOR = "native-stacking-operator";
const TOKEN = "mock-token";
const REWARD_TOKEN = "mock-reward-token";
const POX_ADAPTER = "mock-pox-adapter";
const STACKING_ADAPTER = "mock-stacking-adapter";
const STACKING_ADAPTER_2 = "mock-stacking-adapter-2";

const proof = (byte: number) => Cl.buffer(Buffer.alloc(32, byte));
const contract = (deployer: string, name: string) => Cl.contractPrincipal(deployer, name);

function tupleValue(result: any): any {
  return result.value?.value ?? result.value;
}

function tupleUint(result: any, key: string): number {
  return Number(tupleValue(result)[key].value);
}

function currentBurnHeight(): number {
  return simnet.mineEmptyBlocks(0);
}

function mineTo(height: number): void {
  const current = currentBurnHeight();
  if (current < height) simnet.mineEmptyBlocks(height - current);
}

describe("dual stacking and delegated native operator", () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;
  let wallet4: string;
  let poxAdapter: any;
  let stackingAdapter: any;
  let stackingAdapter2: any;
  let token: any;
  let rewardToken: any;
  let operator: any;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
    wallet2 = accounts.get("wallet_2")!;
    wallet3 = accounts.get("wallet_3")!;
    wallet4 = accounts.get("wallet_4") ?? deployer;

    poxAdapter = contract(deployer, POX_ADAPTER);
    stackingAdapter = contract(deployer, STACKING_ADAPTER);
    stackingAdapter2 = contract(deployer, STACKING_ADAPTER_2);
    token = contract(deployer, TOKEN);
    rewardToken = contract(deployer, REWARD_TOKEN);
    operator = contract(deployer, OPERATOR);

    expect(simnet.callPublicFn(OPERATOR, "initialize", [Cl.principal(deployer)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "set-pox-adapter", [poxAdapter], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "set-keeper", [Cl.principal(wallet2), Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "set-operator", [Cl.principal(deployer)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      OPERATOR,
      "set-orchestrator",
      [contract(deployer, ORCHESTRATOR)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(ORCHESTRATOR, "initialize", [Cl.principal(deployer)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-native-token", [token], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-reward-token", [rewardToken], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-native-operator", [operator], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-native-cooldown", [Cl.uint(3)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-allocation-cap", [Cl.uint(100)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-stx-allocation-cap", [Cl.uint(70)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "set-liquid-reserve",
      [Cl.uint(1_000), Cl.uint(0), Cl.uint(0)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const base = currentBurnHeight();
    expect(simnet.callPublicFn(
      POX_ADAPTER,
      "set-cycle",
      [Cl.uint(1), Cl.uint(0), Cl.uint(10), Cl.uint(base)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    for (const recipient of [deployer, wallet1, wallet2, wallet3, wallet4]) {
      expect(simnet.callPublicFn(TOKEN, "mint", [Cl.uint(1_000_000), Cl.principal(recipient)], deployer).result)
        .toEqual(Cl.ok(Cl.bool(true)));
      expect(simnet.callPublicFn(REWARD_TOKEN, "mint", [Cl.uint(1_000_000), Cl.principal(recipient)], deployer).result)
        .toEqual(Cl.ok(Cl.bool(true)));
    }
  });

  it("hardens typed configuration, monotonic cycles, and distinct adapter policy", () => {
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-liquid-reserve", [Cl.uint(1), Cl.uint(1), Cl.uint(1)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1100)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-reward-cycle", [Cl.uint(0)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1133)));
    expect(simnet.callPublicFn(OPERATOR, "set-orchestrator", [Cl.principal(wallet4)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-native-operator", [operator], deployer).result)
      .toEqual(Cl.error(Cl.uint(1124)));
    expect(simnet.callPublicFn(
      OPERATOR,
      "set-orchestrator",
      [contract(deployer, ORCHESTRATOR)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      STACKING_ADAPTER,
      "set-config",
      [Cl.bool(true), Cl.uint(3000), Cl.uint(100)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "register-adapter",
      [stackingAdapter, Cl.uint(3000), Cl.uint(100)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "register-adapter",
      [stackingAdapter2, Cl.uint(7000), Cl.uint(200)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-adapter", [stackingAdapter], deployer).result, "risk-bps"))
      .toBe(3000);
    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-adapter", [stackingAdapter2], deployer).result, "max-exposure"))
      .toBe(200);
  });

  function registerCommit(user: string, amount: number, lockPeriod: number, byte: number): number {
    expect(simnet.callPublicFn(
      OPERATOR,
      "register-delegation",
      [Cl.uint(amount * 2), poxAdapter],
      user,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const result = simnet.callPublicFn(
      OPERATOR,
      "commit-delegation",
      [Cl.principal(user), Cl.uint(amount), Cl.uint(lockPeriod), proof(byte), poxAdapter],
      deployer,
    ).result;
    expect(result.type).toBe("ok");
    return Number(result.value.value);
  }

  it("binds unique authoritative commits and separates native/STX exposure", () => {
    const commit1 = registerCommit(wallet1, 40, 100, 1);

    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(10), token, operator, Cl.uint(commit1)],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(1023)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(10), token, operator, Cl.uint(999)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1010)));

    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(10), token, operator, Cl.uint(commit1)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(1)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(10), token, operator, Cl.uint(commit1)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1022)));

    const commit2 = registerCommit(wallet2, 20, 100, 2);
    expect(simnet.callPublicFn(
      STACKING_ADAPTER_2,
      "set-config",
      [Cl.bool(true), Cl.uint(8000), Cl.uint(200)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter2, Cl.uint(20), token, operator, Cl.uint(commit2)],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(1127)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(commit2)], deployer).result))
      .toContain("bound: false");

    expect(simnet.callPublicFn(
      STACKING_ADAPTER_2,
      "set-config",
      [Cl.bool(false), Cl.uint(7000), Cl.uint(200)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter2, Cl.uint(20), token, operator, Cl.uint(commit2)],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(1108)));

    expect(simnet.callPublicFn(
      STACKING_ADAPTER_2,
      "set-config",
      [Cl.bool(true), Cl.uint(7000), Cl.uint(200)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-adapter-active", [stackingAdapter2, Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter2, Cl.uint(20), token, operator, Cl.uint(commit2)],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(1108)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-adapter-active", [stackingAdapter2, Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter2, Cl.uint(20), token, operator, Cl.uint(commit2)],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.uint(2)));

    const position1 = simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(1)], deployer).result;
    expect(Cl.prettyPrint(position1)).toContain("stx-amount: u40");
    expect(Cl.prettyPrint(position1)).toContain("weight: u10");
    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result, "total-exposure"))
      .toBe(30);
    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result, "total-stx-exposure"))
      .toBe(60);

    const commit3 = registerCommit(wallet3, 20, 100, 3);
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(5), token, operator, Cl.uint(commit3)],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(1128)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(commit3)], deployer).result))
      .toContain("bound: false");
  });

  it("rolls back operator binding, custody, IDs, and adapter state on failures", () => {
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-stx-allocation-cap", [Cl.uint(100)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const beforeBalance = simnet.callReadOnlyFn(TOKEN, "get-balance", [Cl.principal(wallet3)], deployer).result;
    const beforeConfig = simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result;
    const beforeNextPosition = tupleUint(beforeConfig, "next-position-id");

    expect(simnet.callPublicFn(TOKEN, "set-fail-transfer", [Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(5), token, operator, Cl.uint(3)],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(2)));
    expect(simnet.callReadOnlyFn(TOKEN, "get-balance", [Cl.principal(wallet3)], deployer).result)
      .toEqual(beforeBalance);
    expect(simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(beforeNextPosition)], deployer).result)
      .toEqual(Cl.none());
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(3)], deployer).result))
      .toContain("bound: false");
    expect(simnet.callPublicFn(TOKEN, "set-fail-transfer", [Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(STACKING_ADAPTER, "set-failures", [Cl.bool(true), Cl.bool(false), Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(5), token, operator, Cl.uint(3)],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(9101)));
    expect(simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result)
      .toEqual(beforeConfig);
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(3)], deployer).result))
      .toContain("bound: false");
    expect(simnet.callPublicFn(STACKING_ADAPTER, "set-failures", [Cl.bool(false), Cl.bool(false), Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("keeps external PoX lifecycle authoritative and rolls back failed finalization", () => {
    expect(simnet.callPublicFn(
      POX_ADAPTER,
      "set-failures",
      [Cl.bool(true), Cl.bool(false), Cl.bool(false), Cl.bool(false)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      OPERATOR,
      "register-delegation",
      [Cl.uint(20), poxAdapter],
      wallet4,
    ).result).toEqual(Cl.error(Cl.uint(9001)));
    expect(simnet.callReadOnlyFn(OPERATOR, "get-delegation", [Cl.principal(wallet4)], deployer).result)
      .toEqual(Cl.none());
    expect(simnet.callPublicFn(
      POX_ADAPTER,
      "set-failures",
      [Cl.bool(false), Cl.bool(false), Cl.bool(false), Cl.bool(false)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const base = currentBurnHeight();
    expect(simnet.callPublicFn(
      POX_ADAPTER,
      "set-cycle",
      [Cl.uint(2), Cl.uint(0), Cl.uint(10), Cl.uint(base)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const commit4 = registerCommit(wallet4, 10, 3, 4);
    expect(simnet.callPublicFn(OPERATOR, "revoke-delegation", [poxAdapter], wallet4).result)
      .toEqual(Cl.error(Cl.uint(1009)));
    expect(simnet.callPublicFn(OPERATOR, "finalize-commit", [Cl.uint(commit4), poxAdapter], wallet4).result)
      .toEqual(Cl.error(Cl.uint(1013)));

    const commit4Data = simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(commit4)], deployer).result;
    const unlock = tupleUint(commit4Data, "unlock-height");
    mineTo(unlock);
    expect(simnet.callPublicFn(
      POX_ADAPTER,
      "set-failures",
      [Cl.bool(false), Cl.bool(false), Cl.bool(false), Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "finalize-commit", [Cl.uint(commit4), poxAdapter], wallet4).result)
      .toEqual(Cl.error(Cl.uint(9001)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(commit4)], deployer).result))
      .toContain("state: u0");
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(POX_ADAPTER, "get-external-commit", [Cl.uint(1)], deployer).result))
      .toContain("state: u0");

    expect(simnet.callPublicFn(
      POX_ADAPTER,
      "set-failures",
      [Cl.bool(false), Cl.bool(false), Cl.bool(false), Cl.bool(false)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "finalize-commit", [Cl.uint(commit4), poxAdapter], wallet4).result.type)
      .toBe("ok");
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(commit4)], deployer).result))
      .toContain("state: u1");
    expect(simnet.callPublicFn(OPERATOR, "revoke-delegation", [poxAdapter], wallet4).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("freezes reward denominators and allows every eligible position to claim", () => {
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "fund-reward",
      [Cl.uint(0), Cl.uint(100), rewardToken],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(100)));
    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-cycle-snapshot", [Cl.uint(0)], deployer).result, "weight"))
      .toBe(30);

    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(5), token, operator, Cl.uint(3)],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(1129)));

    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-reward", [Cl.uint(1), Cl.uint(0), rewardToken], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(33)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-reward", [Cl.uint(2), Cl.uint(0), rewardToken], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(66)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-reward", [Cl.uint(1), Cl.uint(0), rewardToken], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1115)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "fund-reward",
      [Cl.uint(0), Cl.uint(1), rewardToken],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1118)));
    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-reward-pool", [Cl.uint(0), rewardToken], deployer).result, "claimed"))
      .toBe(99);

    simnet.mintSTX(deployer, 1_000n);
    expect(simnet.callPublicFn(ORCHESTRATOR, "fund-stx-reward", [Cl.uint(0), Cl.uint(90)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(90)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-stx-reward", [Cl.uint(1), Cl.uint(0)], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(30)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-stx-reward", [Cl.uint(2), Cl.uint(0)], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(60)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-stx-reward", [Cl.uint(2), Cl.uint(0)], wallet2).result)
      .toEqual(Cl.error(Cl.uint(1115)));
    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-stx-reward-pool", [Cl.uint(0)], deployer).result, "claimed"))
      .toBe(90);
  });

  it("requires authoritative PoX maturity before exit and decrements both exposure ledgers", () => {
    const position1 = simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(1)], deployer).result;
    const poxUnlock = tupleUint(position1, "pox-unlock-height");
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "finalize-pox-exit",
      [Cl.uint(1), operator, poxAdapter],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1013)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "record-btc-entitlement", [Cl.uint(1), Cl.uint(12), proof(7), operator], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1131)));

    const position2 = simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(2)], deployer).result;
    expect(tupleUint(position2, "pox-unlock-height")).toBe(poxUnlock);
    mineTo(poxUnlock);

    expect(simnet.callPublicFn(
      POX_ADAPTER,
      "set-failures",
      [Cl.bool(false), Cl.bool(false), Cl.bool(false), Cl.bool(true)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "finalize-pox-exit",
      [Cl.uint(2), operator, poxAdapter],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(9001)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(2)], deployer).result))
      .toContain("pox-unlocked: false");
    expect(simnet.callPublicFn(
      POX_ADAPTER,
      "set-failures",
      [Cl.bool(false), Cl.bool(false), Cl.bool(false), Cl.bool(false)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "finalize-pox-exit", [Cl.uint(1), operator, poxAdapter], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "finalize-pox-exit", [Cl.uint(2), operator, poxAdapter], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result, "total-stx-exposure"))
      .toBe(0);

    expect(simnet.callPublicFn(ORCHESTRATOR, "request-native-unstake", [Cl.uint(1), stackingAdapter], wallet1).result.type)
      .toBe("ok");
    expect(simnet.callPublicFn(ORCHESTRATOR, "request-native-unstake", [Cl.uint(2), stackingAdapter2], wallet2).result.type)
      .toBe("ok");
    const nativeUnlock = tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(1)], deployer).result, "native-unlock-height");
    mineTo(nativeUnlock);
    expect(simnet.callPublicFn(ORCHESTRATOR, "finalize-native-unstake", [Cl.uint(1), stackingAdapter, token], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1116)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-liquid-reserve", [Cl.uint(0), Cl.uint(0), Cl.uint(0)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "finalize-native-unstake", [Cl.uint(1), stackingAdapter, token], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(10)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "finalize-native-unstake", [Cl.uint(2), stackingAdapter2, token], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(20)));
    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result, "total-exposure"))
      .toBe(0);
    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-adapter", [stackingAdapter], deployer).result, "exposure"))
      .toBe(0);
    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-adapter", [stackingAdapter2], deployer).result, "exposure"))
      .toBe(0);
  });

  it("binds and consumes exact BTC settlements once, with accounting-only claims", () => {
    expect(simnet.callPublicFn(
      OPERATOR,
      "record-btc-settlement",
      [Cl.uint(1), Cl.uint(12), proof(7)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      OPERATOR,
      "record-btc-settlement",
      [Cl.uint(2), Cl.uint(8), proof(8)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(ORCHESTRATOR, "record-btc-entitlement", [Cl.uint(1), Cl.uint(99), proof(9), operator], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1025)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "record-btc-entitlement", [Cl.uint(1), Cl.uint(13), proof(7), operator], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1026)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "record-btc-entitlement", [Cl.uint(1), Cl.uint(12), proof(8), operator], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1026)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "record-btc-entitlement", [Cl.uint(1), Cl.uint(12), proof(7), operator], wallet2).result)
      .toEqual(Cl.error(Cl.uint(1112)));

    expect(simnet.callPublicFn(ORCHESTRATOR, "record-btc-entitlement", [Cl.uint(1), Cl.uint(12), proof(7), operator], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "record-btc-entitlement", [Cl.uint(1), Cl.uint(12), proof(7), operator], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1118)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-btc-entitlement", [Cl.uint(1)], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(12)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-btc-entitlement", [Cl.uint(1)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1115)));

    expect(simnet.callPublicFn(ORCHESTRATOR, "record-btc-entitlement", [Cl.uint(2), Cl.uint(8), proof(7), operator], wallet2).result)
      .toEqual(Cl.error(Cl.uint(1119)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-btc-entitlement", [Cl.uint(1)], deployer).result))
      .toContain("claimed: true");
  });

  it("advances reward cycles only forward and opens the next cycle with its own weight", () => {
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-reward-cycle", [Cl.uint(0)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1133)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-reward-cycle", [Cl.uint(1)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-stx-allocation-cap", [Cl.uint(100)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(5), token, operator, Cl.uint(3)],
      wallet3,
    ).result).toEqual(Cl.ok(Cl.uint(3)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(3)], deployer).result))
      .toContain("stx-amount: u20");
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-reward-cycle", [Cl.uint(1)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1133)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-reward-cycle", [Cl.uint(2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("keeps new staking sources free of hardcoded principals and unwrap-panic", () => {
    for (const file of [
      "contracts/traits/stacking-traits.clar",
      "contracts/staking/native-stacking-operator.clar",
      "contracts/staking/dual-stacking-orchestrator.clar",
      "contracts/test-helpers/mock-pox-adapter.clar",
      "contracts/test-helpers/mock-stacking-adapter.clar",
      "contracts/test-helpers/mock-stacking-adapter-2.clar",
      "contracts/test-helpers/mock-token.clar",
      "contracts/test-helpers/mock-reward-token.clar",
    ]) {
      const source = require("node:fs").readFileSync(file, "utf8");
      expect(source).not.toMatch(/\bS[TP][0-9A-Z]{38,}/);
      expect(source).not.toContain("unwrap-panic");
    }
  });
});
