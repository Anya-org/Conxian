# Compliance Module

## Overview (Explanation)
The Compliance module ensures that all protocol activities adhere to global regulatory standards. It implements a multi-tier KYC/AML system, travel rule enforcement (IVMS101), and institutional-grade auditing tools using SIP-018 structured data.

## Architecture (Explanation)
The module follows a "Hook" pattern for non-invasive enforcement:
- **Registry**: `compliance-manager.clar` maintains the list of authorized providers and user compliance statuses with staleness detection.
- **Enforcement**: `compliance-hooks.clar` provides read-only checks (`check-kyc`, `check-aml`) that other contracts can use to verify callers.
- **Institutional**: `regulatory-adapter.clar` handles SIP-018 compliant domain separators and structured data hashing for audits.
- **Enterprise**: `travel-rule-service.clar` manages VASP registration and transaction logging.

## Core Contracts (Reference)

### `compliance-manager.clar`
The central registry for compliance data.

| Function | Signature | Description |
|----------|-----------|-------------|
| `check-user-compliance` | `(check-user-compliance (principal bool uint bool) (response bool uint))` | Updates the compliance status for a specific user. |
| `register-provider` | `(register-provider (principal) (response bool uint))` | Registers a new authorized compliance provider. |
| `is-compliant` | `(is-compliant (principal) (bool))` | Returns whether a user currently meets the protocol's compliance standards. |

### `compliance-hooks.clar`
Read-only validation hooks for protocol-wide use.

| Function | Signature | Description |
|----------|-----------|-------------|
| `check-kyc` | `(check-kyc (principal) (response bool uint))` | Returns if the user has a valid KYC record. |
| `check-aml` | `(check-aml (principal) (response bool uint))` | Returns if the user has passed AML screening. |
| `verify-kyc` | `(verify-kyc (principal uint) (response bool uint))` | Updates a user's KYC tier level (Authorized providers only). |
| `log-audit-event` | `(log-audit-event ((string-ascii 50) (buff 256)) (response bool uint))` | Logs an institutional audit event. |

### `regulatory-adapter.clar`
SIP-018 Institutional compliance adapter.

| Function | Signature | Description |
|----------|-----------|-------------|
| `check-clean-hands-compliance` | `(check-clean-hands-compliance (principal) (response bool uint))` | Returns institutional "Clean Hands" status for a user. |
| `verify-and-update-compliance` | `(verify-and-update-compliance (principal (string-ascii 3) uint (buff 65)) (response bool uint))` | Verifies SIP-018 attestation signature. |

### `travel-rule-service.clar`
IVMS101 compliance for enterprise transactions.

| Function | Signature | Description |
|----------|-----------|-------------|
| `register-vasp` | `(register-vasp ((string-ascii 20)) (response bool uint))` | Registers a new VASP. |
| `log-travel-rule-data` | `(log-travel-rule-data ((buff 32) (buff 32) (string-ascii 20) (string-ascii 20) uint principal) (response bool uint))` | Logs transaction metadata. |

## Integration Examples (How-to)

### Enforcing Compliance in a Vault
Vaults can use the compliance hooks to protect deposits:
```clarity
(let ((is-kyc (contract-call? .compliance-hooks check-kyc tx-sender)))
  (asserts! (is-ok is-kyc) (err u5001))
)
```

## Testing (How-to)
Validation is performed via the compliance test suite.
1. Run module tests: `npx vitest tests/compliance`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342
- Standard: Hexagonal, SIP-018, IVMS101
