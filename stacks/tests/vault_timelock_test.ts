import { describe, it, beforeEach, expect } from "vitest";
import { initSimnet } from "@hirosystems/clarinet-sdk";
import { Cl } from "@stacks/transactions";

// Helper to assert ok true across shapes
const assertOkTrue = (r: any) => {
  expect(r.type).toBe('ok');
  const v = r.value; if (v.type === 'true') return; expect(v).toEqual({ type: 'bool', value: true });
};

describe("vault + timelock", () => {
  let simnet: any; let accounts: Map<string,string>; let deployer: string; let wallet1: string;
  beforeEach(async () => {
    simnet = await initSimnet("./Clarinet.toml");
    accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it("deposit then withdraw updates balances correctly", () => {
    const vaultContract = `${deployer}.vault`;
    // Mint
    const mint = simnet.callPublicFn("mock-ft", "mint", [Cl.principal(wallet1), Cl.uint(1000)], deployer);
    assertOkTrue(mint.result);
    const approve = simnet.callPublicFn("mock-ft", "approve", [Cl.principal(vaultContract), Cl.uint(1000)], wallet1);
    assertOkTrue(approve.result);
    const deposit = simnet.callPublicFn("vault", "deposit", [Cl.uint(600)], wallet1);
    expect(deposit.result.type).toBe('ok');
    // credited shares 599
    if (!(deposit.result.value.type === 'uint' && deposit.result.value.value === 599n)) {
      throw new Error(`expected credited 599, got ${JSON.stringify(deposit.result)}`);
    }
    const bal = simnet.callReadOnlyFn("vault", "get-balance", [Cl.principal(wallet1)], wallet1);
    expect(bal.result.type).toBe('uint');
    expect(bal.result.value).toBe(599n);
    const withdraw = simnet.callPublicFn("vault", "withdraw", [Cl.uint(100)], wallet1);
    expect(withdraw.result.type).toBe('ok');
    const amt = withdraw.result.value; if (!(amt.type === 'uint' && amt.value === 100n)) throw new Error('withdraw amount mismatch');
    const bal2 = simnet.callReadOnlyFn("vault", "get-balance", [Cl.principal(wallet1)], wallet1);
    expect(bal2.result.value).toBe(499n);
  });

  it("timelock can pause vault after delay (simulated)", () => {
    const timelockId = `${deployer}.timelock`;
  // Timelock already the admin of vault by default (vault admin = .timelock)
  // Reduce delay to 0 so execution is immediate for test determinism
  const setDelay = simnet.callPublicFn("timelock", "set-min-delay", [Cl.uint(0)], deployer);
  assertOkTrue(setDelay.result);

  const queue = simnet.callPublicFn("timelock", "queue-set-paused", [Cl.bool(true)], deployer);
    // first id u0
    expect(queue.result.type).toBe('ok');
    const idv = queue.result.value; if (!(idv.type === 'uint' && idv.value === 0n)) throw new Error('expected id 0');
  // Execute immediately (no delay)
  const exec = simnet.callPublicFn("timelock", "execute-set-paused", [Cl.uint(0)], deployer);
  assertOkTrue(exec.result);
  const paused = simnet.callReadOnlyFn("vault", "get-paused", [], deployer);
  // Accept both primitive 'true' form and structured bool representation
  if (paused.result.type === 'true') {
    // already true
    expect(paused.result.type).toBe('true');
  } else {
    expect(paused.result.type).toBe('bool');
    expect(paused.result.value).toBe(true);
  }
  });
});
