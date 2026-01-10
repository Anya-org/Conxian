import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from "@stacks/clarinet-sdk";
import { resolve } from "path";

const ORACLE_AGGREGATOR_V2_CONTRACT_NAME = 'oracle-aggregator-v2';
const MOCK_CIRCUIT_BREAKER_CONTRACT_NAME = 'mock-circuit-breaker';

describe('P0 Circuit Breaker Logic Flaw Mitigation Tests', () => {
  let simnet: any;
  let deployer: any;
  let wallet1: any;
  let oracleAggregatorV2Contract: any;
  let mockCircuitBreakerContract: any;

  beforeEach(async () => {
    const manifestPath = resolve(__dirname, '../../Clarinet.toml');
    simnet = await initSimnet(manifestPath);
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    oracleAggregatorV2Contract = `${deployer}.${ORACLE_AGGREGATOR_V2_CONTRACT_NAME}`;
    mockCircuitBreakerContract = `${deployer}.${MOCK_CIRCUIT_BREAKER_CONTRACT_NAME}`;
  });

  it('ensures only the admin can set the circuit breaker', () => {
    // Non-admin attempts to set the circuit breaker
    let result = simnet.callPublicFn(
        ORACLE_AGGREGATOR_V2_CONTRACT_NAME,
        'set-circuit-breaker',
        [Cl.principal(mockCircuitBreakerContract)],
        wallet1
    );
    expect(result.result).toEqual(Cl.error(Cl.uint(1001))); // ERR_UNAUTHORIZED

    // Admin successfully sets the circuit breaker
    result = simnet.callPublicFn(
        ORACLE_AGGREGATOR_V2_CONTRACT_NAME,
        'set-circuit-breaker',
        [Cl.principal(mockCircuitBreakerContract)],
        deployer
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('correctly checks the status of the dynamic circuit breaker', () => {
    // Set the dynamic circuit breaker
    simnet.callPublicFn(
        ORACLE_AGGREGATOR_V2_CONTRACT_NAME,
        'set-circuit-breaker',
        [Cl.principal(mockCircuitBreakerContract)],
        deployer
    );

    // Check circuit breaker status (should be closed by default)
    let isCircuitOpen = simnet.callReadOnlyFn(
        ORACLE_AGGREGATOR_V2_CONTRACT_NAME,
        'check-circuit-breaker',
        [],
        deployer
    );
    expect(isCircuitOpen.result).toEqual(Cl.ok(Cl.bool(true)));

    // Trip the circuit breaker in the mock contract
    simnet.callPublicFn(
        MOCK_CIRCUIT_BREAKER_CONTRACT_NAME,
        'set-circuit-open',
        [Cl.bool(true)],
        deployer
    );

    // Check circuit breaker status again (should now be open)
    isCircuitOpen = simnet.callReadOnlyFn(
        ORACLE_AGGREGATOR_V2_CONTRACT_NAME,
        'check-circuit-breaker',
        [],
        deployer
    );
    expect(isCircuitOpen.result).toEqual(Cl.error(Cl.uint(1003))); // ERR_CIRCUIT_OPEN
  });
});
