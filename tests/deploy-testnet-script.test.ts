// @vitest-environment node
import { describe, expect, it } from "vitest";
import {
  DEPLOYMENT_SEQUENCE,
  DEPLOYMENT_TRANSACTION_POLICY,
} from "../scripts/deploy-testnet";
import { PostConditionMode } from "@stacks/transactions";

describe("testnet deployment helper", () => {
  it("uses the repository revenue-automation path", () => {
    expect(DEPLOYMENT_SEQUENCE.find((contract) => contract.name === "revenue-automation")?.path).toBe(
      "contracts/treasury/revenue-automation.clar",
    );
  });

  it("uses deny-mode post conditions", () => {
    expect(DEPLOYMENT_TRANSACTION_POLICY.postConditionMode).toBe(PostConditionMode.Deny);
  });
});
