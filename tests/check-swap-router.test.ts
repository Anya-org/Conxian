import { describe, it, expect } from "vitest";
import { simnet } from "./setup-test-env";

describe("Swap Router Load Test", () => {
  it("should load swap-router", async () => {
    const contract = simnet.getContractSource("swap-router");
    expect(contract).toBeDefined();
  });
});
