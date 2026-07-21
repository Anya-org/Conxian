import { describe, it, expect, beforeEach } from 'vitest';
import { Cl } from '@stacks/transactions';
import { simnet } from '../setup-test-env';
import { ec as EC } from 'elliptic';

describe('Regulatory Adapter SIP-018 Tests', () => {
    let accounts: any;
  let deployer: string;
  let wallet1: string;

  beforeEach(async () => {

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

    expect(verifyRes.result).toStrictEqual(Cl.error(Cl.uint(6003))); // ERR_UNAUTHORIZED
  });

  it('should successfully verify a valid signature', () => {
    const user = Cl.principal(wallet1);
    const jurisdiction = "USA";
    const tier = 1;

    // 0. Register the user's principal hash first
    const crypto = require('crypto');
    const userHash = crypto.createHash('sha256').update(wallet1).digest();

    simnet.callPublicFn('regulatory-adapter', 'register-user-hash', [
      user,
      Cl.buffer(userHash)
    ], deployer);

    // 1. Get the real SIP-018 hash from the contract
    const hashRes = simnet.callReadOnlyFn('regulatory-adapter', 'get-sip018-hash', [
      user,
      Cl.stringAscii(jurisdiction),
      Cl.uint(tier)
    ], deployer);

    // Extract the hash value (which is a buffer)
    const hashHex = (hashRes.result as any).value.value;
    const hashBytes = Buffer.from(hashHex.startsWith('0x') ? hashHex.slice(2) : hashHex, 'hex');

    // 2. Generate a random secp256k1 keypair on-the-fly
    const ec = new EC('secp256k1');
    const key = ec.genKeyPair();

    // Sign with canonical: true
    const signatureObj = key.sign(hashBytes, { canonical: true });

    // Construct the RSV signature buffer (65 bytes)
    const r = Buffer.from(signatureObj.r.toArray('be', 32));
    const s = Buffer.from(signatureObj.s.toArray('be', 32));
    const v = Buffer.from([signatureObj.recoveryParam]);
    const sigBuff = Buffer.concat([r, s, v]);

    // 3. Set our generated public key as the authority public key
    const pubkeyHex = key.getPublic(true, 'hex'); // Compressed public key (33 bytes)
    const pubkeyBuff = Buffer.from(pubkeyHex, 'hex');

    simnet.callPublicFn('regulatory-adapter', 'update-authority', [
      Cl.principal(deployer),
      Cl.buffer(pubkeyBuff)
    ], deployer);

    // 4. Verify and update compliance
    const verifyRes = simnet.callPublicFn('regulatory-adapter', 'verify-and-update-compliance', [
      user,
      Cl.stringAscii(jurisdiction),
      Cl.uint(tier),
      Cl.buffer(sigBuff)
    ], deployer);

    // Ensure it was successful
    expect(verifyRes.result).toStrictEqual(Cl.ok(Cl.bool(true)));

    // 5. Verify the user is now marked as compliant
    const complianceRes = simnet.callPublicFn('regulatory-adapter', 'check-clean-hands-compliance', [
      user
    ], deployer);
    expect(complianceRes.result).toStrictEqual(Cl.ok(Cl.bool(true)));
  });
});
