import { describe, expect, it } from 'vitest';
import { Cl, cvToValue } from '@stacks/transactions';

describe('lending-manager', () => {
  it('should deposit assets successfully', () => {
    const { result } = simnet.callPublicFn(
      'lending-manager',
      'deposit',
      [Cl.contractPrincipal(simnet.deployer, 'token'), Cl.uint(100)],
      simnet.deployer,
    );
    expect(result).toBeOk(Cl.bool(true));
  });

  it('should withdraw assets successfully', () => {
    const { result } = simnet.callPublicFn(
      'lending-manager',
      'withdraw',
      [Cl.contractPrincipal(simnet.deployer, 'token'), Cl.uint(100)],
      simnet.deployer,
    );
    expect(result).toBeOk(Cl.bool(true));
  });

  it('should borrow assets successfully', () => {
    const { result } = simnet.callPublicFn(
      'lending-manager',
      'borrow',
      [Cl.contractPrincipal(simnet.deployer, 'token'), Cl.uint(100)],
      simnet.deployer,
    );
    expect(result).toBeOk(Cl.bool(true));
  });

  it('should repay assets successfully', () => {
    const { result } = simnet.callPublicFn(
      'lending-manager',
      'repay',
      [Cl.contractPrincipal(simnet.deployer, 'token'), Cl.uint(100)],
      simnet.deployer,
    );
    expect(result).toBeOk(Cl.bool(true));
  });
});
