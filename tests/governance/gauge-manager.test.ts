import { beforeAll, describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";
import { simnet } from "../setup-test-env";

const CONTRACT = "gauge-manager";
const TOKEN = "mock-token";
const MAX_UINT = (2n ** 128n) - 1n;
const hash = (byte: number) => Cl.buffer(Buffer.alloc(32, byte));

function tupleUint(result: any, key: string): number {
  return Number(result.value[key].value);
}

describe("Gauge manager", () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
    wallet2 = accounts.get("wallet_2")!;
    wallet3 = accounts.get("wallet_3")!;

    const token = Cl.contractPrincipal(deployer, TOKEN);
    expect(simnet.callPublicFn(CONTRACT, "set-voting-token", [token], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "set-epoch-length", [Cl.uint(100)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "register-gauge", [Cl.principal(wallet1), hash(1), Cl.uint(6000)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "register-gauge", [Cl.principal(wallet2), hash(2), Cl.uint(10000)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "register-gauge", [Cl.principal(wallet3), hash(3), Cl.uint(10000)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(TOKEN, "mint", [Cl.uint(1000), Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(TOKEN, "mint", [Cl.uint(1000), Cl.principal(wallet2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("validates gauge registration, admin controls, token identity, and zero totals", () => {
    const token = Cl.contractPrincipal(deployer, TOKEN);
    const communityToken = Cl.contractPrincipal(deployer, "community-governance-token");

    expect(simnet.callPublicFn(CONTRACT, "register-gauge", [Cl.principal(wallet1), hash(9), Cl.uint(1000)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1202)));
    expect(simnet.callPublicFn(CONTRACT, "register-gauge", [Cl.principal(deployer), hash(9), Cl.uint(10001)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1204)));
    expect(simnet.callPublicFn(CONTRACT, "set-gauge-enabled", [Cl.principal(wallet1), Cl.bool(false)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1200)));
    expect(simnet.callPublicFn(CONTRACT, "set-gauge-cap", [Cl.principal(wallet1), Cl.uint(10001)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1204)));
    expect(simnet.callPublicFn(CONTRACT, "set-epoch-length", [Cl.uint(1_000_001)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1206)));

    expect(simnet.callPublicFn(CONTRACT, "set-gauge-enabled", [Cl.principal(wallet3), Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "vote-gauge", [Cl.principal(wallet3), Cl.uint(1), token], wallet3).result)
      .toEqual(Cl.error(Cl.uint(1205)));
    expect(simnet.callPublicFn(CONTRACT, "set-gauge-enabled", [Cl.principal(wallet3), Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(CONTRACT, "vote-gauge", [Cl.principal(wallet1), Cl.uint(1), communityToken], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1201)));
    expect(simnet.callPublicFn(
      CONTRACT,
      "vote-gauge",
      [Cl.principal(wallet1), Cl.uint(MAX_UINT), token],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1213)));
    expect(simnet.callReadOnlyFn(CONTRACT, "get-raw-relative-weight", [Cl.uint(99), Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.uint(0));
  });

  it("escrows multi-gauge votes, applies caps, and prevents duplicates", () => {
    const token = Cl.contractPrincipal(deployer, TOKEN);

    expect(simnet.callPublicFn(CONTRACT, "vote-gauge", [Cl.principal(wallet1), Cl.uint(500), token], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "vote-gauge", [Cl.principal(wallet2), Cl.uint(200), token], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "vote-gauge", [Cl.principal(wallet1), Cl.uint(1), token], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1210)));
    expect(simnet.callPublicFn(CONTRACT, "vote-gauge", [Cl.principal(wallet1), Cl.uint(300), token], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callReadOnlyFn(CONTRACT, "get-epoch-total", [Cl.uint(0)], deployer).result)
      .toEqual(Cl.uint(1000));
    expect(simnet.callReadOnlyFn(CONTRACT, "get-user-epoch-total", [Cl.uint(0), Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.uint(700));
    expect(simnet.callReadOnlyFn(CONTRACT, "get-raw-relative-weight", [Cl.uint(0), Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.uint(8000));
    expect(simnet.callReadOnlyFn(CONTRACT, "get-capped-relative-weight", [Cl.uint(0), Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.uint(6000));
    expect(simnet.callReadOnlyFn(CONTRACT, "get-capped-relative-weight", [Cl.uint(0), Cl.principal(wallet2)], deployer).result)
      .toEqual(Cl.uint(2000));
  });

  it("finalizes only at the burn-block boundary, preserves history, and returns escrow", () => {
    const token = Cl.contractPrincipal(deployer, TOKEN);
    const alternateToken = Cl.contractPrincipal(deployer, "community-governance-token");
    const config = simnet.callReadOnlyFn(CONTRACT, "get-config", [], deployer).result;
    const boundary = tupleUint(config, "epoch-end");

    expect(simnet.callPublicFn(CONTRACT, "advance-epoch", [], wallet3).result)
      .toEqual(Cl.error(Cl.uint(1208)));

    const current = simnet.mineEmptyBlocks(0);
    if (current < boundary) {
      simnet.mineEmptyBlocks(boundary - current);
    }

    // Disabling an active gauge zeros its canonical current weight. Re-enabling
    // before finalization restores eligibility, while the final disabled state
    // is what the historical epoch must retain.
    expect(simnet.callPublicFn(CONTRACT, "set-gauge-enabled", [Cl.principal(wallet1), Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(CONTRACT, "get-capped-relative-weight", [Cl.uint(0), Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.uint(0));
    expect(simnet.callPublicFn(CONTRACT, "set-gauge-enabled", [Cl.principal(wallet1), Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(CONTRACT, "get-capped-relative-weight", [Cl.uint(0), Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.uint(6000));
    expect(simnet.callPublicFn(CONTRACT, "set-gauge-enabled", [Cl.principal(wallet1), Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    // Once votes exist, a length update is scheduled for the next epoch and
    // cannot rewrite the current frozen boundary.
    expect(simnet.callPublicFn(CONTRACT, "set-epoch-length", [Cl.uint(20)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const scheduled = simnet.callReadOnlyFn(CONTRACT, "get-config", [], deployer).result;
    expect(tupleUint(scheduled, "epoch-end")).toBe(boundary);
    expect(tupleUint(scheduled, "next-epoch-length")).toBe(20);

    // The vote transaction lands at the exact boundary and is rejected.
    expect(simnet.callPublicFn(CONTRACT, "vote-gauge", [Cl.principal(wallet3), Cl.uint(1), token], wallet3).result)
      .toEqual(Cl.error(Cl.uint(1207)));
    expect(simnet.callPublicFn(CONTRACT, "advance-epoch", [], wallet3).result)
      .toEqual(Cl.ok(Cl.uint(0)));
    expect(simnet.callReadOnlyFn(CONTRACT, "is-epoch-finalized", [Cl.uint(0)], deployer).result)
      .toEqual(Cl.bool(true));

    // The new epoch uses the configured next length and binds its first vote
    // to the token accepted at that epoch's start.
    expect(simnet.callPublicFn(CONTRACT, "set-gauge-enabled", [Cl.principal(wallet1), Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "set-gauge-cap", [Cl.principal(wallet1), Cl.uint(10000)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "vote-gauge", [Cl.principal(wallet1), Cl.uint(100), token], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "set-voting-token", [alternateToken], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "vote-gauge", [Cl.principal(wallet1), Cl.uint(100), alternateToken], wallet2).result)
      .toEqual(Cl.error(Cl.uint(1201)));
    expect(simnet.callPublicFn(CONTRACT, "vote-gauge", [Cl.principal(wallet1), Cl.uint(100), token], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(CONTRACT, "get-epoch-total", [Cl.uint(1)], deployer).result)
      .toEqual(Cl.uint(200));
    expect(simnet.callReadOnlyFn(CONTRACT, "get-raw-relative-weight", [Cl.uint(1), Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.uint(10000));

    // Post-finalization configuration changes affect only the active epoch.
    expect(simnet.callPublicFn(CONTRACT, "set-gauge-enabled", [Cl.principal(wallet2), Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "set-gauge-cap", [Cl.principal(wallet2), Cl.uint(1)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "set-gauge-enabled", [Cl.principal(wallet1), Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "set-gauge-cap", [Cl.principal(wallet1), Cl.uint(10000)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(CONTRACT, "get-raw-relative-weight", [Cl.uint(0), Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.uint(8000));
    expect(simnet.callReadOnlyFn(CONTRACT, "get-capped-relative-weight", [Cl.uint(0), Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.uint(0));
    expect(simnet.callReadOnlyFn(CONTRACT, "get-capped-relative-weight", [Cl.uint(0), Cl.principal(wallet2)], deployer).result)
      .toEqual(Cl.uint(2000));

    const nextConfig = simnet.callReadOnlyFn(CONTRACT, "get-config", [], deployer).result;
    expect(tupleUint(nextConfig, "epoch-length")).toBe(20);
    expect(tupleUint(nextConfig, "epoch-start")).toBe(boundary);
    expect(tupleUint(nextConfig, "epoch-end")).toBe(boundary + 20);

    expect(simnet.callPublicFn(CONTRACT, "withdraw-vote", [Cl.uint(0), Cl.principal(wallet1), token], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(500)));
    expect(simnet.callPublicFn(CONTRACT, "withdraw-vote", [Cl.uint(0), Cl.principal(wallet2), token], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(200)));
    expect(simnet.callPublicFn(CONTRACT, "withdraw-vote", [Cl.uint(0), Cl.principal(wallet1), token], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(300)));
    expect(simnet.callPublicFn(CONTRACT, "withdraw-vote", [Cl.uint(0), Cl.principal(wallet1), token], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1212)));

    const epochOneConfig = simnet.callReadOnlyFn(CONTRACT, "get-config", [], deployer).result;
    const epochOneEnd = tupleUint(epochOneConfig, "epoch-end");
    const epochOneCurrent = simnet.mineEmptyBlocks(0);
    if (epochOneCurrent < epochOneEnd) {
      simnet.mineEmptyBlocks(epochOneEnd - epochOneCurrent);
    }
    expect(simnet.callPublicFn(CONTRACT, "advance-epoch", [], wallet3).result)
      .toEqual(Cl.ok(Cl.uint(1)));
    expect(simnet.callPublicFn(CONTRACT, "withdraw-vote", [Cl.uint(1), Cl.principal(wallet1), alternateToken], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1201)));
    expect(simnet.callPublicFn(CONTRACT, "withdraw-vote", [Cl.uint(1), Cl.principal(wallet1), token], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(100)));
    expect(simnet.callPublicFn(CONTRACT, "withdraw-vote", [Cl.uint(1), Cl.principal(wallet1), token], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(100)));
    expect(simnet.callPublicFn(CONTRACT, "set-voting-token", [token], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });
});
