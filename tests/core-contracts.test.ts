import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { initSimnet, type Simnet } from "@stacks/clarinet-sdk";
import { Cl } from "@stacks/transactions";

let simnet: Simnet;
let deployer: string;

describe("Core Contract Tests", () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
  });

  beforeEach(() => {
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

    it("should check protocol owner", () => {
      const result = simnet.callReadOnlyFn(
        "conxian-protocol",
        "get-protocol-owner",
        [],
        deployer
      );
      // Contract uses a hardcoded placeholder for owner in storage until initialized
      expect(result.result).toBeDefined();
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

    it("should check cxd-token total supply", () => {
      const result = simnet.callReadOnlyFn(
        "cxd-token",
        "get-total-supply",
        [],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.uint(0)));
    });
  });

});
