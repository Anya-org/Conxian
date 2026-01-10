import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { initSimnet, type Simnet } from "@stacks/clarinet-sdk";
import { Cl } from "@stacks/transactions";

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe("Governance Tests", () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  describe("Operations Engine", () => {
    it("should have conxian-operations-engine deployed", () => {
      const contract = simnet.getContractSource("conxian-operations-engine");
      expect(contract).toBeDefined();
    });

    it("should allow operational adjustments", () => {
      const params = Cl.bufferFromHex("00"); // Dummy params
      const result = simnet.callPublicFn(
        "conxian-operations-engine",
        "execute-operational-adjustment",
        [params],
        deployer
      );
      // Should succeed since deployer is the default operator-controller
      expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
    });

    it("should check failsafe status", () => {
      const result = simnet.callReadOnlyFn(
        "conxian-operations-engine",
        "is-failsafe-active",
        [],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.bool(false)));
    });
  });

  describe("Agent Risk", () => {
    it("should have agent-risk deployed", () => {
      const contract = simnet.getContractSource("agent-risk");
      expect(contract).toBeDefined();
    });

    it("should get contract owner", () => {
      const result = simnet.callReadOnlyFn(
        "agent-risk",
        "get-contract-owner",
        [],
        deployer
      );
      expect(result.result).toEqual(Cl.ok(Cl.principal(deployer)));
    });
  });

  describe("Agent Treasury", () => {
    it("should have agent-treasury deployed", () => {
      const contract = simnet.getContractSource("agent-treasury");
      expect(contract).toBeDefined();
    });
  });

  describe("Proposal Engine", () => {
    it("should have proposal-engine deployed", () => {
      const contract = simnet.getContractSource("proposal-engine");
      expect(contract).toBeDefined();
    });

    it("should have proposal-registry deployed", () => {
      const contract = simnet.getContractSource("proposal-registry");
      expect(contract).toBeDefined();
    });

    it("should have proposal-executor deployed", () => {
      const contract = simnet.getContractSource("proposal-executor");
      expect(contract).toBeDefined();
    });
  });

  describe("Reputation Engine", () => {
    it("should have reputation-engine deployed", () => {
      const contract = simnet.getContractSource("reputation-engine");
      expect(contract).toBeDefined();
    });

    it("should have reputation-engine-trait deployed", () => {
      const contract = simnet.getContractSource("reputation-engine-trait");
      expect(contract).toBeDefined();
    });
  });

  describe("Enhanced Governance NFT", () => {
    it("should have enhanced-governance-nft deployed", () => {
      const contract = simnet.getContractSource("enhanced-governance-nft");
      expect(contract).toBeDefined();
    });
  });

  describe("Governance Traits", () => {
    it("should have governance-traits deployed", () => {
      const contract = simnet.getContractSource("governance-traits");
      expect(contract).toBeDefined();
    });

    it("should have conxian-service-trait deployed", () => {
      const contract = simnet.getContractSource("conxian-service-trait");
      expect(contract).toBeDefined();
    });
  });

  describe("Upgrade Controller", () => {
    it("should have upgrade-controller deployed", () => {
      const contract = simnet.getContractSource("upgrade-controller");
      expect(contract).toBeDefined();
    });
  });

  describe("Voting System", () => {
    it("should have voting contract deployed", () => {
      const contract = simnet.getContractSource("voting");
      expect(contract).toBeDefined();
    });
  });

  describe("Community DAO", () => {
    it("should have community-dao deployed", () => {
      const contract = simnet.getContractSource("community-dao");
      expect(contract).toBeDefined();
    });

    it("should have community-governance-token deployed", () => {
      const contract = simnet.getContractSource("community-governance-token");
      expect(contract).toBeDefined();
    });
  });

  describe("Governance Handover", () => {
    it("should have governance-handover deployed", () => {
      const contract = simnet.getContractSource("governance-handover");
      expect(contract).toBeDefined();
    });
  });

  describe("Signed Data Base", () => {
    it("should have signed-data-base deployed", () => {
      const contract = simnet.getContractSource("signed-data-base");
      expect(contract).toBeDefined();
    });
  });
});
