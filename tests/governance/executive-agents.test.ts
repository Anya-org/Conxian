import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { simnet } from '../setup-test-env';

describe("Autonomous Executive Agents", () => {
    let deployer: string;

  beforeEach(async () => {

    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
  });

  describe("Risk Agent", () => {
    it("can assess system risk", () => {
      const { result } = simnet.callPublicFn(
        "agent-risk",
        "assess-system-risk",
        [Cl.principal(deployer + ".finance-metrics")],
        deployer
      );
      expect(result).toBeDefined();
    });
  });

  describe("Treasury Agent", () => {
    it("can calculate cybernetic policy", () => {
      const { result } = simnet.callPublicFn(
        "fiscal-orchestrator",
        "calculate-cybernetic-policy",
        [Cl.principal(deployer + ".finance-metrics")],
        deployer
      );
      expect(result).toBeDefined();
    });
  });
});
