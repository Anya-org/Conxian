import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';
const COMPLIANCE_HOOKS_CONTRACT_NAME = 'compliance-hooks';
const KYC_REGISTRY_CONTRACT_NAME = 'kyc-registry';
const ERR_POLICY_VIOLATION = 7000;

describe('P0 Policy Enforcement Bypass Mitigation Tests', () => {
    let deployer: any;
  let wallet1: any;
  let untouchedWallet: any;

  beforeEach(() => {

    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    untouchedWallet = accounts.get('wallet_2')!;
  });

  it('allows a KYC-verified user', () => {
    // Set user's KYC tier to 1 (Basic)
    simnet.callPublicFn(
        KYC_REGISTRY_CONTRACT_NAME,
        'set-identity-status',
        [Cl.principal(wallet1), Cl.uint(1), Cl.uint(0), Cl.stringAscii("USA")],
        deployer
    );

    // Check KYC status
    const result = simnet.callReadOnlyFn(
        COMPLIANCE_HOOKS_CONTRACT_NAME,
        'check-kyc',
        [Cl.principal(wallet1)],
        wallet1
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('blocks a user without a KYC record', () => {
    // wallet_2 is not mutated by this suite, so this exercises the actual
    // missing-record path rather than inheriting wallet_1's prior setup.
    const hasRecord = simnet.callReadOnlyFn(
        KYC_REGISTRY_CONTRACT_NAME,
        'has-identity-status',
        [Cl.principal(untouchedWallet)],
        untouchedWallet
    );
    expect(hasRecord.result).toEqual(Cl.bool(false));

    const result = simnet.callReadOnlyFn(
        COMPLIANCE_HOOKS_CONTRACT_NAME,
        'check-kyc',
        [Cl.principal(untouchedWallet)],
        untouchedWallet
    );
    // compliance-hooks names the missing/insufficient-KYC error
    // ERR_POLICY_VIOLATION (u7000).
    expect(result.result).toEqual(Cl.error(Cl.uint(ERR_POLICY_VIOLATION)));
  });

  it('allows a non-sanctioned user', () => {
    // Set user's KYC tier to 1 (Basic) and flags to 0 (not sanctioned)
    simnet.callPublicFn(
        KYC_REGISTRY_CONTRACT_NAME,
        'set-identity-status',
        [Cl.principal(wallet1), Cl.uint(1), Cl.uint(0), Cl.stringAscii("USA")],
        deployer
    );

    // Check AML status
    const result = simnet.callReadOnlyFn(
        COMPLIANCE_HOOKS_CONTRACT_NAME,
        'check-aml',
        [Cl.principal(wallet1)],
        wallet1
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('blocks a sanctioned user', () => {
    // Set user's KYC tier to 1 (Basic) and flags to 2 (sanctioned)
    simnet.callPublicFn(
        KYC_REGISTRY_CONTRACT_NAME,
        'set-identity-status',
        [Cl.principal(wallet1), Cl.uint(1), Cl.uint(2), Cl.stringAscii("USA")],
        deployer
    );

    // Check AML status
    const result = simnet.callReadOnlyFn(
        COMPLIANCE_HOOKS_CONTRACT_NAME,
        'check-aml',
        [Cl.principal(wallet1)],
        wallet1
    );
    expect(result.result).toEqual(Cl.error(Cl.uint(ERR_POLICY_VIOLATION)));
  });
});
