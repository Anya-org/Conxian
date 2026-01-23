import { describe, it, expect } from 'vitest';
import { encryptState, decryptState } from '../services/storage';

async function encryptLegacy(state: any, pin: string) {
  const salt = new TextEncoder().encode('Conxius_Sovereign_Enclave_V1_Salt');
  const keyMaterial = await globalThis.crypto.subtle.importKey('raw', new TextEncoder().encode(pin), { name: 'PBKDF2' }, false, [
    'deriveBits',
    'deriveKey'
  ]);
  const key = await globalThis.crypto.subtle.deriveKey(
    { name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt']
  );
  const iv = globalThis.crypto.getRandomValues(new Uint8Array(12));
  const plaintext = new TextEncoder().encode(JSON.stringify(state));
  const ciphertext = await globalThis.crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, plaintext);
  return JSON.stringify({ iv: Array.from(iv), data: Array.from(new Uint8Array(ciphertext)) });
}

describe('storage', () => {
  it('roundtrips current format', async () => {
    const pin = '1234';
    const state = { a: 1, b: 'x' };
    const enc = await encryptState(state, pin);
    const dec = await decryptState(enc, pin);
    expect(dec).toEqual(state);
  });

  it('decrypts legacy fixed-salt format', async () => {
    const pin = '1234';
    const state = { legacy: true, n: 42 };
    const legacyEnc = await encryptLegacy(state, pin);
    const dec = await decryptState(legacyEnc, pin);
    expect(dec).toEqual(state);
  });
});

