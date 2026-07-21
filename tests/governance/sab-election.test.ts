import { readFileSync } from "node:fs";
import { beforeAll, describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";
import { simnet } from "../setup-test-env";

const CONTRACT = "sab-election";
const MOCK_TOKEN = "mock-token";

const hash = (byte: number) => Cl.buffer(Buffer.alloc(32, byte));

describe("SAB election", () => {
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

    const token = Cl.contractPrincipal(deployer, MOCK_TOKEN);
    expect(simnet.callPublicFn(CONTRACT, "set-voting-token", [token], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      CONTRACT,
      "set-parameters",
      [Cl.uint(10), Cl.uint(10), Cl.uint(2000), Cl.uint(5000)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(MOCK_TOKEN, "mint", [Cl.uint(1000), Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(MOCK_TOKEN, "mint", [Cl.uint(1000), Cl.principal(wallet2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("has no stub or unwrap-panic implementation paths", () => {
    for (const file of [
      "contracts/governance/sab-election.clar",
      "contracts/governance/upgrade-controller.clar",
      "contracts/governance/gauge-manager.clar",
    ]) {
      const source = readFileSync(file, "utf8");
      expect(source).not.toContain("stub-func");
      expect(source).not.toContain("unwrap-panic");
      if (file.endsWith("sab-election.clar")) {
        expect(source).toContain("(asserts! (< cycle-id MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))");
      }
      if (file.endsWith("upgrade-controller.clar")) {
        expect(source).toContain("(asserts! (< proposal-id MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))");
        expect(source).toContain("(asserts! (< (var-get enabled-signer-count) MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))");
        expect(source).toContain("(asserts! (< prior-approvals MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))");
      }
      if (file.endsWith("gauge-manager.clar")) {
        expect(source).toContain("(asserts! (< epoch MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))");
      }
    }
  });

  it("enforces admin configuration, token identity, and non-zero supply", () => {
    const token = Cl.contractPrincipal(deployer, MOCK_TOKEN);
    const communityToken = Cl.contractPrincipal(deployer, "community-governance-token");

    expect(simnet.callPublicFn(
      CONTRACT,
      "set-parameters",
      [Cl.uint(2), Cl.uint(3), Cl.uint(5000), Cl.uint(5000)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1000)));

    expect(simnet.callPublicFn(
      CONTRACT,
      "set-parameters",
      [Cl.uint(0), Cl.uint(3), Cl.uint(5000), Cl.uint(5000)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1005)));

    expect(simnet.callPublicFn(
      CONTRACT,
      "set-parameters",
      [Cl.uint(1_000_001), Cl.uint(3), Cl.uint(5000), Cl.uint(5000)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1005)));

    expect(simnet.callPublicFn(
      CONTRACT,
      "set-parameters",
      [Cl.uint(2), Cl.uint(3), Cl.uint(10001), Cl.uint(5000)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1006)));

    expect(simnet.callPublicFn(CONTRACT, "open-cycle", [communityToken], deployer).result)
      .toEqual(Cl.error(Cl.uint(1001)));

    expect(simnet.callPublicFn(CONTRACT, "set-voting-token", [communityToken], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "open-cycle", [communityToken], deployer).result)
      .toEqual(Cl.error(Cl.uint(1007)));
    expect(simnet.callPublicFn(CONTRACT, "set-voting-token", [token], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("runs a winner cycle at exact phase boundaries and returns escrow", () => {
    const token = Cl.contractPrincipal(deployer, MOCK_TOKEN);
    const cycleId = Cl.uint(1);

    expect(simnet.callPublicFn(
      CONTRACT,
      "set-parameters",
      [Cl.uint(10), Cl.uint(10), Cl.uint(2000), Cl.uint(5000)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "open-cycle", [token], deployer).result)
      .toEqual(Cl.ok(cycleId));

    expect(simnet.callPublicFn(CONTRACT, "nominate", [cycleId, hash(1)], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "nominate", [cycleId, hash(2)], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "nominate", [cycleId, hash(1)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1010)));
    expect(simnet.callPublicFn(CONTRACT, "open-cycle", [token], deployer).result)
      .toEqual(Cl.error(Cl.uint(1002)));

    // At nomination-end/voting-start, nomination is closed and voting opens.
    simnet.mineEmptyBlocks(6);
    expect(simnet.callPublicFn(CONTRACT, "nominate", [cycleId, hash(3)], wallet3).result)
      .toEqual(Cl.error(Cl.uint(1008)));
    expect(simnet.callReadOnlyFn(CONTRACT, "is-voting-open", [cycleId], deployer).result)
      .toEqual(Cl.bool(true));

    expect(simnet.callPublicFn(
      CONTRACT,
      "vote",
      [cycleId, Cl.principal(wallet1), Cl.uint(600), token],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      CONTRACT,
      "vote",
      [cycleId, Cl.principal(wallet1), Cl.uint(400), token],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      CONTRACT,
      "vote",
      [cycleId, Cl.principal(wallet1), Cl.uint(1), token],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(1013)));

    expect(Cl.prettyPrint(simnet.callReadOnlyFn(CONTRACT, "get-cycle", [cycleId], deployer).result))
      .toContain("total-votes: u1000");

    // At voting-end, voting is closed and permissionless finalization succeeds.
    simnet.mineEmptyBlocks(6);
    expect(simnet.callReadOnlyFn(CONTRACT, "is-voting-open", [cycleId], deployer).result)
      .toEqual(Cl.bool(false));
    expect(simnet.callPublicFn(CONTRACT, "finalize-cycle", [cycleId], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(CONTRACT, "get-cycle", [cycleId], deployer).result))
      .toContain("succeeded: true");
    expect(simnet.callReadOnlyFn(CONTRACT, "get-config", [], deployer).result)
      .toEqual(expect.objectContaining({ type: "tuple" }));

    expect(simnet.callPublicFn(CONTRACT, "claim-stake", [cycleId, token], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(600)));
    expect(simnet.callPublicFn(CONTRACT, "claim-stake", [cycleId, token], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(400)));
    expect(simnet.callPublicFn(CONTRACT, "claim-stake", [cycleId, token], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1017)));
  });

  it("finalizes a tied cycle unsuccessfully while preserving claims", () => {
    const token = Cl.contractPrincipal(deployer, MOCK_TOKEN);
    const cycleId = Cl.uint(2);

    expect(simnet.callPublicFn(CONTRACT, "open-cycle", [token], deployer).result)
      .toEqual(Cl.ok(cycleId));
    expect(simnet.callPublicFn(CONTRACT, "nominate", [cycleId, hash(4)], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "nominate", [cycleId, hash(5)], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    simnet.mineEmptyBlocks(8);

    expect(simnet.callPublicFn(
      CONTRACT,
      "vote",
      [cycleId, Cl.principal(wallet1), Cl.uint(300), token],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      CONTRACT,
      "vote",
      [cycleId, Cl.principal(wallet2), Cl.uint(300), token],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    simnet.mineEmptyBlocks(8);

    expect(simnet.callPublicFn(CONTRACT, "finalize-cycle", [cycleId], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(false)));
    const cycle = Cl.prettyPrint(simnet.callReadOnlyFn(CONTRACT, "get-cycle", [cycleId], deployer).result);
    expect(cycle).toContain("tie: true");
    expect(cycle).toContain("succeeded: false");
    expect(simnet.callReadOnlyFn(CONTRACT, "get-config", [], deployer).result)
      .toBeDefined();

    expect(simnet.callPublicFn(CONTRACT, "claim-stake", [cycleId, token], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(300)));
    expect(simnet.callPublicFn(CONTRACT, "claim-stake", [cycleId, token], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(300)));
  });

  it("binds escrow and claims to the cycle token across configuration changes", () => {
    const token = Cl.contractPrincipal(deployer, MOCK_TOKEN);
    const alternateToken = Cl.contractPrincipal(deployer, "community-governance-token");
    const cycleId = Cl.uint(3);

    expect(simnet.callPublicFn(CONTRACT, "open-cycle", [token], deployer).result)
      .toEqual(Cl.ok(cycleId));
    expect(simnet.callPublicFn(CONTRACT, "nominate", [cycleId, hash(6)], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "nominate", [cycleId, hash(7)], wallet2).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    simnet.mineEmptyBlocks(12);

    expect(simnet.callPublicFn(
      CONTRACT,
      "vote",
      [cycleId, Cl.principal(wallet1), Cl.uint(600), token],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(MOCK_TOKEN, "get-balance", [Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(400)));

    // The global setting may change for future cycles, but it cannot change
    // the token that backs this cycle's escrow.
    expect(simnet.callPublicFn(CONTRACT, "set-voting-token", [alternateToken], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      CONTRACT,
      "vote",
      [cycleId, Cl.principal(wallet1), Cl.uint(400), alternateToken],
      wallet2,
    ).result).toEqual(Cl.error(Cl.uint(1001)));
    expect(simnet.callPublicFn(
      CONTRACT,
      "vote",
      [cycleId, Cl.principal(wallet1), Cl.uint(400), token],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(MOCK_TOKEN, "get-balance", [Cl.principal(wallet2)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(600)));

    simnet.mineEmptyBlocks(12);
    expect(simnet.callPublicFn(CONTRACT, "finalize-cycle", [cycleId], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "claim-stake", [cycleId, alternateToken], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1001)));
    expect(simnet.callPublicFn(CONTRACT, "claim-stake", [cycleId, token], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(600)));
    expect(simnet.callPublicFn(CONTRACT, "claim-stake", [cycleId, token], wallet2).result)
      .toEqual(Cl.ok(Cl.uint(400)));
    expect(simnet.callReadOnlyFn(MOCK_TOKEN, "get-balance", [Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(1000)));
    expect(simnet.callReadOnlyFn(MOCK_TOKEN, "get-balance", [Cl.principal(wallet2)], deployer).result)
      .toEqual(Cl.ok(Cl.uint(1000)));

    expect(simnet.callPublicFn(CONTRACT, "set-voting-token", [token], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("snapshots quorum and approval rules for an in-flight cycle", () => {
    const token = Cl.contractPrincipal(deployer, MOCK_TOKEN);
    const cycleId = Cl.uint(4);

    expect(simnet.callPublicFn(
      CONTRACT,
      "set-parameters",
      [Cl.uint(10), Cl.uint(10), Cl.uint(2000), Cl.uint(5000)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CONTRACT, "open-cycle", [token], deployer).result)
      .toEqual(Cl.ok(cycleId));
    const opened = Cl.prettyPrint(simnet.callReadOnlyFn(CONTRACT, "get-cycle", [cycleId], deployer).result);
    expect(opened).toContain("voting-token:");
    expect(opened).toContain("quorum-bps: u2000");
    expect(opened).toContain("approval-bps: u5000");

    expect(simnet.callPublicFn(CONTRACT, "nominate", [cycleId, hash(8)], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    simnet.mineEmptyBlocks(12);
    expect(simnet.callPublicFn(
      CONTRACT,
      "vote",
      [cycleId, Cl.principal(wallet1), Cl.uint(600), token],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    // These stricter values apply only to future cycles. The active cycle
    // still uses 20% quorum and 50% approval from open time.
    expect(simnet.callPublicFn(
      CONTRACT,
      "set-parameters",
      [Cl.uint(10), Cl.uint(10), Cl.uint(9000), Cl.uint(9000)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    const afterUpdate = Cl.prettyPrint(simnet.callReadOnlyFn(CONTRACT, "get-cycle", [cycleId], deployer).result);
    expect(afterUpdate).toContain("quorum-bps: u2000");
    expect(afterUpdate).toContain("approval-bps: u5000");

    simnet.mineEmptyBlocks(12);
    expect(simnet.callPublicFn(CONTRACT, "finalize-cycle", [cycleId], wallet3).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(Cl.prettyPrint(simnet.callReadOnlyFn(CONTRACT, "get-cycle", [cycleId], deployer).result))
      .toContain("succeeded: true");
    expect(simnet.callPublicFn(CONTRACT, "claim-stake", [cycleId, token], wallet1).result)
      .toEqual(Cl.ok(Cl.uint(600)));

    expect(simnet.callPublicFn(
      CONTRACT,
      "set-parameters",
      [Cl.uint(10), Cl.uint(10), Cl.uint(2000), Cl.uint(5000)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
