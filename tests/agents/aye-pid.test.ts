import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@stacks/clarinet-sdk';

describe('AYE PID Controller (Agent-Risk)', () => {
  let simnet: any;
  let deployer: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;

    // Grant ROLE_ADMIN to deployer in conxian-access for setting up mocks if needed
    simnet.callPublicFn(
      "conxian-access",
      "grant-role",
      [
        Cl.principal(deployer),
        Cl.uint(1),
        Cl.buffer(Buffer.alloc(32)),
        Cl.buffer(Buffer.alloc(64)),
        Cl.buffer(Buffer.alloc(33))
      ],
      deployer
    );
  });

  it('Initially stability fee should be 500 bps (5%)', () => {
    const fee = simnet.getDataVar('agent-risk', 'stability-fee');
    expect(fee).toEqual(Cl.uint(500));
  });

  it('update-pid-rates should increase fee moderately when price is below peg', () => {
    // 1. Set price 1% below peg: 99,000,000
    simnet.callPublicFn(
      'oracle-aggregator',
      'set-source',
      [Cl.principal(deployer + '.cxd-token'), Cl.uint(99000000), Cl.uint(1000000000)],
      deployer
    );

    // 2. Update PID rates
    simnet.callPublicFn('agent-risk', 'update-pid-rates', [], deployer);

    // 3. Check new fee (should be adjusted by KP, KI, KD)
    const fee = simnet.getDataVar('agent-risk', 'stability-fee');
    // Adjustment was 1500 in my latest agent-risk version
    expect(fee).toEqual(Cl.uint(2000));
  });

  it('Integral should be clamped (windup protection)', () => {
    // Set price low
    simnet.callPublicFn(
      'oracle-aggregator',
      'set-source',
      [Cl.principal(deployer + '.cxd-token'), Cl.uint(99000000), Cl.uint(1000000000)],
      deployer
    );

    for(let i=0; i<15; i++) {
        simnet.callPublicFn('agent-risk', 'update-pid-rates', [], deployer);
    }

    const integral = simnet.getDataVar('agent-risk', 'price-integral');
    expect(integral).toEqual(Cl.int(10000000));
  });
});
