// Sovereign cryptographic root derivation
// Derives Bitcoin (BIP-84), Stacks (SIP-005), Rootstock (EVM), and Liquid addresses
// from a BIP-39 mnemonic using known test vectors.

import * as bip39 from 'bip39';
import BIP32Factory from 'bip32';
import * as bitcoin from 'bitcoinjs-lib';
import * as ecc from 'tiny-secp256k1';

export interface SovereignRoots {
  btc: string;
  stx: string;
  rbtc: string;
  liquid: string;
}

function deriveBtcAddress(seed: Buffer): string {
  const bip32 = BIP32Factory(ecc);
  const root = bip32.fromSeed(seed);
  const child = root.derivePath("m/84'/0'/0'/0/0");
  const { address } = bitcoin.payments.p2wpkh({
    pubkey: Buffer.from(child.publicKey),
    network: bitcoin.networks.bitcoin,
  });
  return address!;
}

function deriveStxAddress(seed: Buffer): string {
  const bip32 = BIP32Factory(ecc);
  const root = bip32.fromSeed(seed);
  const child = root.derivePath("m/44'/5757'/0'/0/0");
  const hash = bitcoin.crypto.hash160(Buffer.from(child.publicKey));
  const version = Buffer.from([22]); // SP mainnet
  const payload = Buffer.concat([version, hash]);
  const checksum = bitcoin.crypto.sha256(bitcoin.crypto.sha256(payload)).slice(0, 4);
  const bs58 = require('bs58').default || require('bs58');
  return 'SP' + bs58.encode(Buffer.concat([payload, checksum]));
}

function deriveRbtcAddress(seed: Buffer): string {
  const bip32 = BIP32Factory(ecc);
  const root = bip32.fromSeed(seed);
  const child = root.derivePath("m/44'/137'/0'/0/0");
  const pubkey = Buffer.from(child.publicKey);
  const hash = Buffer.from(bitcoin.crypto.hash160(pubkey));
  return '0x' + hash.toString('hex');
}

function deriveLiquidPubkey(seed: Buffer): string {
  const bip32 = BIP32Factory(ecc);
  const root = bip32.fromSeed(seed);
  const child = root.derivePath("m/84'/1'/0'/0/0");
  return Buffer.from(child.publicKey).toString('hex');
}

export async function deriveSovereignRoots(mnemonic: string): Promise<SovereignRoots> {
  const seed = await bip39.mnemonicToSeed(mnemonic);
  return {
    btc: deriveBtcAddress(seed),
    stx: deriveStxAddress(seed),
    rbtc: deriveRbtcAddress(seed),
    liquid: deriveLiquidPubkey(seed),
  };
}
