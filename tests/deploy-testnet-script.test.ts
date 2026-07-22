// @vitest-environment node
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  DEPLOYMENT_SCOPE,
  DEPLOYMENT_SEQUENCE,
  DEPLOYMENT_TRANSACTION_POLICY,
} from "../scripts/deploy-testnet";
import { PostConditionMode } from "@stacks/transactions";

const helperSource = readFileSync(new URL("../scripts/deploy-testnet.ts", import.meta.url), "utf8");

describe("testnet deployment helper", () => {
  it("uses the repository revenue-automation path", () => {
    expect(DEPLOYMENT_SEQUENCE.find((contract) => contract.name === "revenue-automation")?.path).toBe(
      "contracts/treasury/revenue-automation.clar",
    );
  });

  it("uses deny-mode post conditions", () => {
    expect(DEPLOYMENT_TRANSACTION_POLICY.postConditionMode).toBe(PostConditionMode.Deny);
  });

  it("is explicitly bounded to preparatory testnet work", () => {
    expect(DEPLOYMENT_SCOPE).toBe("testnet-helper-preparatory-only");
    expect(helperSource).toContain("not the full-system");
    expect(helperSource).toContain("or partnership deployer");
    expect(helperSource).toContain('requiredEnvironment("DEPLOYMENT_PLAN_PATH")');
    expect(helperSource).toContain("matching");
  });

  it("retains only a broadcast/partial candidate until complete verification", () => {
    expect(helperSource).toContain('evidenceStatus: "broadcast"');
    expect(helperSource).toContain('coverage: "partial"');
    expect(helperSource).toContain("writeBroadcastCandidate();");
    expect(helperSource).toContain("} finally {");
    expect(helperSource).not.toContain('evidenceStatus: "confirmed"');
    expect(helperSource).not.toContain('coverage: "complete"');
  });
});
