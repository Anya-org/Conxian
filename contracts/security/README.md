# Security Module

## Overview (Explanation)
The Security module provides the Conxian Protocol with robust defense mechanisms, including circuit breakers, insurance funds, and rate limiters. These components ensure protocol solvency and protect against systemic risks and MEV exploitation.

## Architecture (Explanation)
The module implements multiple layers of protection:
- **Emergency Controls**: `circuit-breaker.clar` and `enhanced-circuit-breaker.clar` allow for halting specific functions or entire modules.
- **Solvency**: `conxian-insurance-fund.clar` manages a reserve of assets to cover unexpected losses.
- **Operational Safety**: `rate-limiter.clar` prevents large-scale drainage or spam.
- **MEV Protection**: Dedicated NFT-based protection layers against sandwich attacks and front-running.
- **Reserve Attestation Boundary**: `proof-of-reserves.clar` verifies a bounded
  distinct-attestor quorum over chain-, contract-, asset-, balance-, supply-,
  backing-, burn-height-, expiry-, and nonce-bound snapshots. See
  `docs/PROOF_OF_RESERVES.md`; this is not an audit or deployment claim.

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
| **Proof of Reserves (PoR)** | A cryptographic attestation mechanism that reports sufficient represented reserves only while exact live state and active signer quorum remain valid; it does not independently prove off-chain custody. |
| **Insurance Fund** | A reserve of assets held by the protocol to cover unexpected losses, such as liquidations that fail to cover debt. |
| **Veto Quorum** | The minimum number of authorized participants required to trigger a systemic veto and halt administrative functions. |
| **Rate Limiting** | A defensive strategy that limits the number of operations or amount of value a user can move within a specific time window. |

## Status (Reference)
- Implementation: Active source with fail-closed PoR verification; deployment not claimed
- Audit Status: No external auditor/oracle qualification claimed
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, Defensive Engineering, CSF-Integrated
