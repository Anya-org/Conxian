import { Capacitor, registerPlugin } from '@capacitor/core';

type SecureEnclaveBiometricPlugin = {
  authenticate(options?: { durationSeconds?: number }): Promise<{ authenticated: boolean; validUntilMs?: number }>;
  clearBiometricSession(): Promise<void>;
};

const SecureEnclave = registerPlugin<SecureEnclaveBiometricPlugin>('SecureEnclave');

export async function authenticateBiometric(): Promise<boolean> {
  if (!Capacitor.isNativePlatform()) return false;
  try {
    const res = await SecureEnclave.authenticate({ durationSeconds: 300 });
    return !!res.authenticated;
  } catch {
    return false;
  }
}

export async function clearBiometricSession(): Promise<void> {
  if (!Capacitor.isNativePlatform()) return;
  try {
    await SecureEnclave.clearBiometricSession();
  } catch {
  }
}
