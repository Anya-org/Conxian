import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { initSimnet } from "@stacks/clarinet-sdk";

describe("Autonomous Executive Agents", () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  describe("Risk Agent", () => {
    it("can assess system risk", () => {
      const { result } = simnet.callReadOnlyFn(
        "agent-risk",
        "assess-system-risk",
        [],
        deployer
      );
      expect(result).toBeDefined();
    });
  });

  describe("Treasury Agent", () => {
    it("can calculate cybernetic policy", () => {
      const { result } = simnet.callReadOnlyFn(
        "fiscal-orchestrator",
        "calculate-cybernetic-policy",
        [],
        deployer
      );
      expect(result).toBeDefined();
    });
  });
});
