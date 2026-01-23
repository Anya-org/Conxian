# Conxius Wallet PRD (Android-First)

## 1. Product Overview

Conxius is a sovereign, offline-first Android wallet that bridges the Bitcoin ecosystem (L1, Lightning, Stacks, Rootstock, Liquid, Nostr) with interlayer execution capabilities.

The primary differentiator is the **Native Enclave Core**: keys for all supported protocols are generated and used within a hardened boundary (Android Keystore + memory-only seed handling) and never leave the device's secure memory.

## 2. User Personas

- **The Sovereign Hodler**: Wants deep cold storage security on a mobile device. Uses Conxius as a daily driver for small-to-medium amounts, trusting the Android TEE.
- **The Interlayer Explorer**: Moves assets between Bitcoin L1 and rollups/sidechains (Stacks, Liquid, RSK). Needs a reliable bridge client that verifies attestations locally.
- **The Social Nomad**: Uses Nostr for uncensored communication and identity (NIP-06), requiring a secure signer that doesn't expose keys to web relays.
- **The Node Operator**: Connects to their own LND/Core node for privacy via the embedded Breez SDK Greenlight client or remote connection.

## 3. User Journeys

### 3.1. Onboarding (New Wallet)

- **Trigger**: First launch.
- **Flow**:
  1. Splash screen (Boot sequence).
  2. "Create Wallet" vs "Import Wallet".
  3. PIN creation (6+ digits).
  4. Seed generation (BIP-39) inside the Secure Enclave.
  5. **Critical**: User must verify backup (e.g., select words 3, 7, 12).
  6. Biometric enrollment (optional but encouraged).
  7. Dashboard loads with multi-chain view.

### 3.2. Daily Spend (BTC L1)

- **Trigger**: User wants to send BTC.
- **Flow**:
  1. Scan QR or paste address.
  2. Enter amount (Fiat/BTC toggle).
  3. Review fee (Low/Med/High).
  4. "Slide to Pay".
  5. Auth challenge (Biometric/PIN) triggers Native Enclave signing.
  6. Success screen (TxID + Explorer link).
  7. Notification when confirmed.

### 3.3. Lightning Payment (0-Gas)

- **Trigger**: User scans LNURL/BOLT11.
- **Flow**:
  1. App parses intent (Pay/Withdraw).
  2. Shows amount/description.
  3. Confirm payment.
  4. **Enclave Action**: Seed is decrypted natively and passed directly to Breez SDK memory (Zero-Leak).
  5. Instant settlement toast.

### 3.4. Sovereign Identity (Nostr & D.iD)

- **Trigger**: User logs into a Nostr client or D.iD service.
- **Flow**:
  1. "Connect Identity".
  2. **Enclave Action**: NIP-06 private key is derived on-demand from master seed (`m/44'/1237'/...`).
  3. Public Key (`npub`) is returned to UI.
  4. Events are signed natively without exposing the private key (`nsec`).

### 3.5. Multi-Chain Bridge (Liquid/Stacks/RSK)

- **Trigger**: User manages sidechain assets.
- **Flow**:
  1. Select Asset (e.g., L-BTC, STX).
  2. Enclave derives protocol-specific keys (`m/84'/1776'` for Liquid, `m/44'/5757'` for Stacks).
  3. Transaction constructed and signed natively.
  4. Broadcast to respective network.

## 4. Functional Requirements

### 4.1. Key Management (Native Enclave Core)

- **FR-KEY-01**: Master Seed must be encrypted at rest using Android Keystore AES-GCM.
- **FR-KEY-02**: Decrypted seed must reside in memory only during signing/startup and be zeroed immediately after.
- **FR-KEY-03**: Biometric authentication must be required to decrypt the master seed for high-value operations.
- **FR-KEY-04**: Support standard derivation paths:
  - Bitcoin: `m/84'/0'/0'/0/0` (Native Segwit)
  - Stacks: `m/44'/5757'/0'/0/0`
  - Rootstock (EVM): `m/44'/60'/0'/0/0`
  - Liquid: `m/84'/1776'/0'/0/0`
  - Nostr: `m/44'/1237'/0'/0/0`

### 4.2. Transactions

- **FR-TX-01**: Must support BIP-84 (Native Segwit) derivation.
- **FR-TX-02**: Must parse and validate BIP-21 URIs.
- **FR-TX-03**: Must prevent dust outputs during coin selection.
- **FR-TX-04**: Support atomic swaps and peg-ins/peg-outs where applicable.

### 4.3. Connectivity

- **FR-NET-01**: All external API calls must be user-auditable (list of endpoints).
- **FR-NET-02**: Support for Greenlight (Breez SDK) for non-custodial Lightning.

## 5. Non-Functional Requirements

### 5.1. Security

- **NFR-SEC-01**: No sensitive data in logs (seed, private keys, macaroons).
- **NFR-SEC-02**: App preview in "Recents" must be obscured (FLAG_SECURE).
- **NFR-SEC-03**: Root detection warning on startup.
- **NFR-SEC-04**: 0-Gas efficiency for Identity and Lightning Auth.

### 5.2. Reliability

- **NFR-REL-01**: App must work offline (view cached state).
- **NFR-REL-02**: Bridge state must persist across app restarts.

### 5.3. Performance

- **NFR-PERF-01**: Cold launch to Lock Screen < 1s.
- **NFR-PERF-02**: Unlock to Dashboard < 2s.
- **NFR-PERF-03**: Identity derivation < 200ms (cached).

## 6. Release Strategy

- **Alpha (Internal)**: Debug builds, mock assets.
- **Beta (Testnet)**: Public testnet builds, real crypto disabled or testnet-only.
- **Production**: Mainnet enabled, strict security review, APK signing with release keys.

## 7. Continuous Improvement

- **PRD Updates**: This document is the source of truth. Any architectural change (e.g., adding a new chain) triggers a PRD update PR.
- **Testing**: Every PR must pass `testDebugUnitTest` for Android and `npm test` for logic.
- **Verification**: Release builds are verified on physical Pixel devices before publication.
