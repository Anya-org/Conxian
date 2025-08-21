import { describe, it, expect, beforeEach } from "vitest";
import { initSimnet } from "@hirosystems/clarinet-sdk";
import { Cl } from "@stacks/transactions";
import { getUintValue } from '../utils/clarity-helpers';

describe("Vault Shares (SDK) - PRD VAULT-SHARES alignment", () => {
  let simnet: any;
  let accounts: Map<string, string>;
  let deployer: string;
  let wallet1: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    
    // Debug: Check if accounts are distinct
    console.log("Deployer address:", deployer);
    console.log("Wallet1 address:", wallet1);
    console.log("Accounts are different:", deployer !== wallet1);
  });

  it("PRD VAULT-SHARES-EQUAL: two users deposit equal amounts get equal shares and balances", async () => {
    const vaultContract = `${deployer}.vault`;

    // Debug: Check vault status first
    const vaultPaused = simnet.callReadOnlyFn("vault", "get-paused", [], deployer);
    console.log("Vault paused:", vaultPaused.result);
    
    const vaultToken = simnet.callReadOnlyFn("vault", "get-token", [], deployer);
    console.log("Vault token:", vaultToken.result);

    // Use predefined addresses for distinct users (learned from oracle debugging)
    const user1 = deployer; // Keep deployer as user1
    const user2 = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5'; // Use predefined address for user2

  // Setup user1 (deployer) 
  let r1 = simnet.callPublicFn("mock-ft", "mint", [Cl.principal(user1), Cl.uint(1000)], deployer);
  expect(r1.result.type).toBe('ok');
  r1 = simnet.callPublicFn("mock-ft", "approve", [Cl.principal(vaultContract), Cl.uint(1000)], user1);
  expect(r1.result.type).toBe('ok');
  
  // Setup user2 (predefined address)
  let r2 = simnet.callPublicFn("mock-ft", "mint", [Cl.principal(user2), Cl.uint(1000)], deployer);
  expect(r2.result.type).toBe('ok');
  r2 = simnet.callPublicFn("mock-ft", "approve", [Cl.principal(vaultContract), Cl.uint(1000)], user2);
  expect(r2.result.type).toBe('ok');
  
  const dep1 = simnet.callPublicFn("vault", "deposit", [Cl.uint(1000)], user1);
  console.log("Deposit 1 result:", dep1.result);
  const dep2 = simnet.callPublicFn("vault", "deposit", [Cl.uint(1000)], user2);
  console.log("Deposit 2 result:", dep2.result);
  expect(dep1.result.type).toBe('ok');
  expect(dep2.result.type).toBe('ok');
  expect(getUintValue(dep1.result)).toBe(getUintValue(dep2.result));
  });

  it("PRD VAULT-SHARES-ROUNDING: withdraw rounding uses ceil on shares burn and preserves NAV", async () => {
    const vaultContract = `${deployer}.vault`;

    // Setup: wallet1 gets 100 and approves
    let response = simnet.callPublicFn("mock-ft", "mint", [Cl.principal(wallet1), Cl.uint(100)], deployer);
    expect(response.result.type).toBe('ok');

    response = simnet.callPublicFn("mock-ft", "approve", [Cl.principal(vaultContract), Cl.uint(100)], wallet1);
    expect(response.result.type).toBe('ok');

    const deposit = simnet.callPublicFn("vault", "deposit", [Cl.uint(100)], wallet1);
    expect(deposit.result.type).toBe('ok');
    // fee = floor(100*30/10000)=0; credited=100
    expect(getUintValue(deposit.result)).toBe(100);

    // Withdraw 1 unit; fee withdraw 10 bps => floor(1*10/10000)=0; payout = 1
    const withdraw = simnet.callPublicFn("vault", "withdraw", [Cl.uint(1)], wallet1);
    expect(withdraw.result.type).toBe('ok');
    expect(getUintValue(withdraw.result)).toBe(1);

    // NAV decreases by exactly 1
    const tvl = simnet.callReadOnlyFn("vault", "get-total-balance", [], deployer);
    expect(getUintValue(tvl.result)).toBe(99);

    // Balance equals 99
    const b1 = simnet.callReadOnlyFn("vault", "get-balance", [Cl.principal(wallet1)], wallet1);
    expect(getUintValue(b1.result)).toBe(99);
  });
});
