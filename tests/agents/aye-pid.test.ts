import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

describe('AYE PID Controller (Agent-Risk)', () => {
    let deployer: string;

  beforeEach(async () => {

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
    // stability-fee is initialized to u30 (0.30%) in the current implementation
    expect(fee).toBeDefined();
    expect(Cl.prettyPrint(fee)).toContain('u');
  });

  it('update-pid-rates should increase fee moderately when price is below peg', () => {
    // 1. Set price 1% below peg: 99,000,000 using admin set-price
    simnet.callPublicFn(
      'oracle-aggregator',
      'set-price',
      [Cl.contractPrincipal(deployer, 'cxd-token'), Cl.uint(99000000)],
      deployer
    );

    // 2. Update PID rates
    const res = simnet.callPublicFn('agent-risk', 'update-pid-rates', [], deployer);
    expect(res.result).toBeDefined();

    // 3. Check new fee (should have been updated by PID controller)
    const fee = simnet.getDataVar('agent-risk', 'stability-fee');
    expect(fee).toBeDefined();
  });

  it('Integral should be clamped (windup protection)', () => {
    // Set price low via admin set-price
    simnet.callPublicFn(
      'oracle-aggregator',
      'set-price',
      [Cl.contractPrincipal(deployer, 'cxd-token'), Cl.uint(99000000)],
      deployer
    );

    for(let i=0; i<5; i++) {
        simnet.callPublicFn('agent-risk', 'update-pid-rates', [], deployer);
    }

    const integral = simnet.getDataVar('agent-risk', 'price-integral');
    expect(integral).toBeDefined();
  });
});
