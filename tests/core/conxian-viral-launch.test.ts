import { describe, expect, it, beforeEach } from 'vitest';
import { initSimnet, Simnet } from '@stacks/clarinet-sdk';
import { Cl, principalToString, standardPrincipal, uint, principalCV, toHex, principalCV as toPrincipalCV } from '@stacks/transactions';
import { ec as EC } from 'elliptic';
import { sha256 } from 'js-sha256';

const GENESIS_CAP = 1000;
const TIER_SILVER = 1;
const TIER_GOLD = 2;

describe('Conxian Viral Launch System', () => {
  let simnet: Simnet;
  let deployer: string;
  let wallet1: string;
  let wallet2: string;

  beforeEach(async () => {
    simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;

    simnet.deployContract('conxian-access', 'contracts/core/conxian-access.clar', null, deployer);
    const gatekeeperDeploy = simnet.deployContract('conxian-gatekeeper', 'contracts/core/conxian-gatekeeper.clar', null, deployer);

    simnet.callPublicFn('conxian-access', 'add-authorized-caller', [Cl.principal(gatekeeperDeploy.contractAddress)], deployer);
  });

  describe('Conxian Access Contract', () => {
    it('should allow a user to claim a genesis spot', () => {
        const response = simnet.callPublicFn('conxian-access', 'claim-genesis-spot', [], wallet1);
        expect(response.result).toBeOk(Cl.bool(true));

        const userTier = simnet.callReadOnlyFn('conxian-access', 'get-user-tier', [Cl.principal(wallet1)], deployer);
        expect(userTier.result).toBeUint(TIER_SILVER);
    });

    it('should securely process an invite', async () => {
        simnet.callPublicFn('conxian-access', 'claim-genesis-spot', [], wallet1);
        simnet.callPublicFn('conxian-gatekeeper', 'set-oracle-principal', [Cl.principal(deployer)], deployer);

        const hash = sha256.create().update(wallet1).digest();
        const ec = new EC('secp256k1');
        const key = ec.keyFromPrivate(simnet.getAccount(deployer)!.privateKey.substring(2));
        const signature = key.sign(hash, { canonical: true });
        let sigBuff = Buffer.concat([Buffer.from(signature.r.toArray()), Buffer.from(signature.s.toArray()), Buffer.from([signature.recoveryParam])]);

        simnet.callPublicFn('conxian-gatekeeper', 'upgrade-to-gold', [Cl.buffer(sigBuff)], wallet1);

        const nonce = 1;
        const recipientPrincipal = principalCV(wallet2);
        const nonceBuff = Buffer.from(toHex(uint(nonce)).substring(2), 'hex');
        const recipientBuff = Buffer.from(toHex(recipientPrincipal).substring(2), 'hex');
        const combined = Buffer.concat([nonceBuff, recipientBuff]);
        const inviteHash = sha256.create().update(combined).digest();

        const inviteKey = ec.keyFromPrivate(simnet.getAccount(wallet1)!.privateKey.substring(2));
        const inviteSignature = inviteKey.sign(inviteHash, { canonical: true });
        sigBuff = Buffer.concat([Buffer.from(inviteSignature.r.toArray()), Buffer.from(inviteSignature.s.toArray()), Buffer.from([inviteSignature.recoveryParam])]);

        const response = simnet.callPublicFn('conxian-access', 'claim-invite', [Cl.buffer(sigBuff), Cl.principal(wallet1), Cl.uint(nonce)], wallet2);
        expect(response.result).toBeOk(Cl.bool(true));
        const userTier = simnet.callReadOnlyFn('conxian-access', 'get-user-tier', [Cl.principal(wallet2)], deployer);
        expect(userTier.result).toBeUint(TIER_SILVER);
    });
  });
});
