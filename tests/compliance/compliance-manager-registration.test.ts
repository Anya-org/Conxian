import { beforeAll, describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';

const COMPLIANCE_MANAGER = 'compliance-manager';
const COMPLIANCE_HOOKS = 'compliance-hooks';
const KYC_REGISTRY = 'kyc-registry';
const VALIDITY_PERIOD = 144;
const UNAUTHORIZED = 3000;
const INVALID_MINIMUM_KYC_LEVEL = 3003;

describe('Canonical registration compliance gate', () => {
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;

  beforeAll(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
    wallet3 = accounts.get('wallet_3')!;
  });

  const setCompliance = (user: string, clean: boolean, kycLevel: number, sender = deployer) => simnet.callPublicFn(
    COMPLIANCE_MANAGER,
    'check-user-compliance',
    [Cl.principal(user), Cl.bool(clean), Cl.uint(kycLevel), Cl.bool(false)],
    sender,
  );

  const setKycStatus = (user: string, tier: number, flags: number) => {
    const result = simnet.callPublicFn(
      KYC_REGISTRY,
      'set-identity-status',
      [Cl.principal(user), Cl.uint(tier), Cl.uint(flags), Cl.stringAscii('USA')],
      deployer,
    );
    expect(result.result).toEqual(Cl.ok(Cl.bool(true)));
  };

  const registrationGate = (user: string, minimumKycLevel: number) => simnet.callReadOnlyFn(
    COMPLIANCE_MANAGER,
    'is-registration-compliant',
    [Cl.principal(user), Cl.uint(minimumKycLevel)],
    deployer,
  ).result;

  it('separates ordinary record writers from positive sanctions attestations', () => {
    expect(simnet.callPublicFn(COMPLIANCE_MANAGER, 'register-provider', [Cl.principal(wallet2)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));
    expect(simnet.callPublicFn(COMPLIANCE_MANAGER, 'set-sanctions-provider', [Cl.principal(wallet3)], wallet1).result)
      .toEqual(Cl.error(Cl.uint(UNAUTHORIZED)));
    expect(simnet.callPublicFn(COMPLIANCE_MANAGER, 'set-sanctions-provider', [Cl.principal(wallet3)], deployer).result)
      .toEqual(Cl.ok(Cl.bool(true)));

    // The owner and an approved provider can both preserve the normal KYC
    // update path by writing a non-positive/unknown sanctions result.
    expect(setCompliance(wallet1, false, 1).result).toEqual(Cl.ok(Cl.bool(true)));
    expect(setCompliance(wallet1, false, 2, wallet2).result).toEqual(Cl.ok(Cl.bool(true)));

    // A positive clean-screen result is no longer writable by every approved
    // provider or by the owner after a distinct sanctions provider is set.
    expect(setCompliance(wallet1, true, 2, wallet2).result)
      .toEqual(Cl.error(Cl.uint(UNAUTHORIZED)));
    expect(setCompliance(wallet1, true, 2).result)
      .toEqual(Cl.error(Cl.uint(UNAUTHORIZED)));
    expect(setCompliance(wallet1, true, 2, wallet1).result)
      .toEqual(Cl.error(Cl.uint(UNAUTHORIZED)));

    // The configured sanctions provider may write the positive attestation
    // without also being registered as a general-purpose provider.
    expect(setCompliance(wallet1, true, 2, wallet3).result).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('requires a fresh manager record and an existing authoritative KYC record', () => {
    setCompliance(wallet1, false, 1);
    expect(simnet.callReadOnlyFn(KYC_REGISTRY, 'has-identity-status', [Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.bool(false));
    expect(registrationGate(wallet1, 1)).toEqual(Cl.ok(Cl.bool(false)));

    setKycStatus(wallet1, 1, 0);
    expect(simnet.callReadOnlyFn(KYC_REGISTRY, 'has-identity-status', [Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.bool(true));
    // The legacy manager boolean is false, but the authoritative registry is
    // clean, so a fresh record at the required tier is eligible.
    expect(registrationGate(wallet1, 1)).toEqual(Cl.ok(Cl.bool(true)));

    setCompliance(wallet1, false, 2);
    expect(registrationGate(wallet1, 2)).toEqual(Cl.ok(Cl.bool(false)));

    setKycStatus(wallet1, 1, 0);
    expect(registrationGate(wallet1, 2)).toEqual(Cl.ok(Cl.bool(false)));
    setKycStatus(wallet1, 2, 0);
    expect(registrationGate(wallet1, 2)).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('fails closed for missing, low, malformed, and sanctioned registry evidence', () => {
    setCompliance(wallet2, true, 3, wallet3);
    expect(registrationGate(wallet2, 1)).toEqual(Cl.ok(Cl.bool(false)));

    setKycStatus(wallet2, 0, 0);
    expect(registrationGate(wallet2, 1)).toEqual(Cl.ok(Cl.bool(false)));

    setKycStatus(wallet2, 4, 0);
    expect(registrationGate(wallet2, 1)).toEqual(Cl.ok(Cl.bool(false)));

    setKycStatus(wallet2, 3, 2);
    expect(registrationGate(wallet2, 1)).toEqual(Cl.ok(Cl.bool(false)));

    setKycStatus(wallet2, 3, 0);
    expect(registrationGate(wallet2, 1)).toEqual(Cl.ok(Cl.bool(true)));
  });

  it('accepts the inclusive freshness boundary and rejects the next burn block', () => {
    setCompliance(wallet3, false, 1);
    setKycStatus(wallet3, 1, 0);

    simnet.mineEmptyBlocks(VALIDITY_PERIOD);
    expect(registrationGate(wallet3, 1)).toEqual(Cl.ok(Cl.bool(true)));

    simnet.mineEmptyBlocks(1);
    expect(registrationGate(wallet3, 1)).toEqual(Cl.ok(Cl.bool(false)));
  });

  it('rejects invalid minimum configuration and out-of-range stored tiers', () => {
    setCompliance(wallet3, false, 0);
    setKycStatus(wallet3, 1, 0);
    expect(registrationGate(wallet3, 1)).toEqual(Cl.ok(Cl.bool(false)));

    setCompliance(wallet3, false, 4);
    setKycStatus(wallet3, 4, 0);
    expect(registrationGate(wallet3, 1)).toEqual(Cl.ok(Cl.bool(false)));

    expect(registrationGate(wallet3, 0)).toEqual(Cl.error(Cl.uint(INVALID_MINIMUM_KYC_LEVEL)));
    expect(registrationGate(wallet3, 4)).toEqual(Cl.error(Cl.uint(INVALID_MINIMUM_KYC_LEVEL)));
  });

  it('integrates with compliance-hooks.verify-kyc without treating its false flag as a clean screen', () => {
    expect(simnet.callPublicFn(
      COMPLIANCE_HOOKS,
      'add-kyc-provider',
      [Cl.principal(wallet1), Cl.stringAscii('unlinked KYC provider')],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));
    // The hook's manager error is propagated as a response rather than
    // causing the old unwrap-panic path to abort interpretation.
    expect(simnet.callPublicFn(
      COMPLIANCE_HOOKS,
      'verify-kyc',
      [Cl.principal(wallet3), Cl.uint(1)],
      wallet1,
    ).result).toEqual(Cl.error(Cl.uint(UNAUTHORIZED)));

    expect(simnet.callPublicFn(
      COMPLIANCE_HOOKS,
      'add-kyc-provider',
      [Cl.principal(wallet2), Cl.stringAscii('approved KYC provider')],
      deployer,
    ).result).toEqual(Cl.ok(Cl.bool(true)));

    const verification = simnet.callPublicFn(
      COMPLIANCE_HOOKS,
      'verify-kyc',
      [Cl.principal(wallet3), Cl.uint(1)],
      wallet2,
    );
    expect(verification.result).toEqual(Cl.ok(Cl.bool(true)));

    // verify-kyc updates the fresh manager record but does not manufacture an
    // authoritative registry record, so the registration gate fails closed.
    expect(registrationGate(wallet3, 1)).toEqual(Cl.ok(Cl.bool(false)));

    setKycStatus(wallet3, 1, 0);
    // The hook intentionally writes sanctions-checked=false. Registry-owned
    // clean status is the evidence used by the registration gate.
    expect(registrationGate(wallet3, 1)).toEqual(Cl.ok(Cl.bool(true)));

    setKycStatus(wallet3, 1, 2);
    expect(registrationGate(wallet3, 1)).toEqual(Cl.ok(Cl.bool(false)));
  });

  it('preserves legacy compliance behavior for fresh records', () => {
    setCompliance(wallet1, false, 2);

    expect(simnet.callReadOnlyFn(COMPLIANCE_MANAGER, 'is-compliant', [Cl.principal(wallet1)], deployer).result)
      .toEqual(Cl.bool(false));
    expect(simnet.callPublicFn(COMPLIANCE_MANAGER, 'check-kyc-compliance', [Cl.principal(wallet1)], wallet1).result)
      .toEqual(Cl.ok(Cl.bool(true)));
  });
});
