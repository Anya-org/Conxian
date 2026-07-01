import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

const ORACLE_AGGREGATOR_V2_CONTRACT_NAME = 'oracle-aggregator';

describe('P0 Circuit Breaker Logic Flaw Mitigation Tests', () => {
  let deployer: any;
  let wallet1: any;

  beforeEach(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('ensures only the admin can set the circuit breaker', () => {
    let result = simnet.callPublicFn(ORACLE_AGGREGATOR_V2_CONTRACT_NAME, 'set-circuit-tripped', [Cl.bool(true)], wallet1);
    expect(result.result).toEqual(Cl.error(Cl.uint(1001)));

    result = simnet.callPublicFn(ORACLE_AGGREGATOR_V2_CONTRACT_NAME, 'set-circuit-tripped', [Cl.bool(true)], deployer);
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('correctly checks the status of the dynamic circuit breaker', () => {
    simnet.callPublicFn(ORACLE_AGGREGATOR_V2_CONTRACT_NAME, 'set-circuit-tripped', [Cl.bool(false)], deployer);

    let isCircuitOpen = simnet.callPublicFn(ORACLE_AGGREGATOR_V2_CONTRACT_NAME, 'check-circuit-breaker', [], deployer);
    expect(Cl.prettyPrint(isCircuitOpen.result)).toContain('true');

    simnet.callPublicFn(ORACLE_AGGREGATOR_V2_CONTRACT_NAME, 'set-circuit-tripped', [Cl.bool(true)], deployer);

    isCircuitOpen = simnet.callPublicFn(ORACLE_AGGREGATOR_V2_CONTRACT_NAME, 'check-circuit-breaker', [], deployer);
    expect(Cl.prettyPrint(isCircuitOpen.result)).toContain('u1003');
  });
});
