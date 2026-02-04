import { describe, expect, it, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';

describe('lending-manager', () => {
  let simnet: Simnet;
  let deployer: string;

  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('should deposit assets successfully', async () => {
    const { result } = await simnet.callPublicFn(
      'lending-manager',
      'deposit',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)],
      deployer,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('should withdraw assets successfully', async () => {
    const { result } = await simnet.callPublicFn(
      'lending-manager',
      'withdraw',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)],
      deployer,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('should borrow assets successfully', async () => {
    const { result } = await simnet.callPublicFn(
      'lending-manager',
      'borrow',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)],
      deployer,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('should repay assets successfully', async () => {
    const { result } = await simnet.callPublicFn(
      'lending-manager',
      'repay',
      [Cl.contractPrincipal(deployer, 'mock-token'), Cl.uint(100)],
      deployer,
    );
    expect(result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
