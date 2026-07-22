import { beforeAll, describe, expect, it } from "vitest";
import { Cl, cvToValue } from "@stacks/transactions";
import { simnet } from "../setup-test-env";

const ORCHESTRATOR = "dual-stacking-orchestrator";
const OPERATOR = "native-stacking-operator";
const TOKEN = "mock-token";
const REWARD_TOKEN = "mock-reward-token";
const POX_ADAPTER = "mock-pox-adapter";
const POX_ADAPTER_2 = "mock-pox-adapter-2";
const INTERMEDIARY = "mock-settlement-intermediary";
const STACKING_ADAPTER = "mock-stacking-adapter";
const STACKING_ADAPTER_2 = "mock-stacking-adapter-2";

const proof = (byte: number) => Cl.buffer(Buffer.alloc(32, byte));
const contract = (deployer: string, name: string) => Cl.contractPrincipal(deployer, name);
const contractId = (deployer: string, name: string) => `${deployer}.${name}`;

function tupleValue(result: any): any {
  return result.value?.value ?? result.value;
}

function tupleUint(result: any, key: string): number {
  return Number(tupleValue(result)[key].value);
}

function tupleBool(result: any, key: string): boolean {
  return cvToValue(tupleValue(result)[key]);
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
  let poxAdapter2: any;
  let intermediary: any;
  let stackingAdapter: any;
  let stackingAdapter2: any;
  let token: any;
  let rewardToken: any;
  let operator: any;
  let commit1: number;
  let commit2: number;
  let commit3: number;
  let commit4: number;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
    wallet2 = accounts.get("wallet_2")!;
    wallet3 = accounts.get("wallet_3")!;
    wallet4 = accounts.get("wallet_4") ?? deployer;

    poxAdapter = contract(deployer, POX_ADAPTER);
    poxAdapter2 = contract(deployer, POX_ADAPTER_2);
    intermediary = contract(deployer, INTERMEDIARY);
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
    expect(tupleValue(simnet.callReadOnlyFn(OPERATOR, "get-config", [], deployer).result).orchestrator.value)
      .toBe(wallet4);
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

    // The intermediary is temporarily authoritative before any commit is
    // bound. A later failure must roll back the operator's consumed proof.
    expect(simnet.callPublicFn(OPERATOR, "set-orchestrator", [intermediary], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const intermediaryCommit = registerCommit(wallet3, 10, 1, 9);
    const intermediaryCommitData = simnet.callReadOnlyFn(
      OPERATOR,
      "get-commit",
      [Cl.uint(intermediaryCommit)],
      deployer,
    ).result;
    expect(simnet.callPublicFn(
      INTERMEDIARY,
      "attempt-bind-commit",
      [operator, Cl.uint(intermediaryCommit)],
      wallet3,
    ).result.type).toBe("ok");
    expect(simnet.callPublicFn(OPERATOR, "set-orchestrator", [contract(deployer, ORCHESTRATOR)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    mineTo(tupleUint(intermediaryCommitData, "unlock-height"));
    expect(simnet.callPublicFn(
      INTERMEDIARY,
      "finalize-commit",
      [operator, Cl.uint(intermediaryCommit), poxAdapter],
      wallet3,
    ).result.type)
      .toBe("ok");
    expect(simnet.callPublicFn(
      OPERATOR,
      "record-btc-settlement",
      [Cl.uint(intermediaryCommit), Cl.uint(7), proof(90)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      INTERMEDIARY,
      "attempt-bind-btc",
      [operator, Cl.uint(intermediaryCommit), proof(90), Cl.uint(7)],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(9300)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(OPERATOR, "get-btc-settlement", [proof(90)], deployer).result))
      .toContain("consumed: false");
    expect(simnet.callPublicFn(
      INTERMEDIARY,
      "bind-btc",
      [operator, Cl.uint(intermediaryCommit), proof(90), Cl.uint(7)],
      wallet3,
    ).result.type).toBe("ok");
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(OPERATOR, "get-btc-settlement", [proof(90)], deployer).result))
      .toContain("consumed: true");
    expect(simnet.callPublicFn(OPERATOR, "revoke-delegation", [poxAdapter], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      OPERATOR,
      "set-orchestrator",
      [contract(deployer, ORCHESTRATOR)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
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
    commit1 = registerCommit(wallet1, 40, 100, 1);

    expect(simnet.callPublicFn(OPERATOR, "bind-commit", [Cl.uint(commit1)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1021)));
    expect(simnet.callPublicFn(
      INTERMEDIARY,
      "attempt-bind-commit",
      [operator, Cl.uint(commit1)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1021)));

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
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(1)], deployer).result))
      .toContain("pox-adapter:");
    expect(simnet.callPublicFn(OPERATOR, "set-orchestrator", [Cl.principal(wallet4)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      OPERATOR,
      "set-orchestrator",
      [contract(deployer, ORCHESTRATOR)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-native-token", [rewardToken], deployer).result)
      .toEqual(Cl.error(Cl.uint(1134)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-reward-token", [token], deployer).result)
      .toEqual(Cl.error(Cl.uint(1134)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(10), token, operator, Cl.uint(commit1)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1022)));

    commit2 = registerCommit(wallet2, 20, 100, 2);
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

    commit3 = registerCommit(wallet3, 20, 100, 3);
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(5), token, operator, Cl.uint(commit3)],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(1128)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(commit3)], deployer).result))
      .toContain("bound: false");
  });

  it("rolls back operator binding, custody, IDs, and aggregate accounting on pre-write failures", () => {
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
      [stackingAdapter, Cl.uint(5), token, operator, Cl.uint(commit3)],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(2)));
    expect(simnet.callReadOnlyFn(TOKEN, "get-balance", [Cl.principal(wallet3)], deployer).result)
      .toEqual(beforeBalance);
    expect(simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(beforeNextPosition)], deployer).result)
      .toEqual(Cl.none());
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(commit3)], deployer).result))
      .toContain("bound: false");
    expect(simnet.callPublicFn(TOKEN, "set-fail-transfer", [Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(STACKING_ADAPTER, "set-failures", [Cl.bool(true), Cl.bool(false), Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(5), token, operator, Cl.uint(commit3)],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(9101)));
    expect(simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result)
      .toEqual(beforeConfig);
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(commit3)], deployer).result))
      .toContain("bound: false");
    expect(simnet.callPublicFn(STACKING_ADAPTER, "set-failures", [Cl.bool(false), Cl.bool(false), Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("rolls back adapter writes and all dual-position state when prepare-stake fails after writing", () => {
    const beforeConfig = simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result;
    const beforeNextPosition = tupleUint(beforeConfig, "next-position-id");
    const cycleId = tupleUint(beforeConfig, "reward-cycle");
    const beforeCycleWeight = simnet.callReadOnlyFn(ORCHESTRATOR, "get-cycle-weight", [Cl.uint(cycleId)], deployer).result;
    const beforeCycleCount = simnet.callReadOnlyFn(ORCHESTRATOR, "get-cycle-position-count", [Cl.uint(cycleId)], deployer).result;
    const beforeAdapter = simnet.callReadOnlyFn(ORCHESTRATOR, "get-adapter", [stackingAdapter], deployer).result;
    const beforeOperatorConfig = simnet.callReadOnlyFn(OPERATOR, "get-config", [], deployer).result;
    const beforeCommit = simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(commit3)], deployer).result;
    const beforeActiveCommit = simnet.callReadOnlyFn(OPERATOR, "get-active-commit", [Cl.principal(wallet3)], deployer).result;
    const beforeWalletBalance = simnet.callReadOnlyFn(TOKEN, "get-balance", [Cl.principal(wallet3)], deployer).result;
    const beforeCustody = simnet.callReadOnlyFn(
      TOKEN,
      "get-balance",
      [contract(deployer, ORCHESTRATOR)],
      deployer,
    ).result;

    expect(simnet.callPublicFn(STACKING_ADAPTER, "set-fail-after-prepare", [Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(5), token, operator, Cl.uint(commit3)],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(9101)));

    expect(simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(beforeNextPosition)], deployer).result)
      .toEqual(Cl.none());
    expect(simnet.callReadOnlyFn(STACKING_ADAPTER, "get-position", [Cl.uint(beforeNextPosition)], deployer).result)
      .toEqual(Cl.none());
    expect(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(commit3)], deployer).result)
      .toEqual(beforeCommit);
    expect(simnet.callReadOnlyFn(OPERATOR, "get-active-commit", [Cl.principal(wallet3)], deployer).result)
      .toEqual(beforeActiveCommit);
    expect(simnet.callReadOnlyFn(OPERATOR, "get-config", [], deployer).result)
      .toEqual(beforeOperatorConfig);
    expect(simnet.callReadOnlyFn(TOKEN, "get-balance", [Cl.principal(wallet3)], deployer).result)
      .toEqual(beforeWalletBalance);
    expect(simnet.callReadOnlyFn(
      TOKEN,
      "get-balance",
      [contract(deployer, ORCHESTRATOR)],
      deployer,
    ).result).toEqual(beforeCustody);

    const afterConfig = simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result;
    for (const key of ["next-position-id", "total-exposure", "total-stx-exposure", "total-risk-exposure"]) {
      expect(tupleUint(afterConfig, key), `${key} changed after rollback`)
        .toBe(tupleUint(beforeConfig, key));
    }
    expect(simnet.callReadOnlyFn(ORCHESTRATOR, "get-adapter", [stackingAdapter], deployer).result)
      .toEqual(beforeAdapter);
    expect(simnet.callReadOnlyFn(ORCHESTRATOR, "get-cycle-weight", [Cl.uint(cycleId)], deployer).result)
      .toEqual(beforeCycleWeight);
    expect(simnet.callReadOnlyFn(ORCHESTRATOR, "get-cycle-position-count", [Cl.uint(cycleId)], deployer).result)
      .toEqual(beforeCycleCount);

    expect(simnet.callPublicFn(STACKING_ADAPTER, "set-fail-after-prepare", [Cl.bool(false)], deployer).result)
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
    commit4 = registerCommit(wallet4, 10, 3, 4);
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
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(
      POX_ADAPTER,
      "get-external-commit",
      [Cl.uint(tupleUint(commit4Data, "external-commit-id"))],
      deployer,
    ).result))
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
    expect(simnet.callPublicFn(ORCHESTRATOR, "sweep-reward-dust", [Cl.uint(0), rewardToken], deployer).result)
      .toEqual(Cl.error(Cl.uint(1136)));

    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(5), token, operator, Cl.uint(commit3)],
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
    expect(simnet.callReadOnlyFn(
      REWARD_TOKEN,
      "get-balance",
      [contract(deployer, ORCHESTRATOR)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(1)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "set-liquid-reserve",
      [Cl.uint(1_000), Cl.uint(10), Cl.uint(0)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "sweep-reward-dust", [Cl.uint(0), rewardToken], deployer).result)
      .toEqual(Cl.error(Cl.uint(1116)));
    expect(tupleBool(simnet.callReadOnlyFn(
      ORCHESTRATOR,
      "get-reward-pool",
      [Cl.uint(0), rewardToken],
      deployer,
    ).result, "swept")).toBe(false);
    expect(simnet.callPublicFn(
      REWARD_TOKEN,
      "mint",
      [Cl.uint(10), contract(deployer, ORCHESTRATOR)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "sweep-reward-dust", [Cl.uint(0), rewardToken], deployer).result)
      .toEqual(Cl.ok(Cl.uint(1)));
    expect(simnet.callReadOnlyFn(
      REWARD_TOKEN,
      "get-balance",
      [contract(deployer, ORCHESTRATOR)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(10)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "sweep-reward-dust", [Cl.uint(0), rewardToken], deployer).result)
      .toEqual(Cl.error(Cl.uint(1137)));
    expect(tupleBool(simnet.callReadOnlyFn(
      ORCHESTRATOR,
      "get-reward-pool",
      [Cl.uint(0), rewardToken],
      deployer,
    ).result, "swept")).toBe(true);
    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-reward-pool", [Cl.uint(0), rewardToken], deployer).result, "claimed"))
      .toBe(99);

    simnet.mintSTX(deployer, 1_000n);
    expect(simnet.callPublicFn(ORCHESTRATOR, "fund-stx-reward", [Cl.uint(0), Cl.uint(100)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(100)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "sweep-stx-reward-dust", [Cl.uint(0)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1136)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-stx-reward", [Cl.uint(1), Cl.uint(0)], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(33)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-stx-reward", [Cl.uint(2), Cl.uint(0)], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(66)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-stx-reward", [Cl.uint(2), Cl.uint(0)], wallet2).result)
      .toEqual(Cl.error(Cl.uint(1115)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "set-liquid-reserve",
      [Cl.uint(1_000), Cl.uint(10), Cl.uint(10)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "sweep-stx-reward-dust", [Cl.uint(0)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1116)));
    expect(tupleBool(simnet.callReadOnlyFn(ORCHESTRATOR, "get-stx-reward-pool", [Cl.uint(0)], deployer).result, "swept"))
      .toBe(false);
    simnet.transferSTX(10, contractId(deployer, ORCHESTRATOR), deployer);
    expect(simnet.callPublicFn(ORCHESTRATOR, "sweep-stx-reward-dust", [Cl.uint(0)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(1)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "sweep-stx-reward-dust", [Cl.uint(0)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1137)));
    expect(tupleBool(simnet.callReadOnlyFn(ORCHESTRATOR, "get-stx-reward-pool", [Cl.uint(0)], deployer).result, "swept"))
      .toBe(true);
    expect(tupleUint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-stx-reward-pool", [Cl.uint(0)], deployer).result, "claimed"))
      .toBe(99);
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
    const beforeNativePosition = simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(1)], deployer).result;
    const beforeNativeConfig = simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result;
    const beforeNativeCustody = simnet.callReadOnlyFn(
      TOKEN,
      "get-balance",
      [contract(deployer, ORCHESTRATOR)],
      deployer,
    ).result;
    expect(simnet.callPublicFn(TOKEN, "set-fail-transfer", [Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "finalize-native-unstake", [Cl.uint(1), stackingAdapter, token], wallet1).result)
      .toEqual(Cl.error(Cl.uint(2)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(STACKING_ADAPTER, "get-position", [Cl.uint(1)], deployer).result))
      .toContain("status: u2");
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(1)], deployer).result))
      .toContain("status: u1");
    expect(simnet.callReadOnlyFn(ORCHESTRATOR, "get-config", [], deployer).result)
      .toEqual(beforeNativeConfig);
    expect(simnet.callReadOnlyFn(
      TOKEN,
      "get-balance",
      [contract(deployer, ORCHESTRATOR)],
      deployer,
    ).result).toEqual(beforeNativeCustody);
    expect(simnet.callPublicFn(TOKEN, "set-fail-transfer", [Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(1)], deployer).result)
      .toEqual(beforeNativePosition);
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
      [Cl.uint(commit1), Cl.uint(12), proof(7)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      OPERATOR,
      "record-btc-settlement",
      [Cl.uint(commit2), Cl.uint(8), proof(8)],
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
      [stackingAdapter, Cl.uint(5), token, operator, Cl.uint(commit3)],
      wallet3,
    ).result).toEqual(Cl.ok(Cl.uint(3)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(3)], deployer).result))
      .toContain("stx-amount: u20");
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-reward-cycle", [Cl.uint(1)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1133)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "set-reward-cycle", [Cl.uint(2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("keeps old PoX adapter bindings finalizable and settles zero-floor rewards", () => {
    const position3 = simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(3)], deployer).result;
    expect(Cl.prettyPrint(position3)).toContain("pox-adapter:");
    expect(simnet.callPublicFn(OPERATOR, "set-pox-adapter", [poxAdapter2], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "finalize-pox-exit",
      [Cl.uint(3), operator, poxAdapter2],
      wallet3,
    ).result).toEqual(Cl.error(Cl.uint(1107)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(commit3)], deployer).result))
      .toContain("state: u0");
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "finalize-pox-exit",
      [Cl.uint(3), operator, poxAdapter],
      wallet3,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "set-pox-adapter", [poxAdapter], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "revoke-delegation", [poxAdapter], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(OPERATOR, "revoke-delegation", [poxAdapter], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "revoke-delegation", [poxAdapter], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const base = currentBurnHeight();
    expect(simnet.callPublicFn(
      POX_ADAPTER,
      "set-cycle",
      [Cl.uint(3), Cl.uint(0), Cl.uint(10), Cl.uint(base)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const cycle2Commit1 = registerCommit(wallet1, 10, 2, 31);
    const cycle2Commit2 = registerCommit(wallet2, 20, 2, 32);
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(1), token, operator, Cl.uint(cycle2Commit1)],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.uint(4)));
    expect(simnet.callPublicFn(
      ORCHESTRATOR,
      "open-position",
      [stackingAdapter, Cl.uint(2), token, operator, Cl.uint(cycle2Commit2)],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.uint(5)));

    expect(simnet.callPublicFn(ORCHESTRATOR, "fund-reward", [Cl.uint(2), Cl.uint(1), rewardToken], deployer).result)
      .toEqual(Cl.ok(Cl.uint(1)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "sweep-reward-dust", [Cl.uint(2), rewardToken], deployer).result)
      .toEqual(Cl.error(Cl.uint(1136)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-reward", [Cl.uint(4), Cl.uint(2), rewardToken], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(0)));
    expect(simnet.callReadOnlyFn(
      ORCHESTRATOR,
      "get-reward-claim",
      [Cl.uint(4), Cl.uint(2), rewardToken],
      deployer,
    ).result).toEqual(Cl.none());
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-reward", [Cl.uint(5), Cl.uint(2), rewardToken], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(0)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "sweep-reward-dust", [Cl.uint(2), rewardToken], deployer).result)
      .toEqual(Cl.ok(Cl.uint(1)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "sweep-reward-dust", [Cl.uint(2), rewardToken], deployer).result)
      .toEqual(Cl.error(Cl.uint(1137)));

    expect(simnet.callPublicFn(ORCHESTRATOR, "fund-stx-reward", [Cl.uint(2), Cl.uint(100)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(100)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-stx-reward", [Cl.uint(4), Cl.uint(2)], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(33)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "claim-stx-reward", [Cl.uint(5), Cl.uint(2)], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(66)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "sweep-stx-reward-dust", [Cl.uint(2)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(1)));
    expect(simnet.callPublicFn(ORCHESTRATOR, "sweep-stx-reward-dust", [Cl.uint(2)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1137)));
  });

  it("rejects zero, regressing, and preserves same-cycle PoX commits", () => {
    const position4 = simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(4)], deployer).result;
    const position5 = simnet.callReadOnlyFn(ORCHESTRATOR, "get-position", [Cl.uint(5)], deployer).result;
    const position4Commit = tupleUint(position4, "pox-commit-id");
    const position5Commit = tupleUint(position5, "pox-commit-id");
    mineTo(tupleUint(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(position4Commit)], deployer).result, "unlock-height"));
    expect(simnet.callPublicFn(OPERATOR, "finalize-commit", [Cl.uint(position4Commit), poxAdapter], deployer).result.type)
      .toBe("ok");
    mineTo(tupleUint(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(position5Commit)], deployer).result, "unlock-height"));
    expect(simnet.callPublicFn(OPERATOR, "finalize-commit", [Cl.uint(position5Commit), poxAdapter], deployer).result.type)
      .toBe("ok");
    expect(simnet.callPublicFn(OPERATOR, "revoke-delegation", [poxAdapter], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "revoke-delegation", [poxAdapter], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(OPERATOR, "register-delegation", [Cl.uint(40), poxAdapter], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(POX_ADAPTER, "set-cycle", [Cl.uint(0), Cl.uint(0), Cl.uint(10), Cl.uint(currentBurnHeight())], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const beforeZeroConfig = simnet.callReadOnlyFn(OPERATOR, "get-config", [], deployer).result;
    const beforeZeroExternal = simnet.callReadOnlyFn(POX_ADAPTER, "get-next-external-commit-id", [], deployer).result;
    const beforeZeroNext = tupleUint(beforeZeroConfig, "next-commit-id");
    expect(simnet.callPublicFn(
      OPERATOR,
      "commit-delegation",
      [Cl.principal(wallet1), Cl.uint(20), Cl.uint(1), proof(41), poxAdapter],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1012)));
    expect(simnet.callReadOnlyFn(OPERATOR, "get-config", [], deployer).result)
      .toEqual(beforeZeroConfig);
    expect(simnet.callReadOnlyFn(POX_ADAPTER, "get-next-external-commit-id", [], deployer).result)
      .toEqual(beforeZeroExternal);
    expect(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(beforeZeroNext)], deployer).result)
      .toEqual(Cl.none());
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(OPERATOR, "get-delegation", [Cl.principal(wallet1)], deployer).result))
      .toContain("active: true");
    expect(simnet.callPublicFn(OPERATOR, "revoke-delegation", [poxAdapter], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(POX_ADAPTER, "set-cycle", [Cl.uint(4), Cl.uint(0), Cl.uint(10), Cl.uint(currentBurnHeight())], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(OPERATOR, "register-delegation", [Cl.uint(40), poxAdapter], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const highResult = simnet.callPublicFn(
      OPERATOR,
      "commit-delegation",
      [Cl.principal(wallet1), Cl.uint(20), Cl.uint(1), proof(42), poxAdapter],
      deployer,
    ).result;
    expect(highResult.type).toBe("ok");

    expect(simnet.callPublicFn(OPERATOR, "register-delegation", [Cl.uint(40), poxAdapter], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const sameResult = simnet.callPublicFn(
      OPERATOR,
      "commit-delegation",
      [Cl.principal(wallet2), Cl.uint(20), Cl.uint(1), proof(43), poxAdapter],
      deployer,
    ).result;
    expect(sameResult.type).toBe("ok");
    expect(tupleUint(simnet.callReadOnlyFn(OPERATOR, "get-config", [], deployer).result, "last-cycle-id"))
      .toBe(4);

    expect(simnet.callPublicFn(OPERATOR, "register-delegation", [Cl.uint(40), poxAdapter], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(POX_ADAPTER, "set-cycle", [Cl.uint(3), Cl.uint(0), Cl.uint(10), Cl.uint(currentBurnHeight())], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const beforeLowerConfig = simnet.callReadOnlyFn(OPERATOR, "get-config", [], deployer).result;
    const beforeLowerExternal = simnet.callReadOnlyFn(POX_ADAPTER, "get-next-external-commit-id", [], deployer).result;
    const beforeLowerNext = tupleUint(beforeLowerConfig, "next-commit-id");
    expect(simnet.callPublicFn(
      OPERATOR,
      "commit-delegation",
      [Cl.principal(wallet3), Cl.uint(20), Cl.uint(1), proof(44), poxAdapter],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1012)));
    expect(simnet.callReadOnlyFn(OPERATOR, "get-config", [], deployer).result)
      .toEqual(beforeLowerConfig);
    expect(simnet.callReadOnlyFn(POX_ADAPTER, "get-next-external-commit-id", [], deployer).result)
      .toEqual(beforeLowerExternal);
    expect(simnet.callReadOnlyFn(OPERATOR, "get-commit", [Cl.uint(beforeLowerNext)], deployer).result)
      .toEqual(Cl.none());
    expect(simnet.callPublicFn(OPERATOR, "revoke-delegation", [poxAdapter], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(POX_ADAPTER, "set-cycle", [Cl.uint(4), Cl.uint(0), Cl.uint(10), Cl.uint(currentBurnHeight())], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("keeps new staking sources free of hardcoded principals and unwrap-panic", () => {
    for (const file of [
      "contracts/traits/stacking-traits.clar",
      "contracts/staking/native-stacking-operator.clar",
      "contracts/staking/dual-stacking-orchestrator.clar",
      "contracts/test-helpers/mock-pox-adapter.clar",
      "contracts/test-helpers/mock-pox-adapter-2.clar",
      "contracts/test-helpers/mock-settlement-intermediary.clar",
      "contracts/test-helpers/mock-stacking-adapter.clar",
      "contracts/test-helpers/mock-stacking-adapter-2.clar",
      "contracts/test-helpers/mock-token.clar",
      "contracts/test-helpers/mock-reward-token.clar",
    ]) {
      const source = require("node:fs").readFileSync(file, "utf8");
      expect(source).not.toMatch(/\bS[TP][0-9A-Z]{38,}/);
      expect(source).not.toContain("unwrap-panic");
      expect(source).not.toContain("STAKING_CYCLE");
    }
  });
});
