
import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from './setup-test-env';

describe('Circuit Breaker Integration Tests', () => {
    let deployer: string;
  let wallet1: string;

  beforeAll(async () => {

    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('ensures only the admin can set the circuit breaker in oracle-aggregator', () => {
    // Non-admin attempts to set the circuit breaker
    let result = simnet.callPublicFn(
        'oracle-aggregator',
        'set-circuit-breaker',
        [Cl.principal(`${deployer}.circuit-breaker`)],
        wallet1
    );
    expect(result.result).toEqual(Cl.error(Cl.uint(1001))); // ERR_CB_UNAUTHORIZED in oracle-aggregator

    // Admin successfully sets the circuit breaker
    result = simnet.callPublicFn(
        'oracle-aggregator',
        'set-circuit-breaker',
        [Cl.principal(`${deployer}.circuit-breaker`)],
        deployer
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('correctly trips and resets the circuit breaker', () => {
    const cbContract = `${deployer}.mock-circuit-breaker`;
    const oracleContract = 'oracle-aggregator';

    // Set CB in Oracle using mock-circuit-breaker (which has report-circuit-state integration)
    simnet.callPublicFn(oracleContract, 'set-circuit-breaker', [Cl.principal(cbContract)], deployer);

    // Initial status: Closed (returns ok true)
    let check = simnet.callReadOnlyFn(oracleContract, 'check-circuit-breaker', [], deployer);
    expect(check.result).toEqual(Cl.ok(Cl.bool(true)));

    // Trip the breaker using mock-circuit-breaker (registered as CB above)
    simnet.callPublicFn('mock-circuit-breaker', 'set-circuit-open', [Cl.bool(true)], deployer);

    // Now it should be open (returns ERR_CIRCUIT_OPEN u1003)
    check = simnet.callReadOnlyFn(oracleContract, 'check-circuit-breaker', [], deployer);
    expect(check.result).toEqual(Cl.error(Cl.uint(1003)));

    // Reset it
    simnet.callPublicFn('mock-circuit-breaker', 'set-circuit-open', [Cl.bool(false)], deployer);

    // Back to closed
    check = simnet.callReadOnlyFn(oracleContract, 'check-circuit-breaker', [], deployer);
    expect(check.result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
