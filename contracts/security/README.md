# Security Module

## Overview (Explanation)
The Security module provides the Conxian Protocol with robust defense mechanisms, including circuit breakers, insurance funds, and rate limiters. These components ensure protocol solvency and protect against systemic risks and MEV exploitation.

## Architecture (Explanation)
The module implements multiple layers of protection:
- **Emergency Controls**: `circuit-breaker.clar` and `enhanced-circuit-breaker.clar` allow for halting specific functions or entire modules.
- **Solvency**: `conxian-insurance-fund.clar` manages a reserve of assets to cover unexpected losses.
- **Operational Safety**: `rate-limiter.clar` prevents large-scale drainage or spam.
- **Reserve Evidence**: `proof-of-reserves.clar` verifies registered secp256k1
  attestations over versioned, network-bound snapshots and promotes only a
  distinct-attestor quorum after live SIP-010 balance/supply reconciliation.
- **MEV Protection**: Dedicated NFT-based protection layers against sandwich attacks and front-running.

## Core Contracts (Reference)

### `circuit-breaker.clar`
Veto-capable pause and reset controls.

| Function | Signature | Description |
|----------|-----------|-------------|
| `toggle-contract-pause` | `(target principal)` | Toggles the pause state for a specific contract. |
| `trigger-veto` | `()` | Triggers a systemic veto. |
| `resolve-veto` | `()` | Resolves an active veto. |

### `enhanced-circuit-breaker.clar`
Advanced Apex-compatible isolation and global controls.

| Function | Signature | Description |
|----------|-----------|-------------|
| `toggle-global-pause` | `()` | Toggles the protocol-wide global pause. |
| `toggle-isolation` | `(protocol principal)` | Toggles isolation for an external CSF protocol. |
| `is-isolated` | `(protocol principal)` | Checks if a protocol is isolated. |

### `conxian-insurance-fund.clar`
The protocol's emergency reserve.

| Function | Signature | Description |
|----------|-----------|-------------|
| `deposit` | `(token <sip-010-trait>) (amount uint)` | Deposits tokens into the insurance fund. |
| `cover-loss` | `(token <sip-010-trait>) (recipient principal) (amount uint)` | Disburses funds to cover protocol losses. |

### `rate-limiter.clar`
Limits the rate of asset outflows.

| Function | Signature | Description |
|----------|-----------|-------------|
| `check-rate-limit` | `(user principal)` | Validates if a user is within their allowed rate limit. |
| `set-custom-limit` | `(user principal) (window-size (optional uint)) (max-ops (optional uint))` | Configures a custom limit for a user. |

### `proof-of-reserves.clar`
Cryptographically binds reserve attestations to one common snapshot digest.

The owner/governance registry binds each attestor principal to one compressed
secp256k1 public key and each SIP-010 token principal to one unique 32-byte asset
identity. Every signer signs a separate envelope over
`{snapshot-digest, sha256(attestor-public-key), nonce}`; quorum is counted only
for the shared snapshot digest. Registry, asset, network, or chain configuration
changes advance an epoch and invalidate older proof status.

`off-chain-backing` excludes the observed balance held by the PoR contract. The
accepted invariant is `on-chain-balance + off-chain-backing >= total-supply`,
implemented without overflow-prone addition.

| Function | Description |
|----------|-------------|
| `set-attestor` / `remove-attestor` | Governance-managed authoritative key registry. Duplicate keys cannot create multiple identities. |
| `set-asset` / `remove-asset` | Binds a SIP-010 contract principal to a unique canonical asset identity. |
| `set-network-id` / `set-chain-id` | Explicit domain configuration; the contract remains fail closed while unset. |
| `get-snapshot-digest` | Returns the canonical common snapshot digest for external signing. |
| `get-attestation-digest` | Returns the signer-specific envelope digest with replay nonce. |
| `submit-attestation` | Re-reads live SIP-010 balance/supply, verifies the signature, rejects replay/duplicates, and promotes only a newer quorum snapshot. |
| `is-fully-backed` / `get-proof-status` | Public, non-mutating live reconciliation checks that fail closed on missing, stale, expired, reconfigured, or drifted evidence. |

The pinned analyzer classifies dynamic trait calls as potentially writing even
when the selected SIP-010 methods are read-only. Consequently, the live checks
are public functions intended for transaction simulation rather than
`define-read-only` functions. Principal-only diagnostic accessors are not proof
of backing and must not be used as production gates.

## Integration Examples (How-to)

### Checking Rate Limits for an Operation
```clarity
(contract-call? .rate-limiter check-rate-limit tx-sender)
```

### Depositing STX into Insurance Fund
```clarity
(contract-call? .conxian-insurance-fund deposit .stx-token u100000000)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/security`

## Jargon Definition (Explanation)

| Term | Definition |
|------|------------|
| **Circuit Breaker** | An emergency mechanism that halts specific protocol functions or entire modules during a security incident to prevent further damage. |
| **MEV (Maximal Extractable Value)** | The profit a block producer (or other actors) can extract by reordering, including, or excluding transactions within a block. |
| **Proof of Reserves (PoR)** | A transparency mechanism that proves an entity has sufficient on-chain and off-chain assets to cover its liabilities. |
| **Insurance Fund** | A reserve of assets held by the protocol to cover unexpected losses, such as liquidations that fail to cover debt. |
| **Veto Quorum** | The minimum number of authorized participants required to trigger a systemic veto and halt administrative functions. |
| **Rate Limiting** | A defensive strategy that limits the number of operations or amount of value a user can move within a specific time window. |

## Status (Reference)
- Implementation: Source-level security controls; deployment and external oracle qualification are not claimed
- Audit Status: Focused simulator tests only; independent audit not claimed
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, Defensive Engineering, CSF-Integrated
