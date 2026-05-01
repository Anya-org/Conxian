import { describe, expect, it, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

describe('lending-orchestrator', () => {
    let deployer: string;

  beforeAll(async () => {

    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    // Mint mock tokens to deployer for testing
    simnet.callPublicFn('mock-token', 'mint', [Cl.uint(1000000), Cl.principal(deployer)], deployer);
  });

  it('should deposit assets successfully', async () => {
    const { result } = await simnet.callPublicFn(
      'lending-orchestrator',
      'deposit',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)],
      deployer,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('should withdraw assets successfully', async () => {
    // Deposit first
    simnet.callPublicFn('lending-orchestrator', 'deposit', [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)], deployer);
    const { result } = await simnet.callPublicFn(
      'lending-orchestrator',
      'withdraw',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)],
      deployer,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('should borrow assets successfully', async () => {
    // Deposit first to establish liquidity
    simnet.callPublicFn('lending-orchestrator', 'deposit', [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(500)], deployer);
    const { result } = await simnet.callPublicFn(
      'lending-orchestrator',
      'borrow',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)],
      deployer,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('should repay assets successfully', async () => {
    // Setup: deposit + borrow
    simnet.callPublicFn('lending-orchestrator', 'deposit', [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(500)], deployer);
    simnet.callPublicFn('lending-orchestrator', 'borrow', [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)], deployer);
    // Mint repayment tokens
    simnet.callPublicFn('mock-token', 'mint', [Cl.uint(100), Cl.principal(deployer)], deployer);
    const { result } = await simnet.callPublicFn(
      'lending-orchestrator',
      'repay',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)],
      deployer,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
