import { describe, it, expect, beforeEach } from "vitest";
import { simnet } from './setup-test-env';
import { Cl } from "@stacks/transactions";

describe("Core Contract Tests", () => {
    let deployer: string;

  beforeEach(async () => {

    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  describe("Core Protocol", () => {
    it("should have conxian-protocol contract deployed", () => {
      const contract = simnet.getContractSource("conxian-protocol");
      expect(contract).toBeDefined();
    });

    it("should check protocol pause status", () => {
      const result = simnet.callReadOnlyFn(
        "conxian-protocol",
        "is-paused",
        [],
        deployer
      );
      expect(result.result).toEqual(Cl.bool(false));
    });

    it("should toggle protocol pause status (Admin Only)", () => {
      // 1. Initialize owner
      simnet.callPublicFn("conxian-protocol", "set-owner", [Cl.principal(deployer)], deployer);

      // 2. Pause
      let result = simnet.callPublicFn(
        "conxian-protocol",
        "set-paused",
        [Cl.bool(true)],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.bool(true)));

      // 3. Verify
      let status = simnet.callReadOnlyFn(
        "conxian-protocol",
        "is-paused",
        [],
        deployer
      );
      expect(status.result).toEqual(Cl.bool(true));
    });
  });

  describe("DEX Connectivity", () => {
    it("should execute a native swap", () => {
      const poolId = 1;

      const incoherent = simnet.callPublicFn(
        "concentrated-liquidity-pool",
        "create-pool",
        [
          Cl.principal(`${deployer}.mock-token`),
          Cl.principal(`${deployer}.cxd-token`),
          Cl.uint(3000),
          Cl.uint(1000000),
          Cl.int(0)
        ],
        deployer
      );
      expect(incoherent.result).toEqual(Cl.error(Cl.uint(1103)));

      // Need a coherent tick-0 pool created for ID 1.
      const created = simnet.callPublicFn(
        "concentrated-liquidity-pool",
        "create-pool",
        [
          Cl.principal(`${deployer}.mock-token`),
          Cl.principal(`${deployer}.cxd-token`),
          Cl.uint(3000),
          Cl.uint(1000000000000),
          Cl.int(0)
        ],
        deployer
      );
      expect(created.result).toEqual(Cl.ok(Cl.uint(poolId)));

      expect(simnet.callPublicFn(
        "mock-token",
        "mint",
        [Cl.uint(1000000), Cl.standardPrincipal(deployer)],
        deployer
      ).result).toEqual(Cl.ok(Cl.bool(true)));
      expect(simnet.callPublicFn(
        "cxd-token",
        "mint",
        [Cl.uint(1000000), Cl.contractPrincipal(deployer, "concentrated-liquidity-pool")],
        deployer
      ).result).toEqual(Cl.ok(Cl.bool(true)));

      const result = simnet.callPublicFn(
        "swap-router",
        "exact-input-single",
        [
          Cl.uint(poolId),
          Cl.principal(`${deployer}.mock-token`),
          Cl.principal(`${deployer}.cxd-token`),
          Cl.uint(1000000),
          Cl.uint(0)
        ],
        deployer
      );

      expect(result.result).toEqual(Cl.ok(Cl.uint(987000)));
    });
  });
});
