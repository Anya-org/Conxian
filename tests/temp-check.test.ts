import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeAll } from "vitest";
import { initSimnet } from "@stacks/clarinet-sdk";

const CONTRACT_NAME = "error-utils";
const DEFAULT_SENDER = "ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE";

describe("error-utils contract", () => {
  let simnet: any;
  let deployer: string;

  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
    deployer = simnet.getAccounts().get("deployer")!;
    await simnet.deploy({
      contractName: CONTRACT_NAME,
      contractSource: `(define-read-only (get-last-error) (ok u0))`,
      sender: deployer
    });
  });

  it("should be a valid contract", () => {
    const { result } = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      "get-last-error",
      [],
      DEFAULT_SENDER
    );
    expect(result).toEqual(Cl.ok(Cl.uint(0)));
  });
});
