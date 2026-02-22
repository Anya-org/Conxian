import { describe, it, expect } from "vitest";
import { simnet } from "./setup-test-env";

describe("Simple Load Test", () => {
  it("should load conxian-access", async () => {
    console.log("Accounts:", Array.from(simnet.getAccounts().entries()));
    const contract = simnet.getContractSource("conxian-access");
    expect(contract).toBeDefined();
  });
});
