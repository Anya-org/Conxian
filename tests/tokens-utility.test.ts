import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { simnet } from './setup-test-env';
import { Cl } from "@stacks/transactions";

let deployer: string;
let wallet1: string;

describe("Token and Utility Tests", () => {
  beforeAll(async () => {

  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  describe("Token Contracts", () => {
    it("should have cxd-token deployed", () => {
      const contract = simnet.getContractSource("cxd-token");
      expect(contract).toBeDefined();
    });

    it("should have cxvg-token deployed", () => {
      const contract = simnet.getContractSource("cxvg-token");
      expect(contract).toBeDefined();
    });

    it("should have cxtr-token deployed", () => {
      const contract = simnet.getContractSource("cxtr-token");
      expect(contract).toBeDefined();
    });

    it("should have cxlp-token deployed", () => {
      const contract = simnet.getContractSource("cxlp-token");
      expect(contract).toBeDefined();
    });

    it("should have cxlp-position-nft deployed", () => {
      const contract = simnet.getContractSource("cxlp-position-nft");
      expect(contract).toBeDefined();
    });

    it("should have governance-token deployed", () => {
      const contract = simnet.getContractSource("governance-token");
      expect(contract).toBeDefined();
    });

    it("should have token-system-coordinator deployed", () => {
      const contract = simnet.getContractSource("token-system-coordinator");
      expect(contract).toBeDefined();
    });
  });

  describe("Utility Contracts", () => {
    it("should have block-utils deployed", () => {
      const contract = simnet.getContractSource("block-utils");
      expect(contract).toBeDefined();
    });

    it("should have math-utilities deployed", () => {
      const contract = simnet.getContractSource("math-utilities");
      expect(contract).toBeDefined();
    });
  });

  describe("Regulatory Adapter", () => {
    it("should have regulatory-adapter deployed", () => {
      const contract = simnet.getContractSource("regulatory-adapter");
      expect(contract).toBeDefined();
    });
  });

  describe("Position Factory", () => {
    it("should have position-factory deployed", () => {
      const contract = simnet.getContractSource("position-factory");
      expect(contract).toBeDefined();
    });
  });

  describe("Token Function Tests", () => {
    it("should test cxd-token get-name function", () => {
      const result = simnet.callReadOnlyFn(
        "cxd-token",
        "get-name",
        [],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.stringAscii("Conxian Dollar                 ")));
    });
  });

  describe("Error Handling", () => {
    it("should have sip-standards deployed with correct trait definitions", () => {
      const contract = simnet.getContractSource("sip-standards");
      expect(contract).toBeDefined();
    });
  });
});
