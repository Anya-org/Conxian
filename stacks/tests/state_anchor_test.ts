import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";
import { initSimnet } from "@hirosystems/clarinet-sdk";

describe("state-anchor", () => {
  let simnet: any;
  let accounts: Map<string, any>;
  let deployer: any;
  let wallet1: any;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  it("anchors state root hash successfully", async () => {
    const stateRoot = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
    const blockHeight = 100;

    // Anchor state
    const { result } = simnet.callPublicFn(
      "state-anchor",
      "anchor-state",
      [
        Cl.bufferFromHex(stateRoot),
        Cl.uint(blockHeight)
      ],
      deployer
    );

    expect(result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });

    // Verify state was anchored
    const stateResult = simnet.callReadOnlyFn(
      "state-anchor",
      "get-anchored-state",
      [Cl.uint(blockHeight)],
      deployer
    );

    expect(stateResult.result).toEqual({ 
      type: 'some', 
      value: { 
        type: 'tuple', 
        value: {
          'state-root': { type: 'buffer', value: Buffer.from(stateRoot.slice(2), 'hex') },
          'anchor-height': { type: 'uint', value: BigInt(blockHeight) },
          'timestamp': { type: 'uint', value: expect.any(BigInt) }
        }
      }
    });
  });

  it("rejects unauthorized state anchoring", async () => {
    const stateRoot = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
    const blockHeight = 100;

    // Try to anchor state from non-deployer
    const { result } = simnet.callPublicFn(
      "state-anchor",
      "anchor-state",
      [
        Cl.bufferFromHex(stateRoot),
        Cl.uint(blockHeight)
      ],
      wallet1
    );

    expect(result).toEqual({ type: 'err', value: { type: 'uint', value: 403n } }); // err-unauthorized
  });

  it("emits proper events on state anchoring", async () => {
    const stateRoot = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
    const blockHeight = 100;

    // Anchor state and check events
    const receipt = simnet.callPublicFn(
      "state-anchor",
      "anchor-state",
      [
        Cl.bufferFromHex(stateRoot),
        Cl.uint(blockHeight)
      ],
      deployer
    );

    // Check for event emission
    expect(receipt.events).toHaveLength(1);
    expect(receipt.events[0].event).toBe('print');
    expect(receipt.events[0].data).toMatchObject({
      type: 'tuple',
      value: {
        event: { type: 'ascii', value: 'state-anchored' },
        'state-root': { type: 'buffer', value: Buffer.from(stateRoot.slice(2), 'hex') },
        height: { type: 'uint', value: BigInt(blockHeight) },
        'event-code': { type: 'uint', value: 2001n }
      }
    });
  });

  it("handles multiple state anchors for different heights", async () => {
    const states = [
      { root: "0x1111111111111111111111111111111111111111111111111111111111111111", height: 100 },
      { root: "0x2222222222222222222222222222222222222222222222222222222222222222", height: 101 },
      { root: "0x3333333333333333333333333333333333333333333333333333333333333333", height: 102 }
    ];

    // Anchor multiple states
    for (const state of states) {
      const result = simnet.callPublicFn(
        "state-anchor",
        "anchor-state",
        [
          Cl.bufferFromHex(state.root),
          Cl.uint(state.height)
        ],
        deployer
      );
      expect(result.result).toEqual({ type: 'ok', value: { type: 'bool', value: true } });
    }

    // Verify all states are stored correctly
    for (const state of states) {
      const stateResult = simnet.callReadOnlyFn(
        "state-anchor",
        "get-anchored-state",
        [Cl.uint(state.height)],
        deployer
      );

      expect(stateResult.result).toEqual({ 
        type: 'some', 
        value: { 
          type: 'tuple', 
          value: {
            'state-root': { type: 'buffer', value: Buffer.from(state.root.slice(2), 'hex') },
            'anchor-height': { type: 'uint', value: BigInt(state.height) },
            'timestamp': { type: 'uint', value: expect.any(BigInt) }
          }
        }
      });
    }
  });

  it("returns none for non-existent state", async () => {
    // Query non-existent state
    const stateResult = simnet.callReadOnlyFn(
      "state-anchor",
      "get-anchored-state",
      [Cl.uint(999)],
      deployer
    );

    expect(stateResult.result).toEqual({ type: 'none' });
  });
});
