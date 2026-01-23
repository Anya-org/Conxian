import { Capacitor, registerPlugin } from '@capacitor/core';

type SecureEnclavePlugin = {
  isAvailable(): Promise<{ available: boolean }>;
  hasItem(options: { key: string }): Promise<{ exists: boolean }>;
  getItem(options: {
    key: string;
    requireBiometric?: boolean;
  }): Promise<{ value: string | null }>;
  setItem(options: {
    key: string;
    value: string;
    requireBiometric?: boolean;
  }): Promise<void>;
  removeItem(options: {
    key: string;
    requireBiometric?: boolean;
  }): Promise<void>;
  authenticate(options?: {
    durationSeconds?: number;
  }): Promise<{ authenticated: boolean; validUntilMs?: number }>;
  clearBiometricSession(): Promise<void>;
  signTransaction(options: {
    vault: string;
    pin?: string; // Made optional as per instruction
    path: string;
    messageHash: string;
    network?: string;
  }): Promise<{ signature: string; pubkey: string }>;
  unlockSession(options: {
    vault: string;
    pin: string;
  }): Promise<{ unlocked: boolean }>;
  getPublicKey(options: {
    vault: string;
    pin?: string;
    path: string;
    network?: string;
  }): Promise<{ pubkey: string }>;
  getDerivedSecret(options: {
    vault: string;
    pin?: string;
    path: string;
  }): Promise<{ secret: string; pubkey: string }>;
  getWalletInfo(options: {
    vault: string;
    pin?: string;
  }): Promise<{ btcPubkey: string; stxPubkey: string; liquidPubkey: string; evmAddress: string }>;
};

const SecureEnclave = registerPlugin<SecureEnclavePlugin>('SecureEnclave');

export { SecureEnclave }; // Export the plugin instance for direct access if needed

async function hasNativeSecureEnclave() {
  if (!Capacitor.isNativePlatform()) return false;
  try {
    const res = await SecureEnclave.isAvailable();
    return !!res.available;
  } catch {
    return false;
  }
}

export async function hasEnclaveBlob(key: string): Promise<boolean> {
  if (await hasNativeSecureEnclave()) {
    try {
      const res = await SecureEnclave.hasItem({ key });
      return !!res.exists;
    } catch {
      return false;
    }
  }
  return sessionStorage.getItem(key) != null || localStorage.getItem(key) != null;
}

export async function getEnclaveBlob(key: string, opts?: { requireBiometric?: boolean }): Promise<string | null> {
  if (await hasNativeSecureEnclave()) {
    try {
      const native = await SecureEnclave.getItem({ key, requireBiometric: opts?.requireBiometric ?? false });
      if (native.value != null) return native.value;
    } catch (e: any) {
      const msg = typeof e?.message === 'string' ? e.message : '';
      if ((opts?.requireBiometric ?? false) && msg.toLowerCase().includes('auth required')) {
        throw new Error('auth required');
      }
    }
    const legacy = localStorage.getItem(key);
    if (legacy != null) {
      try {
        await SecureEnclave.setItem({ key, value: legacy, requireBiometric: false });
        localStorage.removeItem(key);
      } catch {
        return legacy;
      }
      return legacy;
    }
    return null;
  }
  const session = sessionStorage.getItem(key);
  if (session != null) return session;
  const legacy = localStorage.getItem(key);
  if (legacy != null) {
    sessionStorage.setItem(key, legacy);
    localStorage.removeItem(key);
    return legacy;
  }
  return null;
}

export async function setEnclaveBlob(key: string, value: string, opts?: { requireBiometric?: boolean }): Promise<void> {
  if (await hasNativeSecureEnclave()) {
    try {
      await SecureEnclave.setItem({ key, value, requireBiometric: opts?.requireBiometric ?? false });
      localStorage.removeItem(key);
      return;
    } catch (e: any) {
      const msg = typeof e?.message === 'string' ? e.message : '';
      if ((opts?.requireBiometric ?? false) && msg.toLowerCase().includes('auth required')) {
        throw new Error('auth required');
      }
    }
  }
  sessionStorage.setItem(key, value);
  localStorage.removeItem(key);
}

export async function removeEnclaveBlob(key: string): Promise<void> {
  if (await hasNativeSecureEnclave()) {
    try {
      await SecureEnclave.removeItem({ key });
    } catch {
    }
  }
  sessionStorage.removeItem(key);
  localStorage.removeItem(key);
}

export async function clearEnclaveBiometricSession(): Promise<void> {
  if (await hasNativeSecureEnclave()) {
    try {
      await SecureEnclave.clearBiometricSession();
    } catch {
    }
  }
}

export async function signNative(options: {
  vault: string;
  pin?: string;
  path: string;
  messageHash: string;
  network?: string;
}): Promise<{ signature: string; pubkey: string }> {
  if (await hasNativeSecureEnclave()) {
    return await SecureEnclave.signTransaction(options);
  }
  throw new Error("Native Enclave not available");
}

export async function getPublicKeyNative(options: {
  vault: string;
  pin?: string;
  path: string;
  network?: string;
}): Promise<{ pubkey: string }> {
  if (await hasNativeSecureEnclave()) {
    return await SecureEnclave.getPublicKey(options);
  }
  throw new Error("Native Enclave not available");
}

export async function getDerivedSecretNative(options: {
  vault: string;
  pin?: string;
  path: string;
}): Promise<{ secret: string; pubkey: string }> {
  if (await hasNativeSecureEnclave()) {
    return await SecureEnclave.getDerivedSecret(options);
  }
  throw new Error("Native Enclave not available");
}

export async function getWalletInfoNative(options: {
  vault: string;
  pin?: string;
}): Promise<{ btcPubkey: string; stxPubkey: string; liquidPubkey: string; evmAddress: string }> {
  if (await hasNativeSecureEnclave()) {
    return await SecureEnclave.getWalletInfo(options);
  }
  throw new Error("Native Enclave not available");
}
