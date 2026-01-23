import { signNative, getPublicKeyNative } from './enclave-storage';
import { Network } from '../types';
import * as bitcoin from 'bitcoinjs-lib';

export interface ConxiusIdentity {
  did: string; // did:pkh:btc:mainnet:<address>
  address: string;
  publicKey: string;
}

/**
 * Conxius Identity Service (D.ID)
 * Uses the Secure Enclave as a Hardware Authenticator.
 */
export class IdentityService {
  private network: string;
  private vaultName: string;
  private static cache: Map<string, ConxiusIdentity> = new Map();

  constructor(vaultName: string = 'primary_vault', network: Network = 'mainnet') {
     this.vaultName = vaultName;
     this.network = network;
  }

  /**
   * Retrieves the Decentralized Identifier (DID) for the current vault.
   * Format: did:pkh:btc:<chain_id>:<address>
   * Current implementation uses the Bitcoin Mainnet/Testnet address as the anchor.
   */
  async getDid(): Promise<ConxiusIdentity> {
     const cacheKey = `${this.vaultName}:${this.network}`;
     if (IdentityService.cache.has(cacheKey)) {
         return IdentityService.cache.get(cacheKey)!;
     }

     // Path: m/84'/0'/0'/0/0 (Standard Native Segwit)
     const path = this.network === 'mainnet' ? "m/84'/0'/0'/0/0" : "m/84'/1'/0'/0/0";
     
     try {
         let pubkey: string;
         try {
            // Optimization: Try to get public key directly without signing
            const res = await getPublicKeyNative({
                vault: this.vaultName,
                path,
                network: this.network
            });
            pubkey = res.pubkey;
         } catch (e) {
             // Fallback to legacy dummy signature if native method fails (e.g. old plugin version)
             console.warn("Native getPublicKey failed, falling back to signNative", e);
             const dummyHash = "0000000000000000000000000000000000000000000000000000000000000000";
             const res = await signNative({
                 vault: this.vaultName,
                 path,
                 messageHash: dummyHash,
                 network: this.network
             });
             pubkey = res.pubkey;
         }
         
         const pubkeyBuffer = Buffer.from(pubkey, 'hex');
         
         // Derive Address (P2WPKH)
         const { address } = bitcoin.payments.p2wpkh({
             pubkey: pubkeyBuffer,
             network: this.network === 'mainnet' ? bitcoin.networks.bitcoin : bitcoin.networks.testnet
         });
         
         if (!address) throw new Error('Failed to derive identity address');
         
         const chainId = this.network === 'mainnet' ? 'mainnet' : 'testnet'; 
         const did = `did:pkh:btc:${chainId}:${address}`;
         
         const identity = { did, address, publicKey: pubkey };
         IdentityService.cache.set(cacheKey, identity);
         return identity;
     } catch (e) {
         console.error("Identity retrieval failed", e);
         throw new Error('Secure Enclave Identity inaccessible');
     }
  }

  /**
   * Signs a "Sign In With X" (SIWx) style message for authentication.
   * @param challenge A server-provided nonce or message.
   * @param domain The domain requesting login.
   */
  async signAuthMessage(challenge: string, domain: string): Promise<{ signature: string, message: string }> {
      const timestamp = new Date().toISOString();
      const didInfo = await this.getDid();
      
      const message = `${domain} wants you to sign in with your Conxius Identity:\n${didInfo.address}\n\nURI: ${didInfo.did}\nNonce: ${challenge}\nIssued At: ${timestamp}`;
      
      const messageHash = Buffer.from(
        bitcoin.crypto.sha256(Buffer.from(message)),
      ).toString("hex");
      const path = this.network === 'mainnet' ? "m/84'/0'/0'/0/0" : "m/84'/1'/0'/0/0";
      
      const sigRes = await signNative({
          vault: this.vaultName,
          path,
          messageHash,
          network: this.network
      });
      
      return {
          signature: sigRes.signature,
          message
      };
  }

  /**
   * Performs an LNURL-Auth (LUD-04) login using the Breez SDK.
   * This is a passwordless login mechanism for Lightning services.
   */
  async loginWithLightning(lnurl: string): Promise<void> {
      try {
          // Dynamic import to avoid circular dependencies if any
          const { performLnurlAuth } = await import('./breez');
          await performLnurlAuth(lnurl);
          console.log("LNURL-Auth successful");
      } catch (e) {
          console.error("LNURL-Auth failed", e);
          throw new Error('Lightning Authentication failed');
      }
  }

  /**
   * Links an external wallet to the identity.
   * In a real implementation, this might involve signing a message with the external wallet
   * and storing the link in a decentralized registry or locally.
   */
  async linkExternalWallet(walletType: string, address: string): Promise<void> {
      console.log(`Linking ${walletType} wallet: ${address}`);
      // Simulate API call/registry update
      return new Promise(resolve => setTimeout(resolve, 1000));
  }
}
