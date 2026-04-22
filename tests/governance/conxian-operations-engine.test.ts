import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";
import { simnet } from '../setup-test-env';

const CONTRACT_NAME = "ops-engine";

describe("Conxian Operations Engine", () => {
    let deployer: string;
  let wallet1: string;

  beforeEach(async () => {

    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;

  });

  it("allows authorized operator to trigger emergency pause", () => {
    const { result } = simnet.callPublicFn(
      CONTRACT_NAME,
      "trigger-emergency-pause",
      [],
      deployer
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it("returns last action block", () => {
    const { result } = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      "get-last-action",
      [],
      deployer
    );
    expect(result).toBeDefined();
  });
});
