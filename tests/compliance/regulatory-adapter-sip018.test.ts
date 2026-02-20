import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@stacks/clarinet-sdk';

describe('Regulatory Adapter SIP-018 Tests', () => {
  let simnet: any;
  let accounts: any;
  let deployer: string;
  let wallet1: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
  });

  it('should correctly calculate the SIP-018 hash', () => {
    const user = Cl.principal(wallet1);
    const jurisdiction = "USA";
    const tier = 1;

    const hashRes = simnet.callReadOnlyFn('regulatory-adapter', 'get-sip018-hash', [
      user,
      Cl.stringAscii(jurisdiction),
      Cl.uint(tier)
    ], deployer);

    expect(hashRes.result).toBeDefined();
  });

  it('should fail verification with invalid signature', () => {
    const user = Cl.principal(wallet1);
    const jurisdiction = "USA";
    const tier = 1;
    const invalidSig = '0x' + '00'.repeat(65);

    // Set authority pubkey first
    const authorityPubkey = '0x02' + '01'.repeat(32); // Mock pubkey
    simnet.callPublicFn('regulatory-adapter', 'update-authority', [
      Cl.principal(deployer),
      Cl.buffer(Buffer.from(authorityPubkey.slice(2), 'hex'))
    ], deployer);

    const verifyRes = simnet.callPublicFn('regulatory-adapter', 'verify-and-update-compliance', [
      user,
      Cl.stringAscii(jurisdiction),
      Cl.uint(tier),
      Cl.buffer(Buffer.from(invalidSig.slice(2), 'hex'))
    ], deployer);

    expect(verifyRes.result).toStrictEqual(Cl.error(Cl.uint(6003))); // ERR_INVALID_SIGNATURE
  });

  it('should fail verification if authority pubkey is not set', () => {
    const user = Cl.principal(wallet1);
    const jurisdiction = "USA";
    const tier = 1;
    const dummySig = '0x' + '00'.repeat(65);

    const verifyRes = simnet.callPublicFn('regulatory-adapter', 'verify-and-update-compliance', [
      user,
      Cl.stringAscii(jurisdiction),
      Cl.uint(tier),
      Cl.buffer(Buffer.from(dummySig.slice(2), 'hex'))
    ], deployer);

    expect(verifyRes.result).toStrictEqual(Cl.error(Cl.uint(6000))); // ERR_UNAUTHORIZED
  });
});
