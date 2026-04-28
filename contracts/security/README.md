# Security Module

## Overview (Explanation)
The Security module provides the Conxian Protocol with robust defense mechanisms, including circuit breakers, insurance funds, and rate limiters. These components ensure protocol solvency and protect against systemic risks and MEV exploitation.

## Architecture (Explanation)
The module implements multiple layers of protection:
- **Emergency Controls**: `circuit-breaker.clar` and `enhanced-circuit-breaker.clar` allow for halting specific functions or entire modules.
- **Solvency**: `conxian-insurance-fund.clar` manages a reserve of assets to cover unexpected losses.
- **Operational Safety**: `rate-limiter.clar` prevents large-scale drainage or spam.
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

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, Defensive Engineering, CSF-Integrated
