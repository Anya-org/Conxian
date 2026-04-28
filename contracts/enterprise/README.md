# Conxian Enterprise Module

## Overview (Explanation)
The Enterprise module provides industrial-grade financial primitives for institutional clients, including tiered account management, advanced order types, and structured finance instruments. It is designed to bridge traditional institutional requirements with the Conxian decentralized protocol.

## Architecture (Explanation)
The module follows a layered approach:
- **Enterprise API**: `enterprise-api.clar` manages institutional account registration and KYC logic.
- **Enterprise Facade**: `enterprise-facade.clar` provides a high-level interface for institutional operations.
- **Advanced Order Manager**: `advanced-order-manager.clar` serves as the institutional execution engine for TWAP/VWAP orders with integrated escrow.
- **Ops Loan Manager**: `ops-loan-manager.clar` enables structured B2B finance through Junior/Senior tranches.

## Core Contracts (Reference)

### `enterprise-api.clar`
Institutional account and KYC management.

| Function | Signature | Description |
|----------|-----------|-------------|
| `register-account` | `(tier uint)` | Registers a new institutional account with a specific tier. |
| `update-kyc-status` | `(user principal) (status bool)` | Updates the KYC compliance status for an institutional user. |
| `submit-advanced-order` | `(order-type (string-ascii 10)) (params (buff 128))` | Submits an advanced institutional order. |

### `enterprise-facade.clar`
High-level interface for enterprise services.

| Function | Signature | Description |
|----------|-----------|-------------|
| `set-enterprise-active` | `(active bool)` | Toggles the global operational status of the Enterprise module. |
| `register-account` | `(user principal) (tier uint) (limit uint)` | Registers an enterprise account with specified limits. |
| `submit-twap-order` | `(token-in principal) (token-out principal) (amount uint) (intervals uint) (interval-blocks uint)` | Submits an industrial-scale TWAP order. |

### `ops-loan-manager.clar`
Structured B2B finance.

| Function | Signature | Description |
|----------|-----------|-------------|
| `create-ops-loan` | `(loan-id (string-ascii 32)) (amount uint) (rate uint) (borrower principal)` | Creates a new structured operational loan. |

## Integration Examples (How-to)

### Creating an Institutional Account
```clarity
(contract-call? .enterprise-api register-account u2)
```

### Submitting a TWAP Order
```clarity
(contract-call? .enterprise-facade submit-twap-order
  .stx-token
  .cxd-token
  u1000000000
  u10
  u144
)
```

## Testing (How-to)
Verify structured finance and enterprise flows using the specialized test suite:
`npm test tests/apex-readiness.test.ts`

## Status (Reference)
- Implementation: Active Development (Apex v1.1.0 aligned)
- Audit Status: Internal Review (March 2026)
- Standards compliance: BIP-341, BIP-342, BIP-174
- Goal: Institutional liquidity bridging (CON-452)
