
/**
 * Conxius Secure Storage Service
 * AES-GCM encryption for persistent state using PBKDF2 key derivation.
 * Ensures no sensitive data is ever stored in plaintext in localStorage.
 */

const LEGACY_SALT_CONSTANT = "Conxius_Sovereign_Enclave_V1_Salt";
const CURRENT_VERSION = 2;

async function getKeyMaterial(password: string): Promise<CryptoKey> {
  const enc = new TextEncoder();
  return globalThis.crypto.subtle.importKey(
    "raw",
    enc.encode(password),
    { name: "PBKDF2" },
    false,
    ["deriveBits", "deriveKey"]
  );
}

async function getKey(keyMaterial: CryptoKey, salt: Uint8Array): Promise<CryptoKey> {
  return globalThis.crypto.subtle.deriveKey(
    {
      name: "PBKDF2",
      salt: salt as unknown as ArrayBuffer,
      iterations: 100000,
      hash: "SHA-256",
    },
    keyMaterial,
    { name: "AES-GCM", length: 256 },
    true,
    ["encrypt", "decrypt"],
  );
}

export const encryptState = async (state: any, pin: string): Promise<string> => {
  try {
    const salt = globalThis.crypto.getRandomValues(new Uint8Array(16));
    const keyMaterial = await getKeyMaterial(pin);
    const key = await getKey(keyMaterial, salt);
    const iv = globalThis.crypto.getRandomValues(new Uint8Array(12));
    const encoded = new TextEncoder().encode(JSON.stringify(state));
    
    const ciphertext = await globalThis.crypto.subtle.encrypt(
      { name: "AES-GCM", iv },
      key,
      encoded
    );

    const ivArray = Array.from(iv);
    const saltArray = Array.from(salt);
    const ctArray = Array.from(new Uint8Array(ciphertext));
    
    return JSON.stringify({ v: CURRENT_VERSION, salt: saltArray, iv: ivArray, data: ctArray });
  } catch (e) {
    console.error("Encryption Failed:", e);
    throw new Error("Enclave Encryption Failure");
  }
};

export const decryptState = async (stored: string, pin: string): Promise<any> => {
  try {
    const parsed = JSON.parse(stored);
    const iv = parsed?.iv;
    const data = parsed?.data;
    const salt = parsed?.salt
      ? new Uint8Array(parsed.salt)
      : new TextEncoder().encode(LEGACY_SALT_CONSTANT);
    const keyMaterial = await getKeyMaterial(pin);
    const key = await getKey(keyMaterial, salt);
    
    const decrypted = await globalThis.crypto.subtle.decrypt(
      { name: "AES-GCM", iv: new Uint8Array(iv) },
      key,
      new Uint8Array(data)
    );

    return JSON.parse(new TextDecoder().decode(decrypted));
  } catch (e) {
    throw new Error("Invalid Credentials");
  }
};

export const isLegacyBlob = (stored: string): boolean => {
  try {
    const parsed = JSON.parse(stored);
    return !parsed.salt || parsed.v !== CURRENT_VERSION;
  } catch {
    return false;
  }
};
