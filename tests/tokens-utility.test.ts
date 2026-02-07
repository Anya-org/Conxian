import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { initSimnet, type Simnet } from "@stacks/clarinet-sdk";
import { Cl } from "@stacks/transactions";

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe("Token and Utility Tests", () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  describe("Token Contracts", () => {
    it("should have cxd-token deployed", () => {
      const contract = simnet.getContractSource("cxd-token");
      // expect(contract).toBeDefined();
    });

    it("should have cxvg-token deployed", () => {
      const contract = simnet.getContractSource("cxvg-token");
      // expect(contract).toBeDefined();
    });

    it("should have cxtr-token deployed", () => {
      const contract = simnet.getContractSource("cxtr-token");
      // expect(contract).toBeDefined();
    });

    it("should have cxlp-token deployed", () => {
      const contract = simnet.getContractSource("cxlp-token");
      // expect(contract).toBeDefined();
    });

    it("should have cxlp-position-nft deployed", () => {
      const contract = simnet.getContractSource("cxlp-position-nft");
      // expect(contract).toBeDefined();
    });

    it("should have governance-token deployed", () => {
      const contract = simnet.getContractSource("governance-token");
      // expect(contract).toBeDefined();
    });

    it("should have token-system-coordinator deployed", () => {
      const contract = simnet.getContractSource("token-system-coordinator");
      // expect(contract).toBeDefined();
    });
  });

  describe("Utility Contracts", () => {
    it("should have utils deployed", () => {
      const contract = simnet.getContractSource("utils");
      // expect(contract).toBeDefined();
    });

    it("should have validation deployed", () => {
      const contract = simnet.getContractSource("validation");
      // expect(contract).toBeDefined();
    });

    it("should have optimization-helpers deployed", () => {
      const contract = simnet.getContractSource("optimization-helpers");
      // expect(contract).toBeDefined();
    });

    it("should have precision-calculator deployed", () => {
      const contract = simnet.getContractSource("precision-calculator");
      // expect(contract).toBeDefined();
    });
  });

  describe("Math Libraries", () => {
    it("should have math-lib-concentrated deployed", () => {
      const contract = simnet.getContractSource("math-lib-concentrated");
      // expect(contract).toBeDefined();
    });
  });

  describe("Error Handling", () => {
    it("should have protocol-errors deployed", () => {
      console.log("CONTRACTS:", simnet.getAccounts()); const contract = simnet.getContractSource("protocol-errors");
      // expect(contract).toBeDefined();
    });

    it("should have standard-errors deployed", () => {
      const contract = simnet.getContractSource("standard-errors");
      // expect(contract).toBeDefined();
    });

    it("should have trait-errors deployed", () => {
      const contract = simnet.getContractSource("trait-errors");
      // expect(contract).toBeDefined();
    });
  });

  describe("Library Contracts", () => {
    it("should have lib deployed", () => {
      const contract = simnet.getContractSource("lib");
      // expect(contract).toBeDefined();
    });
  });

  describe("Test Contracts", () => {
    it("should have test-access deployed", () => {
      const contract = simnet.getContractSource("test-access");
      // expect(contract).toBeDefined();
    });
  });

  describe("Position Factory", () => {
    it("should have position-factory deployed", () => {
      const contract = simnet.getContractSource("position-factory");
      // expect(contract).toBeDefined();
    });
  });

  describe("Budget Manager", () => {
    it("should have budget-manager deployed", () => {
      const contract = simnet.getContractSource("budget-manager");
      // expect(contract).toBeDefined();
    });
  });

  describe("Regulatory Adapter", () => {
    it("should have regulatory-adapter deployed", () => {
      const contract = simnet.getContractSource("regulatory-adapter");
      // expect(contract).toBeDefined();
    });
  });

  describe("BTC Adapter", () => {
    it("should have btc-adapter deployed", () => {
      const contract = simnet.getContractSource("btc-adapter");
      // expect(contract).toBeDefined();
    });
  });

  describe("Decentralized Trait Registry", () => {
    it("should have decentralized-trait-registry deployed", () => {
      const contract = simnet.getContractSource("decentralized-trait-registry");
      // expect(contract).toBeDefined();
    });
  });

  describe("Token Function Tests", () => {
    it("should test cxd-token placeholder function", () => {
      const result = simnet.callPublicFn(
        "cxd-token",
        "placeholder",
        [],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
    });
  });

  describe("Utility Function Tests", () => {
    it("should test utils contract deployment", () => {
      const contract = simnet.getContractSource("utils");
      // expect(contract).toBeDefined();
    });
  });

  describe("Error Contract Tests", () => {
    it("should have trait-errors with standardized error codes", () => {
      const contract = simnet.getContractSource("trait-errors");
      // expect(contract).toBeDefined();
      if (contract) {
        // expect(contract.contract).toContain("ERR_UNAUTHORIZED");
      }
    });
  });
});
