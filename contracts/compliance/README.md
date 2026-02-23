# Compliance Module

## Overview (Explanation)
The Compliance module ensures that all protocol activities adhere to global regulatory standards. It implements a multi-tier KYC/AML system, travel rule enforcement, and institutional-grade auditing tools.

## Architecture (Explanation)
The module follows a "Hook" pattern for non-invasive enforcement:
- **Registry**: `compliance-manager.clar` maintains the list of authorized providers and user compliance statuses.
- **Enforcement**: `compliance-hooks.clar` provides read-only checks (`check-kyc`, `check-aml`) that other contracts can use to verify callers.
- **Institutional**: `regulatory-adapter.clar` handles SIP-018 compliant domain separators and structured data hashing for audits.

## Core Contracts (Reference)

### `compliance-manager.clar`
The central registry for compliance data.

| Function | Signature | Description |
|----------|-----------|-------------|
| `check-user-compliance` | `(check-user-compliance (user principal) (sanctions-checked bool) (kyc-level uint) (travel-rule-checked bool))` | Updates the compliance status for a specific user. |
| `is-compliant` | `(is-compliant (user principal))` | Returns whether a user currently meets the protocol's compliance standards. |
| `set-sanctions-provider` | `(set-sanctions-provider (provider principal))` | Sets the authorized principal for reporting sanctions data. |

### `compliance-hooks.clar`
Read-only validation hooks for protocol-wide use.

| Function | Signature | Description |
|----------|-----------|-------------|
| `check-kyc` | `(check-kyc (user principal))` | Returns a boolean indicating if the user has a valid KYC record. |
| `check-aml` | `(check-aml (user principal))` | Returns a boolean indicating if the user has passed AML screening. |
| `verify-kyc` | `(verify-kyc (user principal) (kyc-level uint))` | Updates a user's KYC tier level. Authorized providers only. |

### `regulatory-adapter.clar`
SIP-018 Institutional compliance adapter.

| Function | Signature | Description |
|----------|-----------|-------------|
| `check-clean-hands-compliance` | `(check-clean-hands-compliance (user principal))` | Returns institutional "Clean Hands" status for a user. |

## Integration Examples (How-to)

### Enforcing Compliance in a Vault
Vaults can use the compliance hooks to protect deposits:
```clarity
(let ((is-kyc (contract-call? .compliance-hooks check-kyc tx-sender)))
  (asserts! is-kyc (err u5001))
)
```

### Reporting an Audit Event
Authorized agents can log events to the immutable audit trail:
```clarity
(contract-call? .compliance-hooks log-audit-event "DEPOSIT" 0xdeadbeef)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/compliance`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342
- Standard: Hexagonal, SIP-018
