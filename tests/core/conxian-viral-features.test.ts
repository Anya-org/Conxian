import { describe, expect, it, beforeEach } from 'vitest';
import { initSimnet, Simnet } from '@stacks/clarinet-sdk';
import { Cl, principalToString, standardPrincipal, uint, principalCV, toHex, principalCV as toPrincipalCV } from '@stacks/transactions';
import { ec as EC } from 'elliptic';
import { sha256 } from 'js-sha256';

const TIER_SILVER = 1;
const TIER_GOLD = 2;

describe('Conxian Viral Features', () => {
  let simnet: Simnet;
  let deployer: string;
  let wallet1: string;
  let wallet2: string;
  let wallet3: string;
  let accessContract: string;
  let gatekeeperContract: string;
  let exitQueueContract: string;

  beforeEach(async () => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
    wallet3 = accounts.get('wallet_3')!;

    accessContract = simnet.deployContract('conxian-access', 'contracts/core/conxian-access.clar', null, deployer).contractAddress;
    gatekeeperContract = simnet.deployContract('conxian-gatekeeper', 'contracts/core/conxian-gatekeeper.clar', null, deployer).contractAddress;
    exitQueueContract = simnet.deployContract('conxian-exit-queue', 'contracts/core/conxian-exit-queue.clar', null, deployer).contractAddress;

    simnet.callPublicFn('conxian-access', 'add-authorized-caller', [Cl.principal(gatekeeperContract)], deployer);
    simnet.callPublicFn('conxian-gatekeeper', 'set-access-contract', [Cl.principal(accessContract)], deployer);
    simnet.callPublicFn('conxian-gatekeeper', 'set-oracle-principal', [Cl.principal(deployer)], deployer);
  });

  it('should not allow a non-Gold user to issue an invite', () => {
    simnet.callPublicFn('conxian-access', 'claim-genesis-spot', [], wallet1); // wallet1 is Silver

    const nonce = 1;
    const issuerTier = TIER_SILVER;
    const recipientPrincipal = principalCV(wallet2);
    const nonceBuff = Buffer.from(toHex(uint(nonce)).substring(2), 'hex');
    const tierBuff = Buffer.from(toHex(uint(issuerTier)).substring(2), 'hex');
    const recipientBuff = Buffer.from(toHex(recipientPrincipal).substring(2), 'hex');
    const combined = Buffer.concat([nonceBuff, tierBuff, recipientBuff]);
    const inviteHash = sha256.create().update(combined).digest();

    const ec = new EC('secp256k1');
    const inviteKey = ec.keyFromPrivate(simnet.getAccount(wallet1)!.privateKey.substring(2));
    const inviteSignature = inviteKey.sign(inviteHash, { canonical: true });
    const sigBuff = Buffer.concat([Buffer.from(inviteSignature.r.toArray()), Buffer.from(inviteSignature.s.toArray()), Buffer.from([inviteSignature.recoveryParam])]);

    const response = simnet.callPublicFn('conxian-access', 'claim-invite', [Cl.buffer(sigBuff), Cl.principal(wallet1), Cl.uint(nonce), Cl.uint(issuerTier)], wallet2);
    expect(response.result).toBeErr(Cl.uint(1004)); // ERR_ISSUER_NOT_GOLD
  });

  it('should prevent a replay attack on the gatekeeper', () => {
    simnet.callPublicFn('conxian-access', 'claim-genesis-spot', [], wallet1);

    const nonce = 1;
    const hash = sha256.create().update(Buffer.concat([Buffer.from(toHex(uint(nonce)).substring(2), 'hex'), Buffer.from(toHex(principalCV(wallet1)).substring(2), 'hex')])).digest();
    const ec = new EC('secp256k1');
    const key = ec.keyFromPrivate(simnet.getAccount(deployer)!.privateKey.substring(2));
    const signature = key.sign(hash, { canonical: true });
    const sigBuff = Buffer.concat([Buffer.from(signature.r.toArray()), Buffer.from(signature.s.toArray()), Buffer.from([signature.recoveryParam])]);

    let response = simnet.callPublicFn('conxian-gatekeeper', 'upgrade-to-gold', [Cl.buffer(sigBuff), Cl.uint(nonce)], wallet1);
    expect(response.result).toBeOk(Cl.bool(true));

    // Replay the same signature and nonce
    response = simnet.callPublicFn('conxian-gatekeeper', 'upgrade-to-gold', [Cl.buffer(sigBuff), Cl.uint(nonce)], wallet1);
    expect(response.result).toBeErr(Cl.uint(2004)); // ERR_NONCE_REPLAY
  });

  it('should allow a successful transfer and claim of an ExitTicket-NFT', () => {
    // wallet1 requests a fast exit and gets an NFT
    let response = simnet.callPublicFn('conxian-exit-queue', 'request-fast-exit', [Cl.uint(100)], wallet1);
    const ticketId = (response.result as any).value.value;
    expect(response.result).toBeOk(Cl.uint(0));

    // wallet1 transfers the NFT to wallet2
    response = simnet.callPublicFn('conxian-exit-queue', 'transfer', [Cl.uint(ticketId), Cl.principal(wallet1), Cl.principal(wallet2)], wallet1);
    expect(response.result).toBeOk(Cl.bool(true));

    // wallet2 claims the completed exit
    response = simnet.callPublicFn('conxian-exit-queue', 'claim-completed-exit', [Cl.uint(ticketId)], wallet2);
    expect(response.result).toBeOk(Cl.bool(true));
  });

  it('should return the correct reward multiplier for a Gold user', () => {
    simnet.callPublicFn('conxian-access', 'claim-genesis-spot', [], wallet1);
    const nonce = 1;
    const hash = sha256.create().update(Buffer.concat([Buffer.from(toHex(uint(nonce)).substring(2), 'hex'), Buffer.from(toHex(principalCV(wallet1)).substring(2), 'hex')])).digest();
    const ec = new EC('secp256k1');
    const key = ec.keyFromPrivate(simnet.getAccount(deployer)!.privateKey.substring(2));
    const signature = key.sign(hash, { canonical: true });
    const sigBuff = Buffer.concat([Buffer.from(signature.r.toArray()), Buffer.from(signature.s.toArray()), Buffer.from([signature.recoveryParam])]);
    simnet.callPublicFn('conxian-gatekeeper', 'upgrade-to-gold', [Cl.buffer(sigBuff), Cl.uint(nonce)], wallet1);

    simnet.callPublicFn('rewards', 'set-launch-block', [], deployer);
    let response = simnet.callReadOnlyFn('rewards', 'get-reward-multiplier', [Cl.principal(wallet1)], deployer);
    expect(response.result).toBeOk(Cl.uint(250));

    simnet.mineEmptyBlocks(4320);

    response = simnet.callReadOnlyFn('rewards', 'get-reward-multiplier', [Cl.principal(wallet1)], deployer);
    expect(response.result).toBeOk(Cl.uint(150));
  });

  it('should enforce the TVL cap', () => {
    simnet.callPublicFn('conxian-access', 'claim-genesis-spot', [], wallet1);
    const sbtcTokenContract = simnet.deployContract('sbtc-token', 'contracts/mocks/mock-token.clar', null, deployer).contractAddress;
    simnet.deployContract('custody', 'contracts/vaults/custody.clar', null, deployer);
    simnet.deployContract('launch-limits', 'contracts/config/launch-limits.clar', null, deployer);
    const vault = simnet.deployContract('sbtc-vault', 'contracts/vaults/sbtc-vault.clar', null, deployer);
    simnet.callPublicFn('sbtc-vault', 'set-custody-contract', [Cl.principal(vault.contractAddress)], deployer);
    simnet.callPublicFn('sbtc-vault', 'set-sbtc-token-contract', [Cl.principal(sbtcTokenContract)], deployer);


    let response = simnet.callPublicFn('sbtc-vault', 'deposit', [Cl.contractPrincipal(sbtcTokenContract), Cl.uint(500000001)], wallet1);
    expect(response.result).toBeErr(Cl.uint(5002));
  });
});
