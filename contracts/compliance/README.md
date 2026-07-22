# Compliance Module

## Overview (Explanation)
The Compliance module ensures that all protocol activities adhere to global regulatory standards. It implements a multi-tier KYC/AML system, travel rule enforcement (IVMS101), and institutional-grade auditing tools using SIP-018 structured data.

## Architecture (Explanation)
The module follows a "Hook" pattern for non-invasive enforcement:
- **Manager**: `compliance-manager.clar` maintains authorized providers and freshness-bearing compliance records.
- **Authoritative identity evidence**: `kyc-registry.clar` owns the KYC record-presence, tier, and sanction-flag decision consumed by the registration gate.
- **Enforcement**: `compliance-hooks.clar` provides read-only checks (`check-kyc`, `check-aml`) that other contracts can use to verify callers.
- **Institutional**: `regulatory-adapter.clar` handles SIP-018 compliant domain separators and structured data hashing for audits.
- **ZKML**: `zkml-verifier.clar` added to the compliance module for zero-knowledge model attestation (CON-70).
- **Enterprise**: `travel-rule-service.clar` manages VASP registration and transaction logging.

## Core Contracts (Reference)

### `compliance-manager.clar`
The central registry for compliance data.

| Function | Signature | Description |
|----------|-----------|-------------|
| `check-user-compliance` | `(check-user-compliance (principal bool uint bool) (response bool uint))` | Updates a compliance record. Owner, approved providers, and the configured sanctions provider may write; `sanctions-checked=true` is restricted to the configured sanctions provider. |
| `register-provider` | `(register-provider (principal) (response bool uint))` | Registers a new authorized compliance provider. |
| `set-sanctions-provider` | `(set-sanctions-provider (principal) (response bool uint))` | Sets the only principal allowed to write a positive legacy clean-screen attestation. |
| `is-compliant` | `(is-compliant (principal) (bool))` | Returns whether a user currently meets the protocol's compliance standards. |
| `is-registration-compliant` | `(is-registration-compliant (principal uint) (response bool uint))` | Canonical fail-closed gate combining a fresh manager record with KYC-registry record presence, tier, and non-sanctioned evidence. |

For the canonical registration gate, the manager record must be present and
fresh (`0 <= burn-block-height - last-updated <= u144`), its tier must be within
`u1-u3` and meet the requested minimum, and `kyc-registry` must contain a
record whose tier also meets that minimum and whose own `is-sanctioned` result
is false. Missing, low-tier, malformed, sanctioned, stale, or future-dated
records return `(ok false)`; a minimum tier outside `u1-u3` returns the named
`ERR_INVALID_MINIMUM_KYC_LEVEL` error. The legacy `sanctions-checked` field is
not used by this gate because its historical meaning is ambiguous; its
positive value remains restricted to the configured sanctions provider for
legacy `is-compliant` consumers. The gate is read-only: it does not collect or
escrow funds, issue refunds, activate registrations, or route registration
fees.

### `compliance-hooks.clar`
Read-only validation hooks for protocol-wide use.

| Function | Signature | Description |
|----------|-----------|-------------|
| `check-kyc` | `(check-kyc (principal) (response bool uint))` | Returns if the user has a valid KYC record. |
| `check-aml` | `(check-aml (principal) (response bool uint))` | Returns if the user has passed AML screening. |
| `verify-kyc` | `(verify-kyc (principal uint) (response bool uint))` | Updates the fresh manager record with `sanctions-checked=false` for an active KYC provider; it does not create or modify the authoritative `kyc-registry` record. |
| `log-audit-event` | `(log-audit-event ((string-ascii 50) (buff 256)) (response bool uint))` | Logs an institutional audit event. |

### `regulatory-adapter.clar`
SIP-018 Institutional compliance adapter.

| Function | Signature | Description |
|----------|-----------|-------------|
| `check-clean-hands-compliance` | `(check-clean-hands-compliance (principal) (response bool uint))` | Returns institutional "Clean Hands" status for a user. |
| `verify-and-update-compliance` | `(verify-and-update-compliance (principal (string-ascii 3) uint (buff 65)) (response bool uint))` | Verifies SIP-018 attestation signature and updates registry. |

### `zkml-verifier.clar`
Zero-knowledge machine learning proof verification.

| Function | Signature | Description |
|----------|-----------|-------------|
| `verify-proof` | `(verify-proof ((string-ascii 64) (buff 32) (buff 1024)) (response bool uint))` | Verifies a ZKML proof payload for model attestation. |

## Integration Examples (How-to)

### Enforcing Compliance in a Vault
Vaults can use the compliance hooks to protect deposits:
```clarity
(let ((is-kyc (contract-call? .compliance-hooks check-kyc tx-sender)))
  (asserts! (is-ok is-kyc) (err u5001))
)
```

## Testing (How-to)
Validation is performed via compiled Clarinet SDK tests.
1. Run the registration gate: `bash scripts/run-tests.sh tests/compliance/compliance-manager-registration.test.ts`
2. Run hook and regulatory regressions: `bash scripts/run-tests.sh tests/enterprise/p0-compliance-hooks.test.ts tests/compliance/regulatory-adapter-sip018.test.ts`

## Jargon Definition (Explanation)

| Term | Definition |
|------|------------|
| **KYC (Know Your Customer)** | The process of verifying the identity of protocol users to prevent fraud and satisfy regulatory requirements. |
| **AML (Anti-Money Laundering)** | A set of procedures designed to prevent the generation of income through illegal actions. |
| **Travel Rule (IVMS101)** | A regulatory requirement (IVMS101 standard) for VASPs to share originator and beneficiary information for transactions above a certain threshold. |
| **ZKML (Zero-Knowledge Machine Learning)** | The use of zero-knowledge proofs to verify that a machine learning model was executed correctly on specific input data without revealing the data or the model itself. |
| **SIP-018** | A Stacks Improvement Proposal for structured data signing, providing a standard way for users to sign off-chain data that can be verified on-chain. |
| **VASP (Virtual Asset Service Provider)** | Any entity that facilitates the exchange, transfer, or custody of virtual assets. |
| **Jurisdictional Sharding** | An architectural pattern where protocol state or transactions are partitioned based on the legal jurisdiction of the participants to ensure local compliance. |

## Status (Reference)
- Implementation: Production-Ready (v1.2.1)
- Audit Status: Internally Verified (April 2026)
- BIP Compliance: BIP-341, BIP-342
- Standard: Hexagonal, SIP-018, IVMS101, ZKML
