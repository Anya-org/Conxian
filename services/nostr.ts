
import { getDerivedSecretNative } from './enclave-storage';
import * as tiny from 'tiny-secp256k1';
import { bech32 } from 'bech32';

/**
 * Nostr Identity Service - Production Grade
 * Handles NIP-01 event creation and cryptographic identity management.
 */

export interface NostrEvent {
  id?: string;
  pubkey: string;
  created_at: number;
  kind: number;
  tags: string[][];
  content: string;
  sig?: string;
}

export const generateNostrKeypair = async (vault: string = 'primary_vault') => {
  try {
      // NIP-06: m/44'/1237'/0'/0/0
      const path = "m/44'/1237'/0'/0/0";
      
      const res = await getDerivedSecretNative({
          vault,
          path
      });
      
      const secretHex = res.secret;
      
      // Derive Schnorr Public Key (X-only)
      const privBuffer = Buffer.from(secretHex, 'hex');
      
      // Verify private key is valid
      if (!tiny.isPrivate(privBuffer)) {
          throw new Error("Invalid private key derived");
      }
      
      const pubKey = tiny.pointFromScalar(privBuffer);
      if (!pubKey) {
          throw new Error("Failed to derive public key from scalar");
      }
      const pubKeyX = pubKey.subarray(1, 33); // Drop prefix
      const pubKeyHex = Buffer.from(pubKeyX).toString('hex');
      
      // Encode npub (bech32)
      const words = bech32.toWords(pubKeyX);
      const npub = bech32.encode('npub', words, 1500); // 1500 is limit, standard
      
      return {
        nsec: `ENCLAVE_SECURED_KEY`, // UI display only
        npub: npub,
        rawPriv: secretHex, // INTERNAL USE ONLY
        pubKeyHex: pubKeyHex
      };
  } catch (e) {
      console.error("Nostr key derivation failed", e);
      throw e;
  }
};

export const createNostrEvent = (content: string, pubkey: string, kind: number = 1): NostrEvent => {
  return {
    pubkey,
    created_at: Math.floor(Date.now() / 1000),
    kind,
    tags: [],
    content
  };
};

export const signNostrEvent = async (event: NostrEvent, rawPrivHex: string): Promise<NostrEvent> => {
  console.log("[NOSTR] Signing event with derived enclave key...");
  
  // Real cryptographic ID calculation (SHA256 of serialized event)
  const encoder = new TextEncoder();
  const serialized = JSON.stringify([
    0,
    event.pubkey,
    event.created_at,
    event.kind,
    event.tags,
    event.content
  ]);
  
  const hashBuffer = await crypto.subtle.digest('SHA-256', encoder.encode(serialized));
  const id = Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
    
  const idBuffer = Buffer.from(id, 'hex');
  const privBuffer = Buffer.from(rawPrivHex, 'hex');
  
  // Sign using Schnorr
  const sigBuffer = tiny.signSchnorr(idBuffer, privBuffer);
  const sig = Buffer.from(sigBuffer).toString('hex');

  return { ...event, id, sig };
};
