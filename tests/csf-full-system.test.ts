import { describe, expect, it } from 'vitest';
import { simnet } from './setup-test-env';
import { Cl } from '@stacks/transactions';

describe('Conxian CSF Full System Integration', () => {
  it('Initializes the system and registers CSF-compliant protocols', () => {
    const accounts = simnet.getAccounts();
    const DEPLOYER = accounts.get('deployer')!;

    // 1. Claim ownership of conxian-protocol
    simnet.callPublicFn('conxian-protocol', 'set-owner', [Cl.principal(DEPLOYER)], DEPLOYER);

    // Register Mock Protocol in the CSF Registry
    const registerCall = simnet.callPublicFn(
      'dex-factory',
      'register-csf-protocol',
      [
        Cl.principal(`${DEPLOYER}.mock-csf-protocol`),
        Cl.stringAscii('Mock Zest Protocol')
      ],
      DEPLOYER
    );
    expect(registerCall.result).toEqual(Cl.ok(Cl.bool(true)));

    // Verify registration
    const getProtocol = simnet.callReadOnlyFn(
      'dex-factory',
      'get-csf-protocol',
      [Cl.principal(`${DEPLOYER}.mock-csf-protocol`)],
      DEPLOYER
    );

    // Check if the result is (ok (some ...)) and contains the correct name
    const resultString = Cl.prettyPrint(getProtocol.result);
    expect(resultString).toContain('Mock Zest Protocol');
    expect(resultString).toContain('active: true');
  });

  it('Executes a CSF swap through the Universal Router', () => {
    const accounts = simnet.getAccounts();
    const DEPLOYER = accounts.get('deployer')!;
    const USER1 = accounts.get('wallet_1')!;

    // Perform a CSF swap using the mock protocol
    const swapCall = simnet.callPublicFn(
      'swap-router',
      'csf-swap',
      [
        Cl.principal(`${DEPLOYER}.mock-csf-protocol`),
        Cl.principal(`${DEPLOYER}.mock-token`),
        Cl.principal(`${DEPLOYER}.cxd-token`),
        Cl.uint(1000000),
        Cl.uint(900000)
      ],
      USER1
    );

    expect(swapCall.result).toEqual(Cl.ok(Cl.uint(1000000)));
  });

  it('Enforces the circuit breaker during protocol isolation', () => {
    const accounts = simnet.getAccounts();
    const DEPLOYER = accounts.get('deployer')!;
    const USER1 = accounts.get('wallet_1')!;

    // Isolate the mock protocol via the enhanced circuit breaker
    const isolateCall = simnet.callPublicFn(
      'enhanced-circuit-breaker',
      'toggle-isolation',
      [Cl.principal(`${DEPLOYER}.mock-csf-protocol`)],
      DEPLOYER
    );
    expect(isolateCall.result).toEqual(Cl.ok(Cl.bool(true)));

    // Attempt swap with isolated source - should fail with ERR_SOURCE_ISOLATED (u504)
    const swapCall = simnet.callPublicFn(
      'swap-router',
      'csf-swap',
      [
        Cl.principal(`${DEPLOYER}.mock-csf-protocol`),
        Cl.principal(`${DEPLOYER}.mock-token`),
        Cl.principal(`${DEPLOYER}.cxd-token`),
        Cl.uint(1000000),
        Cl.uint(900000)
      ],
      USER1
    );
    expect(swapCall.result).toEqual(Cl.error(Cl.uint(504)));

    // De-isolate protocol
    simnet.callPublicFn(
      'enhanced-circuit-breaker',
      'toggle-isolation',
      [Cl.principal(`${DEPLOYER}.mock-csf-protocol`)],
      DEPLOYER
    );
  });

  it('Enforces global circuit breaker on the swap router', () => {
    const accounts = simnet.getAccounts();
    const DEPLOYER = accounts.get('deployer')!;
    const USER1 = accounts.get('wallet_1')!;

    // Pause the swap-router contract
    const pauseCall = simnet.callPublicFn(
      'enhanced-circuit-breaker',
      'toggle-contract-pause',
      [Cl.principal(`${DEPLOYER}.swap-router`)],
      DEPLOYER
    );
    expect(pauseCall.result).toEqual(Cl.ok(Cl.bool(true)));

    // Attempt swap - should fail with ERR_PROTOCOL_PAUSED (u503)
    const swapCall = simnet.callPublicFn(
      'swap-router',
      'csf-swap',
      [
        Cl.principal(`${DEPLOYER}.mock-csf-protocol`),
        Cl.principal(`${DEPLOYER}.mock-token`),
        Cl.principal(`${DEPLOYER}.cxd-token`),
        Cl.uint(1000000),
        Cl.uint(900000)
      ],
      USER1
    );
    expect(swapCall.result).toEqual(Cl.error(Cl.uint(503)));
  });

  it('Registers 2026 Ecosystem Assets in the Oracle Aggregator', () => {
    const accounts = simnet.getAccounts();
    const DEPLOYER = accounts.get('deployer')!;

    // Ensure owner is set
    simnet.callPublicFn('conxian-protocol', 'set-owner', [Cl.principal(DEPLOYER)], DEPLOYER);

    // Register sBTC and stSTX
    const regSBTC = simnet.callPublicFn(
      'oracle-aggregator',
      'register-asset',
      [Cl.principal(`${DEPLOYER}.mock-token`), Cl.uint(1), Cl.bool(false)],
      DEPLOYER
    );
    expect(regSBTC.result).toEqual(Cl.ok(Cl.bool(true)));

    const info = simnet.callReadOnlyFn(
      'oracle-aggregator',
      'get-asset-info',
      [Cl.principal(`${DEPLOYER}.mock-token`)],
      DEPLOYER
    );
    expect(Cl.prettyPrint(info.result)).toContain('tier: u1');
  });
});
