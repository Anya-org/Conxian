
import { describe, it, expect, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from "@stacks/clarinet-sdk";

describe('Circuit Breaker Integration Tests', () => {
  let simnet: any;
  let deployer: string;
  let wallet1: string;

  beforeAll(async () => {
    simnet = await initSimnet();
    deployer = simnet.deployer;
    wallet1 = simnet.getAccounts().get('wallet_1')!;
  });

  it('ensures only the admin can set the circuit breaker in oracle-aggregator', () => {
    // Non-admin attempts to set the circuit breaker
    let result = simnet.callPublicFn(
        'oracle-aggregator',
        'set-circuit-breaker',
        [Cl.principal(`${deployer}.circuit-breaker`)],
        wallet1
    );
    expect(result.result).toEqual(Cl.error(Cl.uint(1000))); // ERR_UNAUTHORIZED in oracle-aggregator

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
    const cbContract = `${deployer}.circuit-breaker`;
    const oracleContract = 'oracle-aggregator';

    // Set CB in Oracle
    simnet.callPublicFn(oracleContract, 'set-circuit-breaker', [Cl.principal(cbContract)], deployer);

    // Initial status: Closed (returns ok true)
    let check = simnet.callReadOnlyFn(oracleContract, 'check-circuit-breaker', [], deployer);
    expect(check.result).toEqual(Cl.ok(Cl.bool(true)));

    // Trip the breaker for oracle-aggregator
    // Need ROLE_KEEPER (u2) or owner
    simnet.callPublicFn('circuit-breaker', 'set-contract-paused', [Cl.principal(`${deployer}.${oracleContract}`), Cl.bool(true)], deployer);

    // Now it should be open (returns err u1002 - ERR_CIRCUIT_OPEN in oracle-aggregator)
    check = simnet.callReadOnlyFn(oracleContract, 'check-circuit-breaker', [], deployer);
    expect(check.result).toEqual(Cl.error(Cl.uint(1002)));

    // Reset it
    simnet.callPublicFn('circuit-breaker', 'set-contract-paused', [Cl.principal(`${deployer}.${oracleContract}`), Cl.bool(false)], deployer);

    // Back to closed
    check = simnet.callReadOnlyFn(oracleContract, 'check-circuit-breaker', [], deployer);
    expect(check.result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
