# Strategic Report: Conclave iOS Parity & Secure Enclave Integration (M13)

## 1. Executive Summary
The Conxian ecosystem's current reliance on Android TEE/StrongBox creates a "Hardware Lock-in" vulnerability and alienates the high-value iOS market (~60% of Bitcoin-native users in target regions). The **iOS Parity Plan** transitions the **Conclave SDK** into a platform-agnostic signing layer, leveraging Apple's **Secure Enclave** to provide equivalent "Zero Secret Egress" security for iOS users.

## 2. Technical Architecture: Apple Secure Enclave
- **Hardware Isolation:** Utilizing the Secure Enclave processor to generate and store private keys (secp256k1) with hardware-enforced protection.
- **Biometric Binding:** All signing operations must be authenticated via FaceID or TouchID at the hardware level.
- **Attestation Flow:** Implementing **App Attest** to provide cryptographic proof of the app's integrity and environment to the Conxian Nexus.

## 3. Implementation Roadmap (Q3 2026)
- **Q3 (Alpha):** Development of the `lib-conclave-ios` Swift wrapper.
- **Q3 (Beta):** Integration with the **Conxius Wallet** iOS beta client.
- **Q4 (Production):** Full "Unified Wallet" launch supporting Android and iOS with hardware-grade security parity.

## 4. Market Impact & Valuation
- **Addressable Market Increase:** 2.5x increase in targetable institutional and retail users.
- **Risk Mitigation:** Eliminates vendor dependency on specific Android hardware providers.
- **Strategic Moat:** Positions Conxian as the **first non-custodial wallet** to offer unified, hardware-grade security for the full Bitcoin stack across all major mobile platforms.

---
[Return to Strategy](../../BD_UNIT_ACCESS.md) | [View Roadmap](../../ROADMAP.md)
