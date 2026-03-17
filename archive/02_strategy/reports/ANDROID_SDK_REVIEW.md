# Android SDK Viewpoint Review: Conxius Wallet

**Date:** 2026-02-19
**Reviewer:** Jules (Lead Software Engineer)
**Scope:** Android Native Integration, Security Architecture, and Blockchain SDKs.

---

## 1. Executive Summary

The Conxius Wallet Android implementation follows a "Native-First" security model, leveraging a Capacitor-based hybrid bridge. The architecture successfully isolates sensitive cryptographic operations and transaction verification within the native Android environment, effectively mitigating risks associated with the JavaScript/Webview layer.

## 2. Technical Analysis

### 2.1 SDK Configuration
- **Compile/Target SDK:** 34 (Android 14).
- **Minimum SDK:** 24 (Android 7.0).
- **Build System:** Gradle with Kotlin 1.9.22 integration.
- **Dependency Management:** Heavy reliance on trusted blockchain libraries (`bitcoinj`, `web3j`, `breez_sdk`).

### 2.2 Security Architecture
- **Screen Protection:** `MainActivity` enforces `FLAG_SECURE`, preventing screenshots and screen recordings of the wallet interface.
- **Trusted UI (WYSIWYS):** The `SecureEnclavePlugin` implements a native confirmation dialog (`AlertDialog`) that parses transaction payloads before signing. This ensures that the user verifies the actual transaction data, not just what the webview displays.
- **Root/Integrity Detection:** `DeviceIntegrityPlugin` provides a multi-layered detection suite (su binary, Magisk/SuperSU package detection, system property audits, and emulator fingerprinting).
- **Vault Security:** Uses PBKDF2 with 200,000 iterations and AES-GCM for storage encryption.
- **Memory Hardening:** The codebase consistently uses `Arrays.fill()` to zero-out sensitive byte arrays (seeds, keys, PINs) immediately after use to minimize the window for memory scraping attacks.

### 2.3 Blockchain Integration
- **Bitcoin (L1/Taproot):** Native parsing via `bitcoinj`. Manual BIP-340 Schnorr signature implementation correctly handles tagged hashes for RGB and Ark protocols.
- **EVM & L2s:** Integration via `web3j` supports RSK, Stacks, and emerging Bitcoin L2s (BOB, B2, Botanix, Mezo).
- **Lightning:** Integrated via `breez_sdk`.

## 3. Findings & Recommendations

### 3.1 Critical: Backup Policy
- **Status:** FIXED ✅
- **Change:** Set `android:allowBackup="false"` and `android:fullBackupContent="false"` in `AndroidManifest.xml`.

### 3.2 High: ProGuard/R8 Configuration
- **Status:** FIXED ✅
- **Change:** Implemented comprehensive ProGuard rules for all integrated blockchain SDKs.

### 3.3 Medium: Hardware Attestation
- **Status:** IMPROVED ✅
- **Change:** Integrated Play Integrity API scaffolding and \`requestIntegrityToken\` method for server-side validation.

### 3.4 Observation: Kotlin Standard Library
- **Finding:** Kotlin versions are forced in `build.gradle` to maintain compatibility.
- **Recommendation:** Periodically review these overrides to ensure the app stays aligned with Capacitor's native dependencies.

---

## 4. Conclusion

From an Android SDK viewpoint, the Conxius Wallet is well-architected for a non-custodial mobile application. The implementation of Native Enclave bridges and Trusted UI patterns provides a strong defense-in-depth against common mobile threat vectors. Addressing the backup policy and ProGuard rules will significantly harden the production release.
