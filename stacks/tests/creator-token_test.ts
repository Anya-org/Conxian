import { describe, it, beforeEach, expect } from 'vitest';
import { initSimnet } from '@hirosystems/clarinet-sdk';
import { Cl } from '@stacks/transactions';

describe('Creator Token (SDK) - PRD CREATOR-TOKEN alignment', () => {
  let simnet: any; let accounts: Map<string, any>; let deployer: string; let wallet1: string; let wallet2: string;
  beforeEach(async () => { 
    simnet = await initSimnet(); 
    accounts = simnet.getAccounts(); 
    deployer = accounts.get('deployer')!; 
    wallet1 = accounts.get('wallet_1')!; 
    wallet2 = accounts.get('wallet_2') || 'STB44HYPYAT2BB2QE513NSP81HTMYWBJP02HPGK6';
    
    // Set up authorization: Make deployer the authorized bounty-system for testing
    // First call as DAO governance (which is initially the deployer's .dao-governance contract)
    const daoGovernance = "STC5KHM41H6WHAST7MWWDD807YSPRQKJ68T330BQ"; // The actual DAO governance in simnet
    simnet.callPublicFn('creator-token', 'set-bounty-system', [Cl.principal(deployer)], daoGovernance);
  });

  it('PRD CREATOR-META: Basic SIP-010 functionality works', () => {
    // Test token metadata
    let result = simnet.callReadOnlyFn('creator-token', 'get-name', [], deployer);
    expect(result.result.type).toBe('ok');
    expect((result.result as any).value.value).toBe('AutoCreator');
    
    result = simnet.callReadOnlyFn('creator-token', 'get-symbol', [], deployer);
    expect(result.result.type).toBe('ok');
    expect((result.result as any).value.value).toBe('ACTR');
    
    result = simnet.callReadOnlyFn('creator-token', 'get-decimals', [], deployer);
    expect(result.result.type).toBe('ok');
    expect((result.result as any).value.value).toBe(6n);
    
    // Debug: Try to set authorization as the actual DAO governance principal
    const daoGovernance = "STC5KHM41H6WHAST7MWWDD807YSPRQKJ68T330BQ";
    const authSetup = simnet.callPublicFn('creator-token', 'set-bounty-system', [Cl.principal(deployer)], daoGovernance);
    console.log('Authorization setup result:', JSON.stringify(authSetup.result));
    
    // Test minting (as bounty system)
    const mint = simnet.callPublicFn('creator-token', 'mint', [
        Cl.principal(wallet1),
        Cl.uint(100000)
    ], deployer); // Deployer acts as bounty system after authorization
    console.log('Mint result:', JSON.stringify(mint.result));
    expect(mint.result.type).toBe('ok');
    
    // Check balance
    result = simnet.callReadOnlyFn('creator-token', 'get-balance-of', [
        Cl.principal(wallet1)
    ], deployer);
    expect(result.result.type).toBe('ok');
    expect((result.result as any).value.value).toBe(100000n);
  });

  it('PRD CREATOR-TRANSFER: Test transfer functionality', () => {
    // First mint to wallet1
    simnet.callPublicFn('creator-token', 'mint', [
        Cl.principal(wallet1),
        Cl.uint(100000)
    ], deployer);
    
    // Test transfer
    const transfer = simnet.callPublicFn('creator-token', 'transfer', [
        Cl.principal(wallet2),
        Cl.uint(25000)
    ], wallet1);
    expect(transfer.result.type).toBe('ok');
    
    // Verify balances after transfer
    let result = simnet.callReadOnlyFn('creator-token', 'get-balance-of', [
        Cl.principal(wallet1)
    ], deployer);
    expect(result.result.type).toBe('ok');
    expect((result.result as any).value.value).toBe(75000n);
    
    result = simnet.callReadOnlyFn('creator-token', 'get-balance-of', [
        Cl.principal(wallet2)
    ], deployer);
    expect(result.result.type).toBe('ok');
    expect((result.result as any).value.value).toBe(25000n);
  });

  it('PRD CREATOR-VEST: Vesting schedule creation and claiming', () => {
    // Create vesting schedule
    const mintVesting = simnet.callPublicFn('creator-token', 'mint-with-vesting', [
        Cl.principal(wallet1),
        Cl.uint(100000), // 100k tokens
        Cl.uint(144), // 1 day cliff
        Cl.uint(1008) // 1 week vesting
    ], deployer);
    expect(mintVesting.result.type).toBe('ok');
    expect((mintVesting.result as any).value.value).toBe(1n); // schedule-id
    
    // Check vesting schedule
    let result = simnet.callReadOnlyFn('creator-token', 'get-vesting-schedule', [
        Cl.principal(wallet1),
        Cl.uint(1)
    ], deployer);
    expect(result.result.type).toBe('some');
    const schedule = (result.result as any).value.value;
    expect(schedule['total-amount'].value).toBe(100000n);
    expect(schedule['cliff-blocks'].value).toBe(144n);
    
    // Try to claim before cliff (should be 0)
    result = simnet.callReadOnlyFn('creator-token', 'calculate-vested-amount', [
        Cl.principal(wallet1),
        Cl.uint(1)
    ], deployer);
    expect((result.result as any).value).toBe(0n);
    
    // Advance past cliff by simulating via multiple calls
    for (let i = 0; i < 20; i++) {
      simnet.callReadOnlyFn('creator-token', 'get-vesting-schedule', [Cl.principal(wallet1), Cl.uint(1)], deployer);
    }
    
    // Check vested amount (should be some portion)
    result = simnet.callReadOnlyFn('creator-token', 'calculate-vested-amount', [
        Cl.principal(wallet1),
        Cl.uint(1)
    ], deployer);
    const vestedAmount = (result.result as any).value;
    expect(vestedAmount).toBeGreaterThan(0n);
    
    // Claim vested tokens
    const claim = simnet.callPublicFn('creator-token', 'claim-vested-tokens', [
        Cl.uint(1)
    ], wallet1);
    expect(claim.result.type).toBe('ok');
    expect((claim.result as any).value.value).toBe(vestedAmount);
    
    // Check balance increased
    result = simnet.callReadOnlyFn('creator-token', 'get-balance-of', [
        Cl.principal(wallet1)
    ], deployer);
    expect(result.result.type).toBe('ok');
    expect((result.result as any).value.value).toBe(vestedAmount);
  });

  it('PRD CREATOR-AUTH: Only authorized contracts can mint', () => {
    // Unauthorized user tries to mint
    const unauthorized = simnet.callPublicFn('creator-token', 'mint', [
        Cl.principal(wallet2),
        Cl.uint(50000)
    ], wallet1); // Not authorized
    expect(unauthorized.result.type).toBe('err');
    expect((unauthorized.result as any).value.value).toBe(100n); // unauthorized
  });

  it('PRD CREATOR-BURN: Burn functionality works', () => {
    // Mint tokens first
    simnet.callPublicFn('creator-token', 'mint', [
        Cl.principal(wallet1),
        Cl.uint(100000)
    ], deployer);
    
    // Check initial supply
    let result = simnet.callReadOnlyFn('creator-token', 'get-total-supply', [], deployer);
    expect(result.result.type).toBe('ok');
    expect((result.result as any).value.value).toBe(100000n);
    
    // Burn tokens
    const burn = simnet.callPublicFn('creator-token', 'burn', [
        Cl.uint(30000)
    ], wallet1);
    expect(burn.result.type).toBe('ok');
    
    // Check balance and supply after burn
    result = simnet.callReadOnlyFn('creator-token', 'get-balance-of', [
        Cl.principal(wallet1)
    ], deployer);
    expect(result.result.type).toBe('ok');
    expect((result.result as any).value.value).toBe(70000n);
    
    result = simnet.callReadOnlyFn('creator-token', 'get-total-supply', [], deployer);
    expect(result.result.type).toBe('ok');
    expect((result.result as any).value.value).toBe(70000n);
  });

  it('PRD CREATOR-ACCESS: Unauthorized burn attempts fail', () => {
    // First mint to wallet1
    simnet.callPublicFn('creator-token', 'mint', [
        Cl.principal(wallet1),
        Cl.uint(100000)
    ], deployer);
    
    // Try to burn from wallet2 (no tokens)
    const burnEmpty = simnet.callPublicFn('creator-token', 'burn', [
        Cl.uint(10000)
    ], wallet2);
    expect(burnEmpty.result.type).toBe('err');
  });
});
