import { describe, expect, it } from 'vitest';
import { simnet } from './setup-test-env';
import { Cl } from '@stacks/transactions';

describe('Conxian CSF Full System Integration', () => {
  it('Initializes the system and registers CSF-compliant protocols', () => {
    const accounts = simnet.getAccounts();
    const DEPLOYER = accounts.get('deployer')!;

    // Get the actual admin address from the contract
    const adminRes = simnet.callReadOnlyFn('conxian-protocol', 'get-protocol-admin', [], DEPLOYER);
    const ADMIN = (adminRes.result as any).value;
    console.log('ACTUAL ADMIN:', ADMIN);

    // Register Mock Protocol in the CSF Registry
    const registerCall = simnet.callPublicFn(
      'dex-factory',
      'register-csf-protocol',
      [
        Cl.principal(`${DEPLOYER}.mock-csf-protocol`),
        Cl.stringAscii('Mock Zest Protocol')
      ],
      ADMIN
    );
    expect(registerCall.result).toEqual(Cl.ok(Cl.bool(true)));

    // Verify registration
    const getCall = simnet.callReadOnlyFn(
      'dex-factory',
      'get-csf-protocol',
      [Cl.principal(`${DEPLOYER}.mock-csf-protocol`)],
      ADMIN
    );

    const result: any = getCall.result;
    expect(result.type).toBe('ok');
    expect(result.value.type).toBe('some');
  });

  it('Executes a CSF swap through the Universal Router', () => {
    const accounts = simnet.getAccounts();
    const DEPLOYER = accounts.get('deployer')!;
    const USER = accounts.get('wallet_1')!;
    const adminRes = simnet.callReadOnlyFn('conxian-protocol', 'get-protocol-admin', [], DEPLOYER);
    const ADMIN = (adminRes.result as any).value;

    // Setup: authorize mock protocol to report fees
    simnet.callPublicFn('bme-engine', 'add-activity-reporter', [Cl.principal(`${DEPLOYER}.mock-csf-protocol`)], ADMIN);

    // Perform a CSF swap using the mock protocol
    const swapCall = simnet.callPublicFn(
      'swap-router',
      'csf-swap',
      [
        Cl.principal(`${DEPLOYER}.mock-csf-protocol`),
        Cl.principal(`${DEPLOYER}.mock-token`),
        Cl.principal(`${DEPLOYER}.cxd-token`),
        Cl.uint(1000000), // amount-in
        Cl.uint(900000)   // min-amount-out
      ],
      USER
    );

    expect(swapCall.result).toEqual(Cl.ok(Cl.uint(1000000)));
  });

  it('Enforces the circuit breaker during protocol isolation', () => {
    const accounts = simnet.getAccounts();
    const DEPLOYER = accounts.get('deployer')!;
    const USER = accounts.get('wallet_1')!;
    const adminRes = simnet.callReadOnlyFn('conxian-protocol', 'get-protocol-admin', [], DEPLOYER);
    const ADMIN = (adminRes.result as any).value;

    // Isolate the mock protocol
    const isolateCall = simnet.callPublicFn(
      'enhanced-circuit-breaker',
      'toggle-isolation',
      [Cl.principal(`${DEPLOYER}.mock-csf-protocol`)],
      ADMIN
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
      USER
    );

    expect(swapCall.result).toEqual(Cl.error(Cl.uint(504)));
  });

  it('Enforces global circuit breaker on the swap router', () => {
    const accounts = simnet.getAccounts();
    const DEPLOYER = accounts.get('deployer')!;
    const USER = accounts.get('wallet_1')!;
    const adminRes = simnet.callReadOnlyFn('conxian-protocol', 'get-protocol-admin', [], DEPLOYER);
    const ADMIN = (adminRes.result as any).value;

    // Globally pause the protocol
    const pauseCall = simnet.callPublicFn(
      'enhanced-circuit-breaker',
      'toggle-global-pause',
      [],
      ADMIN
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
      USER
    );

    expect(swapCall.result).toEqual(Cl.error(Cl.uint(503)));
  });

  it('Registers 2026 Ecosystem Assets in the Oracle Aggregator', () => {
    const accounts = simnet.getAccounts();
    const DEPLOYER = accounts.get('deployer')!;
    const adminRes = simnet.callReadOnlyFn('conxian-protocol', 'get-protocol-admin', [], DEPLOYER);
    const ADMIN = (adminRes.result as any).value;

    const sBTC = `${DEPLOYER}.mock-token`;

    const regSBTC = simnet.callPublicFn(
      'oracle-aggregator',
      'register-asset',
      [Cl.principal(sBTC), Cl.uint(1), Cl.bool(false)],
      ADMIN
    );
    expect(regSBTC.result).toEqual(Cl.ok(Cl.bool(true)));
  });
});
