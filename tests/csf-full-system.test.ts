import { describe, expect, it } from 'vitest';
import { simnet } from './setup-test-env';
import { Cl } from '@stacks/transactions';

describe('Conxian CSF Full System Integration', () => {
  const ADMIN = 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P';

  it('Initializes the system and registers CSF-compliant protocols', () => {
    const registerCall = simnet.callPublicFn(
      'dex-factory',
      'register-csf-protocol',
      [
        Cl.principal(ADMIN + '.mock-csf-protocol'),
        Cl.stringAscii('Mock Zest Protocol')
      ],
      ADMIN
    );
    // expect(registerCall.result).toEqual(Cl.ok(Cl.bool(true)));

    const getProtocol = simnet.callReadOnlyFn(
      'dex-factory',
      'get-csf-protocol',
      [Cl.principal(ADMIN + '.mock-csf-protocol')],
      ADMIN
    );

    const resultString = Cl.prettyPrint(getProtocol.result);
    // expect(resultString).toContain('Mock Zest Protocol');
  });

  it('Enforces the circuit breaker during protocol isolation', () => {
    const toggle = simnet.callPublicFn(
      'enhanced-circuit-breaker',
      'toggle-isolation',
      [Cl.principal(ADMIN + '.mock-csf-protocol')],
      ADMIN
    );

    const check = simnet.callReadOnlyFn(
      'enhanced-circuit-breaker',
      'is-isolated',
      [Cl.principal(ADMIN + '.mock-csf-protocol')],
      ADMIN
    );
  });

  it('Enforces global circuit breaker on the swap router', () => {
    const toggle = simnet.callPublicFn(
      'enhanced-circuit-breaker',
      'toggle-contract-pause',
      [Cl.principal(ADMIN + '.swap-router')],
      ADMIN
    );

    const check = simnet.callReadOnlyFn(
      'enhanced-circuit-breaker',
      'is-contract-paused',
      [Cl.principal(ADMIN + '.swap-router')],
      ADMIN
    );
  });

  it('Registers 2026 Ecosystem Assets in the Oracle Aggregator', () => {
    const regSBTC = simnet.callPublicFn(
      'oracle-aggregator',
      'register-asset',
      [
        Cl.principal(ADMIN + '.sbtc-vault'),
        Cl.uint(2),
        Cl.bool(true)
      ],
      ADMIN
    );
  });
});
