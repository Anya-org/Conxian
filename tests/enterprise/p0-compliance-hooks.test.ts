import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from "@stacks/clarinet-sdk";
import { resolve } from "path";

const COMPLIANCE_HOOKS_CONTRACT_NAME = 'compliance-hooks';
const KYC_REGISTRY_CONTRACT_NAME = 'kyc-registry';

describe('P0 Policy Enforcement Bypass Mitigation Tests', () => {
  let simnet: any;
  let deployer: any;
  let wallet1: any;
  let complianceHooksContract: any;
  let kycRegistryContract: any;

  beforeEach(async () => {
    const manifestPath = resolve(__dirname, '../../Clarinet.toml');
    simnet = await initSimnet(manifestPath);
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    complianceHooksContract = `${deployer}.${COMPLIANCE_HOOKS_CONTRACT_NAME}`;
    kycRegistryContract = `${deployer}.${KYC_REGISTRY_CONTRACT_NAME}`;
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

  it('blocks a non-KYC-verified user', () => {
    // Check KYC status (user has no KYC status)
    const result = simnet.callReadOnlyFn(
        COMPLIANCE_HOOKS_CONTRACT_NAME,
        'check-kyc',
        [Cl.principal(wallet1)],
        wallet1
    );
    expect(result.result).toEqual(Cl.error(Cl.uint(7000))); // ERR_UNAUTHORIZED
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
    expect(result.result).toEqual(Cl.error(Cl.uint(7000))); // ERR_UNAUTHORIZED
  });
});
