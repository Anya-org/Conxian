import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { initSimnet, type Simnet } from "@stacks/clarinet-sdk";
import { Cl } from "@stacks/transactions";

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe("Core Contract Tests", () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
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
      expect(result.result).toEqual(Cl.ok(Cl.bool(false)));
    });

    it("should check if caller is owner", () => {
      const result = simnet.callReadOnlyFn(
        "conxian-protocol",
        "is-owner",
        [],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
    });
  });

  describe("Traits System", () => {
    it("should have core-traits deployed", () => {
      const contract = simnet.getContractSource("core-traits");
      expect(contract).toBeDefined();
    });

    it("should have sip-standards trait deployed", () => {
      const contract = simnet.getContractSource("sip-standards");
      expect(contract).toBeDefined();
    });

    it("should have rbac-trait available", () => {
      // Test that the trait is properly defined
      const contract = simnet.getContractSource("core-traits");
      expect(contract).toBeDefined();
      if (contract) {
        expect(contract.contract).toContain("rbac-trait");
      }
    });
  });

  describe("Base Contracts", () => {
    it("should have ownable contract deployed", () => {
      const contract = simnet.getContractSource("ownable");
      expect(contract).toBeDefined();
    });

    it("should test ownable get-owner function", () => {
      const result = simnet.callReadOnlyFn(
        "ownable",
        "get-owner",
        [],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.principal(deployer)));
    });
  });

  describe("Admin Facade", () => {
    it("should have admin-facade contract deployed", () => {
      const contract = simnet.getContractSource("admin-facade");
      expect(contract).toBeDefined();
    });
  });

  describe("Token System", () => {
    it("should have cxd-token contract deployed", () => {
      const contract = simnet.getContractSource("cxd-token");
      expect(contract).toBeDefined();
    });

    it("should have placeholder function in cxd-token", () => {
      const result = simnet.callPublicFn(
        "cxd-token",
        "placeholder",
        [],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
    });
  });

  describe("Batch Operations", () => {
    it("should have batch-operations contract deployed", () => {
      const contract = simnet.getContractSource("batch-operations");
      expect(contract).toBeDefined();
    });
  });
});
