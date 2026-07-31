// Encrypted state storage — AES-GCM with PBKDF2 key derivation
// Supports both current format and legacy fixed-salt format

export interface EncryptedState {
  iv: number[];
  salt?: number[];
  data: number[];
}

const FIXED_SALT = new TextEncoder().encode('Conxius_Sovereign_Enclave_V1_Salt');

async function deriveKeyFromPin(pin: string, salt: Uint8Array): Promise<CryptoKey> {
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

export async function encryptState(state: unknown, pin: string): Promise<string> {
  const salt = globalThis.crypto.getRandomValues(new Uint8Array(16));
  const key = await deriveKeyFromPin(pin, salt);
  const iv = globalThis.crypto.getRandomValues(new Uint8Array(12));
  const plaintext = new TextEncoder().encode(JSON.stringify(state));
  const ciphertext = await globalThis.crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, plaintext);
  return JSON.stringify({
    iv: Array.from(iv),
    salt: Array.from(salt),
    data: Array.from(new Uint8Array(ciphertext)),
  });
}

export async function decryptState(encrypted: string, pin: string): Promise<unknown> {
  const enc: EncryptedState = JSON.parse(encrypted);
  const salt = enc.salt ? new Uint8Array(enc.salt) : FIXED_SALT;
  const key = await deriveKeyFromPin(pin, salt);
  try {
    const plaintext = await globalThis.crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: new Uint8Array(enc.iv) },
      key,
      new Uint8Array(enc.data)
    );
    return JSON.parse(new TextDecoder().decode(plaintext));
  } catch {
    throw new Error('Decryption failed: invalid PIN or corrupted data');
  }
}
