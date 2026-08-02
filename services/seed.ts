// Seed vault — encrypt/decrypt seed bytes with PIN-based WebCrypto

export interface EncryptedSeed {
  iv: number[];
  salt: number[];
  data: number[];
}

async function deriveKey(pin: string, salt: Uint8Array): Promise<CryptoKey> {
  const keyMaterial = await globalThis.crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(pin),
    { name: 'PBKDF2' },
    false,
    ['deriveKey']
  );
  return globalThis.crypto.subtle.deriveKey(
    { name: 'PBKDF2', salt, iterations: 100_000, hash: 'SHA-256' },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  );
}

export async function encryptSeed(seed: Uint8Array, pin: string): Promise<EncryptedSeed> {
  const salt = globalThis.crypto.getRandomValues(new Uint8Array(16));
  const key = await deriveKey(pin, salt);
  const iv = globalThis.crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await globalThis.crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, seed);
  return {
    iv: Array.from(iv),
    salt: Array.from(salt),
    data: Array.from(new Uint8Array(ciphertext)),
  };
}

export async function decryptSeed(encrypted: EncryptedSeed, pin: string): Promise<Uint8Array> {
  const key = await deriveKey(pin, new Uint8Array(encrypted.salt));
  try {
    const plaintext = await globalThis.crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: new Uint8Array(encrypted.iv) },
      key,
      new Uint8Array(encrypted.data)
    );
    return new Uint8Array(plaintext);
  } catch {
    throw new Error('Decryption failed: invalid PIN or corrupted data');
  }
}
