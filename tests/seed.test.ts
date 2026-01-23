import { describe, it, expect } from 'vitest';
import { encryptSeed, decryptSeed } from '../services/seed';

describe('seed vault', () => {
  it('roundtrips seed bytes', async () => {
    const seed = globalThis.crypto.getRandomValues(new Uint8Array(64));
    const pin = '1234';
    const enc = await encryptSeed(seed, pin);
    const dec = await decryptSeed(enc, pin);
    expect(Array.from(dec)).toEqual(Array.from(seed));
  });

  it('rejects wrong pin', async () => {
    const seed = new Uint8Array([1, 2, 3, 4]);
    const enc = await encryptSeed(seed, '1234');
    await expect(decryptSeed(enc, '9999')).rejects.toThrow();
  });
});

