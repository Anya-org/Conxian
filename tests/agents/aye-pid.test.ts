import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

describe('AYE PID Controller (Agent-Risk)', () => {
  let deployer: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
  });

  it('Initially stability fee should be 500 bps (5%)', () => {
    const fee = simnet.getDataVar('agent-risk', 'stability-fee');
    expect(fee).toEqual(Cl.uint(500));
  });

  it('update-pid-rates should increase fee moderately when price is below peg', () => {
    // 1. Set price 1% below peg: 99,000,000
    // Use massive weight to override previous values
    simnet.callPublicFn(
      'oracle-aggregator',
      'set-source',
      [Cl.principal(deployer + '.cxd-token'), Cl.uint(99000000), Cl.uint(1000000000)],
      deployer
    );

    // 2. Update PID rates
    simnet.callPublicFn('agent-risk', 'update-pid-rates', [], deployer);

    // 3. Check new fee
    const fee = simnet.getDataVar('agent-risk', 'stability-fee');
    expect(fee).toEqual(Cl.uint(2000));
  });

  it('Integral should be clamped (windup protection)', () => {
    // Keep price low for multiple updates
    for(let i=0; i<15; i++) {
        simnet.callPublicFn('agent-risk', 'update-pid-rates', [], deployer);
    }

    const integral = simnet.getDataVar('agent-risk', 'price-integral');
    // Limit is 10,000,000
    expect(integral).toEqual(Cl.int(10000000));
  });

  it('Deadband should prevent adjustments for small errors', () => {
    // Set price exactly at peg: 100,000,000
    simnet.callPublicFn(
      'oracle-aggregator',
      'set-source',
      [Cl.principal(deployer + '.cxd-token'), Cl.uint(100000000), Cl.uint(10000000000)],
      deployer
    );

    const prevIntegral = simnet.getDataVar('agent-risk', 'price-integral');

    simnet.callPublicFn('agent-risk', 'update-pid-rates', [], deployer);

    const newIntegral = simnet.getDataVar('agent-risk', 'price-integral');

    // Integral should stay the same (since error=0)
    expect(newIntegral).toEqual(prevIntegral);
  });
});
