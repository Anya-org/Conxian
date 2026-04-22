import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { simnet } from './setup-test-env';
import { Cl } from "@stacks/transactions";

let deployer: string;
let wallet1: string;

describe("Stubs Implementation Tests", () => {
  beforeAll(async () => {

  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  describe("Bond Token", () => {
    it("should allow minting by owner", () => {
      const mintResult = simnet.callPublicFn(
        "bond-token",
        "mint",
        [Cl.uint(1000), Cl.principal(wallet1)],
        deployer
      );
      expect(mintResult.result).toEqual(Cl.ok(Cl.bool(true)));

      const balanceResult = simnet.callReadOnlyFn(
        "bond-token",
        "get-balance",
        [Cl.principal(wallet1)],
        deployer
      );
      expect(balanceResult.result).toEqual(Cl.ok(Cl.uint(1000)));
    });
  });

  describe("Oracle", () => {
    it("should allow setting and fetching price", () => {
      const setPriceResult = simnet.callPublicFn(
        "oracle",
        "set-price",
        [Cl.principal(deployer), Cl.uint(50000)],
        deployer
      );
      expect(setPriceResult.result).toEqual(Cl.ok(Cl.bool(true)));

      const getPriceResult = simnet.callReadOnlyFn(
        "oracle",
        "get-price",
        [Cl.principal(deployer)],
        deployer
      );
      expect(getPriceResult.result).toEqual(Cl.ok(Cl.uint(50000)));
    });
  });

  describe("Batch Auction", () => {
    it("should allow creating an auction", () => {
      // Need a token to sell. Let's use cxd-token for testing
      // First mint some cxd-token to deployer
      simnet.callPublicFn("cxd-token", "mint", [Cl.uint(1000000), Cl.principal(deployer)], deployer);

      const createResult = simnet.callPublicFn(
        "batch-auction",
        "create-auction",
        [
          Cl.principal(deployer + ".cxd-token"),
          Cl.principal(deployer + ".bond-token"),
          Cl.uint(1000),
          Cl.uint(500),
          Cl.uint(100)
        ],
        deployer
      );
      expect(createResult.result).toSatisfy((res: any) => res.type === Cl.ok(Cl.uint(1)).type);
    });
  });
});
