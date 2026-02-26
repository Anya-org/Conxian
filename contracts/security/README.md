# Security Module

## Overview (Explanation)
The Security module provides the Conxian Protocol with robust defense mechanisms, including circuit breakers, insurance funds, and rate limiters. These components ensure protocol solvency and protect against systemic risks and MEV exploitation.

## Architecture (Explanation)
The module implements multiple layers of protection:
- **Emergency Controls**: `circuit-breaker.clar` and `enhanced-circuit-breaker.clar` allow for halting specific functions or entire modules.
- **Solvency**: `conxian-insurance-fund.clar` manages a reserve of assets to cover unexpected losses.
- **Transparency**: `proof-of-reserves.clar` provides on-chain attestations of protocol-controlled assets.
- **Operational Safety**: `rate-limiter.clar` prevents large-scale drainage or spam.

## Core Contracts (Reference)

### `circuit-breaker.clar`
Centralized pause and reset controls for protocol modules.

| Function | Signature | Description |
|----------|-----------|-------------|
| `trigger-circuit-breaker` | `(trigger-circuit-breaker)` | Activates the global circuit breaker. |
| `set-contract-paused` | `(set-contract-paused (contract principal) (paused bool))` | Pauses a specific contract principal. |
| `is-circuit-breaker-active` | `(is-circuit-breaker-active)` | Returns the current status of the circuit breaker. |

### `conxian-insurance-fund.clar`
The protocol's emergency reserve.

| Function | Signature | Description |
|----------|-----------|-------------|
| `deposit` | `(deposit (amount uint))` | Deposits STX into the insurance fund. |
| `cover-loss` | `(cover-loss (recipient principal) (amount uint))` | Disburses funds to cover protocol losses. Authorized only. |

### `rate-limiter.clar`
Limits the rate of asset outflows.

| Function | Signature | Description |
|----------|-----------|-------------|
| `check-rate-limit` | `(check-rate-limit (user principal) (amount uint))` | Verifies if an operation falls within the allowed rate limit. |

## Integration Examples (How-to)

### Halting a Module in Emergency
```clarity
(contract-call? .circuit-breaker trigger-circuit-breaker)
```

### Checking Rate Limits
```clarity
(contract-call? .rate-limiter check-rate-limit tx-sender u1000000)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/security`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342
- Standard: Hexagonal, Defensive Engineering
