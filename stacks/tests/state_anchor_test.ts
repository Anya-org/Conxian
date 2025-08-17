import { describe, it, expect, beforeEach } from "vitest";
import { initSimnet } from "@hirosystems/clarinet-sdk";
import { Cl } from "@stacks/transactions";

describe("state-anchor", () => {
  let simnet: any;

  beforeEach(async () => {
    simnet = await initSimnet();
  });

  it("allows deployer to anchor state root", async () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;

    const stateRoot = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";

    const { result } = simnet.callPublicFn(
      "state-anchor",
      "anchor-state",
      [
        Cl.bufferFromHex(stateRoot),
        Cl.uint(12345), // block height
        Cl.uint(1000000) // timestamp
      ],
      deployer
    );

    expect(result).toBeOk(Cl.bool(true));
  });

  it("rejects state anchor from non-deployer", async () => {
    const accounts = simnet.getAccounts();
    const wallet1 = accounts.get("wallet_1")!;

    const stateRoot = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";

    const { result } = simnet.callPublicFn(
      "state-anchor",
      "anchor-state",
      [
        Cl.bufferFromHex(stateRoot),
        Cl.uint(12345),
        Cl.uint(1000000)
      ],
      wallet1
    );

    expect(result).toBeErr(Cl.uint(401)); // err-unauthorized
  });

  it("emits event when anchoring state", async () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;

    const stateRoot = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";

    const receipt = simnet.callPublicFn(
      "state-anchor",
      "anchor-state",
      [
        Cl.bufferFromHex(stateRoot),
        Cl.uint(12345),
        Cl.uint(1000000)
      ],
      deployer
    );

    // Check that event was emitted with code u2001
    expect(receipt.events).toHaveLength(1);
    expect(receipt.events[0].event).toBe("print");
    expect(receipt.events[0].data.code).toEqual(Cl.uint(2001));
  });

  it("stores state root with metadata", async () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;

    const stateRoot = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
    const blockHeight = 12345;
    const timestamp = 1000000;

    simnet.callPublicFn(
      "state-anchor",
      "anchor-state",
      [
        Cl.bufferFromHex(stateRoot),
        Cl.uint(blockHeight),
        Cl.uint(timestamp)
      ],
      deployer
    );

    // Read back the anchored state
    const { result } = simnet.callReadOnlyFn(
      "state-anchor",
      "get-state-at-height",
      [Cl.uint(blockHeight)],
      deployer
    );

    expect(result).toBeOk(
      Cl.some(
        Cl.tuple({
          "state-root": Cl.bufferFromHex(stateRoot),
          "block-height": Cl.uint(blockHeight),
          "timestamp": Cl.uint(timestamp),
          "anchor-height": Cl.uint(simnet.blockHeight)
        })
      )
    );
  });

  it("returns none for non-existent state", async () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;

    const { result } = simnet.callReadOnlyFn(
      "state-anchor",
      "get-state-at-height",
      [Cl.uint(99999)],
      deployer
    );

    expect(result).toBeOk(Cl.none());
  });

  it("validates state root format", async () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;

    // Try with invalid state root (wrong length)
    const invalidStateRoot = "0x1234";

    const { result } = simnet.callPublicFn(
      "state-anchor",
      "anchor-state",
      [
        Cl.bufferFromHex(invalidStateRoot),
        Cl.uint(12345),
        Cl.uint(1000000)
      ],
      deployer
    );

    expect(result).toBeErr(Cl.uint(400)); // err-invalid-state-root
  });
});
