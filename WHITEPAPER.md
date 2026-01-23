# Conxius Wallet Whitepaper (Android-First)

## Abstract

Conxius is a mobile-first wallet focused on Bitcoin L1 plus Bitcoin-adjacent layers and interlayer execution. The core design principle is an offline-first local enclave model: secrets are generated, used, and stored on-device; network calls are explicit and user-controlled.

This document describes the security boundary, threat model, cryptographic architecture, and system modules required to build an implementation-grade wallet and interlayer client.

## Goals

- Keys and high-sensitivity credentials remain on-device by default.
- Clear recovery model: PIN vault + explicit seed backup flows.
- Honest capability surface: features are either implemented correctly to standard or gated off.
- Android-first hardening with an upgrade path to additional platforms.

## Non-Goals

- “Custodial by default” services (server-held keys).
- Shipping placeholder signatures or “best-effort” cryptography.
- Silent remote telemetry that could correlate user identity and financial behavior.

## System Overview

### Components

- **UI Shell**: React + Vite mobile UI rendered in a Capacitor WebView.
- **App State Vault**: Encrypted state blob persisted on-device and decrypted only after user unlock.
- **Signing Enclave**: In-memory seed usage for signing; seed bytes are cleared after use.
- **Chain Clients**: Network adapters for L1 and layers (indexers, RPC, or gateways).
- **Interlayer Execution**: State machines for bridging and cross-domain operations.
- **Notification Service**: Local-first event system driving in-app and OS notifications.

### Trust Boundaries

- **Trusted**: Android Keystore, OS user authentication, app process memory (bounded).
- **Untrusted**: Network, third-party APIs/indexers, remote nodes, WebView runtime when compromised.
- **Conditional**: User-provided node endpoints and credentials (treated as secrets).

## Threat Model

### Adversaries

- Network adversary: MITM, DNS poisoning, malicious indexers.
- Device adversary: malware, overlay attacks, rooted devices, compromised WebView context.
- User error: unsafe backups, credential reuse, phishing via LNURL or URLs.

### Assets

- Seed material and derived private keys.
- Vault encryption keys and Android Keystore keys.
- Lightning credentials (macaroons) and node endpoints.
- Transaction intent and metadata (recipients, amounts).

### Mitigations (Required)

- No secrets in logs; no secrets in UI notifications.
- Strong input validation for URIs (BIP21/LNURL) and external URLs.
- Strict capability gating: incomplete features are hidden or labeled “experimental”.
- Enforce lock on background and reduce leakage via screenshots/recents where possible.

## Cryptographic Architecture

### Vault Model

- Wallet state is encrypted with a key derived from the user PIN (PBKDF2 or equivalent).
- The encrypted blob is persisted via a platform secure storage provider when available.

### Android Secure Storage

- Android Keystore AES-GCM key protects persisted data.
- When enabled, a user-authenticated key is required for vault operations (biometric or device credential).
- Migration strategy: legacy vault formats migrate forward with explicit versioning.

### Seed Handling

- Seed material is never written to disk in plaintext.
- Signing operations decrypt the seed vault into memory only when needed and wipe bytes after use.

## Bitcoin L1 Transaction Pipeline (Implementation Requirements)

- PSBT construction must validate script type and refuse unsupported inputs.
- Coin selection should minimize dust and avoid pathological address reuse.
- Transaction lifecycle must be persisted:
  - pending → broadcast → confirmed (with confirmations tracking)
  - failure paths and retry/bump strategies (RBF/CPFP where applicable)

## Lightning (Implementation Requirements)

- Treat LND macaroons as private keys; store only in secure storage, never in logs.
- LNURL must not treat arbitrary HTTP(S) as safe by default; enforce strict parsing and user confirmation.
- Provide transport abstraction for Tor/proxying if “Tor routed” is a product promise.

## Interlayer / Wormhole Execution (Implementation Requirements)

Tracking-only is not sufficient for an interlayer client. Execution requires:

- Source chain transaction creation and signing.
- Attestation/VAA retrieval and verification.
- Destination redemption transaction creation and signing.
- State machine with recoverability at each phase and provider redundancy (no SPOF).

## Notifications

- Phase 1: Local notifications driven by an internal event taxonomy.
- Phase 2 (optional): Push notifications only with a server component and privacy review.

## Release and Safety Standards

- Follow Semantic Versioning and Keep a Changelog.
- Every release documents:
  - security-relevant changes
  - migration behavior
  - capability changes (new supported layers/features)
