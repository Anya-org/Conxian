type SeedEnvelopeV1 = {
  v: 1;
  salt: number[];
  iv: number[];
  data: number[];
};

function getCrypto() {
  const cryptoObj = globalThis.crypto;
  if (!cryptoObj?.subtle) {
    throw new Error('Crypto unavailable');
  }
  return cryptoObj;
}

async function getKeyMaterial(pin: string): Promise<CryptoKey> {
  const enc = new TextEncoder();
  return getCrypto().subtle.importKey('raw', enc.encode(pin), { name: 'PBKDF2' }, false, ['deriveBits', 'deriveKey']);
}

async function deriveAesKey(keyMaterial: CryptoKey, salt: Uint8Array): Promise<CryptoKey> {
  return getCrypto().subtle.deriveKey(
    {
      name: "PBKDF2",
      salt: salt as unknown as ArrayBuffer,
      iterations: 200000,
      hash: "SHA-256",
    },
    keyMaterial,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"],
  );
}

export function isSeedEnvelope(value: unknown): value is SeedEnvelopeV1 {
  if (!value || typeof value !== 'object') return false;
  const v = (value as any).v;
  return v === 1 && Array.isArray((value as any).salt) && Array.isArray((value as any).iv) && Array.isArray((value as any).data);
}

export async function encryptSeed(seed: Uint8Array, pin: string): Promise<string> {
  const cryptoObj = getCrypto();
  const salt = cryptoObj.getRandomValues(new Uint8Array(16));
  const iv = cryptoObj.getRandomValues(new Uint8Array(12));
  const keyMaterial = await getKeyMaterial(pin);
  const key = await deriveAesKey(keyMaterial, salt);
  const ciphertext = await cryptoObj.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    seed as unknown as ArrayBuffer,
  );
  const envelope: SeedEnvelopeV1 = {
    v: 1,
    salt: Array.from(salt),
    iv: Array.from(iv),
    data: Array.from(new Uint8Array(ciphertext))
  };
  return JSON.stringify(envelope);
}

export async function decryptSeed(envelopeStr: string, pin: string): Promise<Uint8Array> {
  const cryptoObj = getCrypto();
  let parsed: unknown;
  try {
    parsed = JSON.parse(envelopeStr);
  } catch {
    throw new Error('Invalid Credentials');
  }
  if (!isSeedEnvelope(parsed)) {
    throw new Error('Invalid Credentials');
  }
  const salt = new Uint8Array(parsed.salt);
  const iv = new Uint8Array(parsed.iv);
  const data = new Uint8Array(parsed.data);
  const keyMaterial = await getKeyMaterial(pin);
  const key = await deriveAesKey(keyMaterial, salt);
  let plaintext: ArrayBuffer;
  try {
    plaintext = await cryptoObj.subtle.decrypt({ name: 'AES-GCM', iv }, key, data);
  } catch {
    throw new Error('Invalid Credentials');
  }
  return new Uint8Array(plaintext);
}

