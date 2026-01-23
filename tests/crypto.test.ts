
import { describe, it, expect } from 'vitest';
import { deriveSovereignRoots } from '../services/signer';
import * as bip39 from 'bip39';

describe('Cryptographic Core', () => {
    
    // Fixed test vector from BIP-39 standard
    const mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
    
    it('should validate a correct mnemonic', () => {
        const isValid = bip39.validateMnemonic(mnemonic);
        expect(isValid).toBe(true);
    });

    it('should reject an invalid mnemonic', () => {
        const invalidMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon invalid";
        const isValid = bip39.validateMnemonic(invalidMnemonic);
        expect(isValid).toBe(false);
    });

    it('should deterministically derive Bitcoin Mainnet (BIP-84) addresses', async () => {
        const roots = await deriveSovereignRoots(mnemonic);
        // Known test vector address for path m/84'/0'/0'/0/0
        expect(roots.btc).toBe('bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu'); 
    });

    it('should deterministically derive Stacks (SIP-005) addresses', async () => {
        const roots = await deriveSovereignRoots(mnemonic);
        // Check if it starts with SP (Mainnet)
        expect(roots.stx.startsWith('SP')).toBe(true);
        // Basic length check for Stacks address
        expect(roots.stx.length).toBeGreaterThan(30);
    });

    it('should deterministically derive Rootstock (EVM) addresses', async () => {
        const roots = await deriveSovereignRoots(mnemonic);
        expect(roots.rbtc.startsWith('0x')).toBe(true);
        expect(roots.rbtc.length).toBe(42);
        expect(/^0x[0-9a-fA-F]{40}$/.test(roots.rbtc)).toBe(true);
    });

    it('should deterministically derive Liquid (L-BTC) addresses', async () => {
        const roots = await deriveSovereignRoots(mnemonic);
        // Liquid addresses/pubkeys are usually hex in our mock/signer
        expect(roots.liquid).toBeDefined();
        // It should be a hex string (pubkey)
        expect(/^[0-9a-fA-F]+$/.test(roots.liquid)).toBe(true);
    });
});
