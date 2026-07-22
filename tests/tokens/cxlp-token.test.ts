import { beforeAll, describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";
import { simnet } from "../setup-test-env";

const CXLP = "cxlp-token";
const CLP = "concentrated-liquidity-pool";

function uintValue(result: any): bigint {
  return BigInt(result.value.value);
}

function readUint(contract: string, method: string, args: any[], sender: string): bigint {
  const result = simnet.callReadOnlyFn(contract, method, args, sender).result;
  expect(result.type).toBe("ok");
  return uintValue(result);
}

function readPool(poolId: bigint, sender: string): string {
  const result = simnet.callReadOnlyFn(CLP, "get-pool", [Cl.uint(poolId)], sender).result;
  return Cl.prettyPrint(result);
}

function readPoolOutstanding(poolId: bigint, sender: string): bigint {
  return readUint(CLP, "get-pool-outstanding-shares", [Cl.uint(poolId)], sender);
}

describe("CXLP mint/burn primitive and CLP reconciliation", () => {
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

    const clp = Cl.contractPrincipal(deployer, CLP);
    expect(simnet.callReadOnlyFn(CXLP, "is-minter", [clp], deployer).result)
      .toEqual(Cl.bool(true));
    expect(simnet.callReadOnlyFn(CXLP, "is-burner", [clp], deployer).result)
      .toEqual(Cl.bool(true));
  });

  function createPool(): bigint {
    const result = simnet.callPublicFn(
      CLP,
      "create-pool",
      [
        Cl.contractPrincipal(deployer, "cxd-token"),
        Cl.contractPrincipal(deployer, "cxvg-token"),
        Cl.uint(3000),
        Cl.uint(1_000_000_000_000),
        Cl.int(0),
      ],
      deployer,
    ).result;

    expect(result.type).toBe("ok");
    return uintValue(result);
  }

  it("supports separate admin role management and revocation", () => {
    const minter = Cl.principal(wallet1);
    const burner = Cl.principal(wallet2);

    expect(simnet.callPublicFn(CXLP, "add-minter", [minter], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CXLP, "add-burner", [burner], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(CXLP, "is-minter", [minter], deployer).result)
      .toEqual(Cl.bool(true));
    expect(simnet.callReadOnlyFn(CXLP, "is-burner", [burner], deployer).result)
      .toEqual(Cl.bool(true));

    expect(simnet.callPublicFn(CXLP, "add-minter", [Cl.principal(wallet3)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callPublicFn(CXLP, "remove-burner", [burner], wallet2).result)
      .toEqual(Cl.error(Cl.uint(1000)));

    expect(simnet.callPublicFn(CXLP, "remove-minter", [minter], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(CXLP, "remove-burner", [burner], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callReadOnlyFn(CXLP, "is-minter", [minter], deployer).result)
      .toEqual(Cl.bool(false));
    expect(simnet.callReadOnlyFn(CXLP, "is-burner", [burner], deployer).result)
      .toEqual(Cl.bool(false));
  });

  it("rejects unauthorized EOA and contract mint/burn calls", () => {
    expect(simnet.callPublicFn(CXLP, "mint", [Cl.uint(1), Cl.principal(wallet1)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callPublicFn(CXLP, "burn", [Cl.uint(1), Cl.principal(wallet1)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(1000)));

    const cxlp = Cl.contractPrincipal(deployer, CXLP);
    expect(simnet.callPublicFn(
      "token-system-coordinator",
      "burn-cxvg",
      [cxlp, Cl.uint(1), Cl.principal(wallet1)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1000)));
  });

  it("uses an injected settlement authority for nested CLP mint and burn", () => {
    const poolId = createPool();

    expect(simnet.callPublicFn(CLP, "set-settlement-authority", [Cl.principal(wallet2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      CLP,
      "mint-shares",
      [Cl.uint(poolId), Cl.principal(wallet1), Cl.uint(100)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1000)));

    expect(simnet.callPublicFn(
      CLP,
      "mint-shares",
      [Cl.uint(poolId), Cl.principal(wallet1), Cl.uint(100)],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callPublicFn(
      CLP,
      "burn-shares",
      [Cl.uint(poolId), Cl.principal(wallet1), Cl.uint(40)],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(readPoolOutstanding(poolId, deployer)).toBe(60n);
    expect(readUint(CLP, "get-total-outstanding-shares", [], deployer)).toBe(readUint(CXLP, "get-total-supply", [], deployer));
    expect(readUint(CXLP, "get-balance", [Cl.principal(wallet1)], deployer)).toBe(60n);

    expect(simnet.callPublicFn(CLP, "set-settlement-authority", [Cl.principal(deployer)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });

  it("rejects zero, missing-pool, and insufficient-share operations without state changes", () => {
    const poolId = createPool();
    const supplyBefore = readUint(CXLP, "get-total-supply", [], deployer);

    expect(simnet.callPublicFn(
      CLP,
      "mint-shares",
      [Cl.uint(poolId), Cl.principal(wallet3), Cl.uint(0)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1002)));
    expect(simnet.callPublicFn(
      CLP,
      "mint-shares",
      [Cl.uint(999_999), Cl.principal(wallet3), Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1003)));
    expect(simnet.callPublicFn(
      CLP,
      "burn-shares",
      [Cl.uint(poolId), Cl.principal(wallet3), Cl.uint(1)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1005)));

    expect(readUint(CXLP, "get-total-supply", [], deployer)).toBe(supplyBefore);
    expect(readPoolOutstanding(poolId, deployer)).toBe(0n);
    expect(readPool(poolId, deployer)).toContain("outstanding-shares: u0");
  });

  it("reconciles pool, owner, canonical balance, and global supply exactly", () => {
    const poolId = createPool();
    const beforeSupply = readUint(CXLP, "get-total-supply", [], deployer);

    expect(simnet.callPublicFn(
      CLP,
      "mint-shares",
      [Cl.uint(poolId), Cl.principal(wallet3), Cl.uint(250)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(readPoolOutstanding(poolId, deployer)).toBe(250n);
    expect(readUint(CLP, "get-total-outstanding-shares", [], deployer)).toBe(beforeSupply + 250n);
    expect(readUint(CXLP, "get-balance", [Cl.principal(wallet3)], deployer)).toBe(250n);
    expect(readUint(CXLP, "get-total-supply", [], deployer)).toBe(beforeSupply + 250n);

    expect(simnet.callPublicFn(
      CLP,
      "burn-shares",
      [Cl.uint(poolId), Cl.principal(wallet3), Cl.uint(90)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(readPoolOutstanding(poolId, deployer)).toBe(160n);
    expect(readUint(CLP, "get-total-outstanding-shares", [], deployer)).toBe(beforeSupply + 160n);
    expect(readUint(CXLP, "get-balance", [Cl.principal(wallet3)], deployer)).toBe(160n);
    expect(readUint(CXLP, "get-total-supply", [], deployer)).toBe(beforeSupply + 160n);
  });

  it("rolls back local reconciliation when downstream mint or burn authorization fails", () => {
    const poolId = createPool();
    const clp = Cl.contractPrincipal(deployer, CLP);

    const beforeMintPool = readPoolOutstanding(poolId, deployer);
    const beforeMintGlobal = readUint(CLP, "get-total-outstanding-shares", [], deployer);
    const beforeMintSupply = readUint(CXLP, "get-total-supply", [], deployer);

    expect(simnet.callPublicFn(CXLP, "remove-minter", [clp], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      CLP,
      "mint-shares",
      [Cl.uint(poolId), Cl.principal(wallet2), Cl.uint(75)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callPublicFn(CXLP, "add-minter", [clp], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(readPoolOutstanding(poolId, deployer)).toBe(beforeMintPool);
    expect(readUint(CLP, "get-total-outstanding-shares", [], deployer)).toBe(beforeMintGlobal);
    expect(readUint(CXLP, "get-total-supply", [], deployer)).toBe(beforeMintSupply);

    expect(simnet.callPublicFn(
      CLP,
      "mint-shares",
      [Cl.uint(poolId), Cl.principal(wallet2), Cl.uint(75)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const beforePool = readPool(poolId, deployer);
    const beforePoolShares = readPoolOutstanding(poolId, deployer);
    const beforeGlobal = readUint(CLP, "get-total-outstanding-shares", [], deployer);
    const beforeBalance = readUint(CXLP, "get-balance", [Cl.principal(wallet2)], deployer);
    const beforeSupply = readUint(CXLP, "get-total-supply", [], deployer);

    expect(simnet.callPublicFn(CXLP, "remove-burner", [clp], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      CLP,
      "burn-shares",
      [Cl.uint(poolId), Cl.principal(wallet2), Cl.uint(25)],
      deployer,
    ).result).toEqual(Cl.error(Cl.uint(1000)));
    expect(simnet.callPublicFn(CXLP, "add-burner", [clp], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    expect(readPool(poolId, deployer)).toBe(beforePool);
    expect(readPoolOutstanding(poolId, deployer)).toBe(beforePoolShares);
    expect(readUint(CLP, "get-total-outstanding-shares", [], deployer)).toBe(beforeGlobal);
    expect(readUint(CXLP, "get-balance", [Cl.principal(wallet2)], deployer)).toBe(beforeBalance);
    expect(readUint(CXLP, "get-total-supply", [], deployer)).toBe(beforeSupply);
  });

  it("keeps direct and proxy transfers aggregate-safe across multiple pools", () => {
    const poolOne = createPool();
    const poolTwo = createPool();

    expect(simnet.callPublicFn(
      CLP,
      "mint-shares",
      [Cl.uint(poolOne), Cl.principal(wallet1), Cl.uint(100)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      CLP,
      "mint-shares",
      [Cl.uint(poolTwo), Cl.principal(wallet2), Cl.uint(50)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const wallet1BeforeTransfer = readUint(CXLP, "get-balance", [Cl.principal(wallet1)], deployer);
    const wallet2BeforeTransfer = readUint(CXLP, "get-balance", [Cl.principal(wallet2)], deployer);
    const wallet3BeforeTransfer = readUint(CXLP, "get-balance", [Cl.principal(wallet3)], deployer);
    const supplyBeforeTransfer = readUint(CXLP, "get-total-supply", [], deployer);
    const globalBeforeTransfer = readUint(CLP, "get-total-outstanding-shares", [], deployer);
    const poolOneBeforeTransfer = readPoolOutstanding(poolOne, deployer);
    const poolTwoBeforeTransfer = readPoolOutstanding(poolTwo, deployer);

    expect(simnet.callPublicFn(
      CXLP,
      "transfer",
      [Cl.uint(40), Cl.principal(wallet1), Cl.principal(wallet2), Cl.none()],
      wallet1,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      CLP,
      "transfer",
      [Cl.uint(10), Cl.principal(wallet2), Cl.principal(wallet3), Cl.none()],
      wallet2,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(readUint(CXLP, "get-balance", [Cl.principal(wallet1)], deployer)).toBe(wallet1BeforeTransfer - 40n);
    expect(readUint(CXLP, "get-balance", [Cl.principal(wallet2)], deployer)).toBe(wallet2BeforeTransfer + 30n);
    expect(readUint(CXLP, "get-balance", [Cl.principal(wallet3)], deployer)).toBe(wallet3BeforeTransfer + 10n);
    expect(readUint(CXLP, "get-total-supply", [], deployer)).toBe(supplyBeforeTransfer);
    expect(readUint(CLP, "get-total-outstanding-shares", [], deployer)).toBe(globalBeforeTransfer);
    expect(readPoolOutstanding(poolOne, deployer)).toBe(poolOneBeforeTransfer);
    expect(readPoolOutstanding(poolTwo, deployer)).toBe(poolTwoBeforeTransfer);

    // Settlement authority selects the pool; #536 will provide the position
    // attribution and custody checks that justify that selection.
    expect(simnet.callPublicFn(
      CLP,
      "burn-shares",
      [Cl.uint(poolOne), Cl.principal(wallet3), Cl.uint(10)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(
      CLP,
      "mint-shares",
      [Cl.uint(poolTwo), Cl.principal(wallet3), Cl.uint(25)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(readPoolOutstanding(poolOne, deployer)).toBe(poolOneBeforeTransfer - 10n);
    expect(readPoolOutstanding(poolTwo, deployer)).toBe(poolTwoBeforeTransfer + 25n);
    expect(readUint(CLP, "get-total-outstanding-shares", [], deployer)).toBe(globalBeforeTransfer + 15n);
    expect(readUint(CXLP, "get-total-supply", [], deployer)).toBe(supplyBeforeTransfer + 15n);
    expect(readUint(CXLP, "get-balance", [Cl.principal(wallet3)], deployer)).toBe(wallet3BeforeTransfer + 25n);
  });

  it("exposes canonical proxy getters without fabricating token state", () => {
    const poolId = createPool();
    expect(simnet.callPublicFn(
      CLP,
      "mint-shares",
      [Cl.uint(poolId), Cl.principal(wallet1), Cl.uint(30)],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    expect(simnet.callReadOnlyFn(CLP, "get-name", [], deployer).result)
      .toEqual(simnet.callReadOnlyFn(CXLP, "get-name", [], deployer).result);
    expect(simnet.callReadOnlyFn(CLP, "get-symbol", [], deployer).result)
      .toEqual(simnet.callReadOnlyFn(CXLP, "get-symbol", [], deployer).result);
    expect(simnet.callReadOnlyFn(CLP, "get-decimals", [], deployer).result)
      .toEqual(simnet.callReadOnlyFn(CXLP, "get-decimals", [], deployer).result);
  });
});
