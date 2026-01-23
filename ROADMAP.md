# Conxius Wallet Roadmap (Implementation-Grade)

## North Star

- Android-first, offline-first wallet for Bitcoin L1 and Bitcoin-adjacent layers, with an explicit interlayer (Wormhole/NTT) execution roadmap.
- Zero secret egress by default: keys and credentials never leave the device without explicit, user-reviewed export.
- “Truthful shipping”: features are either implemented to standard or gated off (no placeholders in production UX).

## Standards Adherence (Non-Negotiable)

- **Bitcoin**
  - BIP-32/39/84 derivation and mnemonic handling
  - BIP-174 PSBT for signing flows
  - BIP-21 for payment URIs
  - BIP-125 for RBF support (when fee bumping ships)
  - BIP-322 only when fully correct (otherwise not exposed as “supported”)
- **Lightning**
  - BOLT11 parsing and invoice safety checks
  - LNURL (LUD specs) with strict input validation and safe networking rules
  - LND REST best practices: scoped macaroons, no logging, explicit user consent
- **Interlayer / Wormhole**
  - NTT execution lifecycle: source tx → attestation/VAA → destination redemption
  - Attestation verification and provider redundancy (no single indexer SPOF)
- **Android Security**
  - Android Keystore AES-GCM with user-auth gated keys for vault protection
  - Secure UI constraints: lock on background, avoid leaking in recents/screenshots

## Quality Gates (Definition of Done)

- Tests: unit tests for crypto + transaction building; integration tests for migrations and signing.
- Security: threat model section updated for any secret-handling changes; no secrets in logs; credential classification documented.
- Correctness: reference vectors where applicable (deterministic address derivation, PSBT validity).
- UX: capability gating (incomplete features are hidden or labeled “experimental”).
- Release hygiene: CHANGELOG entry, version bump policy, migration notes when formats change.

## Current State (Implemented)

- Encrypted state vault with migration support.
- Android SecureEnclave backed by Keystore AES-GCM and user authentication gating (biometric/device credential).
- Auto-lock, duress PIN, and session-only seed usage for signing.
- BTC on-chain send pipeline (PSBT build → sign → broadcast).
- Lightning parsing (BOLT11/LNURL) and LND REST backend plumbing.
- Wormhole/NTT tracking view (execution still planned).

## Milestones

### M1 — Notifications + Event Model (Local-First)

**Scope**

- Local notifications for tx lifecycle and security events.
- A canonical `WalletEvent` taxonomy that drives both toasts and OS notifications.
**Acceptance Criteria**
- Notifications for: tx submitted, tx confirmed, tx failed; auto-lock triggered; vault write blocked by auth.
- No secret material in notification payloads.
- User can disable notifications; app behaves correctly without permissions.

### M2 — Transaction Lifecycle + Reliability (BTC L1)

**Scope**

- Persisted tx history and confirmation tracking; failure recovery.
- Fee management: RBF (BIP-125) and safe defaults.
**Acceptance Criteria**
- Pending txs persist across app restarts; confirmations update deterministically.
- RBF bumps produce valid transactions and do not break history.

### M3 — PSBT Correctness + Privacy

**Scope**

- Coin selection, script-type validation, dust/change policy, address reuse avoidance.
**Acceptance Criteria**
- PSBT creation validates UTXO script type and refuses unsupported scripts with clear UX.
- Coin selection prevents dust outputs and minimizes linkability (documented heuristics).

### M4 — Wormhole/NTT Execution (Interlayer)

**Scope**

- Turn tracking into execution: source tx creation/signing, VAA retrieval/verification, destination redemption.
**Acceptance Criteria**
- Bridge flow is a state machine with recoverability at each phase.
- VAA/attestation data is verified and fetched from at least two providers.

### M5 — Multi-Wallet / Multi-Account

**Scope**

- Multiple vault slots; explicit switching; isolated histories and credentials.
**Acceptance Criteria**
- No cross-wallet leakage (state, history, credentials).
- Safe delete/export per wallet with explicit confirmations.

## Notification Strategy

- Phase 1: Android local notifications (on-device only).
- Phase 2: Optional push notifications (FCM) only when there is a server component and a privacy review.
