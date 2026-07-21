import { beforeAll, describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";
import { simnet } from "../setup-test-env";

const CONTRACT = "upgrade-controller";
const hash = (byte: number) => Cl.buffer(Buffer.alloc(32, byte));

describe("Upgrade authorization registry", () => {
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
  });

  it("requires governance authority and validates release metadata", () => {
    const now = simnet.mineEmptyBlocks(0);
    const target = Cl.principal(wallet3);

    expect(simnet.callPublicFn(
      CONTRACT,
      "create-proposal",
      [target, hash(1), hash(2), Cl.uint(1000), Cl.uint(now + 10), Cl.uint(5)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1100)));

    expect(simnet.callPublicFn(
      CONTRACT,
      "create-proposal",
      [target, hash(1), hash(1), Cl.uint(1000), Cl.uint(now + 10), Cl.uint(5)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1101)));
    expect(simnet.callPublicFn(
      CONTRACT,
      "create-proposal",
      [target, hash(1), hash(2), Cl.uint(10001), Cl.uint(now + 10), Cl.uint(5)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1102)));
    expect(simnet.callPublicFn(
      CONTRACT,
      "create-proposal",
      [target, hash(1), hash(2), Cl.uint(1000), Cl.uint(0), Cl.uint(5)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1103)));
    expect(simnet.callPublicFn(
      CONTRACT,
      "create-proposal",
      [target, hash(1), hash(2), Cl.uint(1000), Cl.uint(now + 10), Cl.uint(0)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1104)));
    expect(simnet.callPublicFn(
      CONTRACT,
      "create-proposal",
      [target, hash(1), hash(2), Cl.uint(1000), Cl.uint(now + 10), Cl.uint(1_000_001)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1104)));
  });

  it("protects signer thresholds and counts duplicate approvals once", () => {
    expect(simnet.callPublicFn(CONTRACT, "set-signer", [Cl.principal(wallet1), Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "set-signer-threshold", [Cl.uint(2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "set-signer-threshold", [Cl.uint(3)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1118)));
    expect(simnet.callPublicFn(CONTRACT, "set-signer", [Cl.principal(deployer), Cl.bool(false)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1118)));

    const now = simnet.mineEmptyBlocks(0);
    const target = Cl.principal(wallet3);
    const proposal = simnet.callPublicFn(
      CONTRACT,
      "create-proposal",
      [target, hash(1), hash(2), Cl.uint(2500), Cl.uint(now + 10), Cl.uint(8)],
      deployer,
    );
    expect(proposal.result).toEqual(Cl.ok(Cl.uint(1)));

    expect(simnet.callPublicFn(CONTRACT, "approve-activation", [Cl.uint(1)], wallet2).result)
      .toEqual(Cl.error(Cl.uint(1110)));
    expect(simnet.callPublicFn(CONTRACT, "approve-activation", [Cl.uint(1)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "approve-activation", [Cl.uint(1)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1111)));
    expect(simnet.callPublicFn(CONTRACT, "approve-activation", [Cl.uint(1)], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("enforces ETA, records rollout authorization, and rolls back the exact release", () => {
    expect(simnet.callPublicFn(CONTRACT, "activate", [Cl.uint(1)], wallet3).result)
      .toEqual(Cl.error(Cl.uint(1113)));

    simnet.mineEmptyBlocks(12);
    expect(simnet.callPublicFn(CONTRACT, "activate", [Cl.uint(1)], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    const target = Cl.principal(wallet3);
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(CONTRACT, "get-active-release", [target], deployer).result))
      .toContain("rollout-bps: u2500");

    expect(simnet.callPublicFn(CONTRACT, "update-rollout", [Cl.uint(1), Cl.uint(3000)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1100)));
    expect(simnet.callPublicFn(CONTRACT, "update-rollout", [Cl.uint(1), Cl.uint(2000)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1102)));
    expect(simnet.callPublicFn(CONTRACT, "update-rollout", [Cl.uint(1), Cl.uint(6000)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(6000)));

    expect(simnet.callPublicFn(CONTRACT, "approve-rollback", [Cl.uint(1)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "approve-rollback", [Cl.uint(1)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1111)));
    expect(simnet.callPublicFn(CONTRACT, "approve-rollback", [Cl.uint(1)], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "rollback", [Cl.uint(1)], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    const active = Cl.prettyPrint(simnet.callReadOnlyFn(CONTRACT, "get-active-release", [target], deployer).result);
    expect(active).toContain("implementation-hash: 0x0101010101010101010101010101010101010101010101010101010101010101");
    expect(active).toContain("rollout-bps: u0");
    expect(active).toContain("rolled-back: true");
    expect(simnet.callPublicFn(CONTRACT, "rollback", [Cl.uint(1)], wallet2).result)
      .toEqual(Cl.error(Cl.uint(1109)));
  });

  it("invalidates activation and rollback approvals after signer-set changes", () => {
    const now = simnet.mineEmptyBlocks(0);
    const target = Cl.principal(wallet2);
    expect(simnet.callPublicFn(
      CONTRACT,
      "create-proposal",
      [target, hash(5), hash(6), Cl.uint(1500), Cl.uint(now + 5), Cl.uint(20)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(2)));

    // Approvals from generation 2 are sufficient under the current threshold.
    expect(simnet.callPublicFn(CONTRACT, "approve-activation", [Cl.uint(2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "approve-activation", [Cl.uint(2)], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    // A threshold change invalidates both existing activation approvals.
    expect(simnet.callPublicFn(CONTRACT, "set-signer-threshold", [Cl.uint(1)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    simnet.mineEmptyBlocks(8);
    expect(simnet.callPublicFn(CONTRACT, "activate", [Cl.uint(2)], wallet3).result)
      .toEqual(Cl.error(Cl.uint(1112)));

    // Re-approving in generation 3 is not enough if the approving signer is
    // then removed; that signer-set change creates generation 4.
    expect(simnet.callPublicFn(CONTRACT, "approve-activation", [Cl.uint(2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "approve-activation", [Cl.uint(2)], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "set-signer", [Cl.principal(wallet1), Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "activate", [Cl.uint(2)], wallet3).result)
      .toEqual(Cl.error(Cl.uint(1112)));

    expect(simnet.callPublicFn(CONTRACT, "approve-activation", [Cl.uint(2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "activate", [Cl.uint(2)], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    // Rollback approvals are independently generation-keyed and are also
    // invalidated when the signer set changes.
    expect(simnet.callPublicFn(CONTRACT, "approve-rollback", [Cl.uint(2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "set-signer", [Cl.principal(wallet1), Cl.bool(true)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "rollback", [Cl.uint(2)], wallet3).result)
      .toEqual(Cl.error(Cl.uint(1112)));
    expect(simnet.callPublicFn(CONTRACT, "approve-rollback", [Cl.uint(2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "rollback", [Cl.uint(2)], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("cancels before activation and never permits an empty signer set", () => {
    const now = simnet.mineEmptyBlocks(0);
    const target = Cl.principal(wallet2);
    expect(simnet.callPublicFn(
      CONTRACT,
      "create-proposal",
      [target, hash(3), hash(4), Cl.uint(100), Cl.uint(now + 5), Cl.uint(4)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.uint(3)));
    expect(simnet.callPublicFn(CONTRACT, "cancel-proposal", [Cl.uint(3)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1100)));
    expect(simnet.callPublicFn(CONTRACT, "cancel-proposal", [Cl.uint(3)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(CONTRACT, "get-proposal-status", [Cl.uint(3)], deployer).result))
      .toContain("u2");
    expect(simnet.callPublicFn(CONTRACT, "activate", [Cl.uint(3)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1108)));

    expect(simnet.callPublicFn(CONTRACT, "set-signer-threshold", [Cl.uint(1)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "set-signer", [Cl.principal(wallet1), Cl.bool(false)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "set-signer", [Cl.principal(deployer), Cl.bool(false)], deployer).result)
      .toEqual(Cl.error(Cl.uint(1117)));
  });
});
