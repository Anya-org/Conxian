# Identity Module

## Overview (Explanation)
The Identity module manages user verification and reputation within the Conxian ecosystem. It provides the protocol with the necessary context to enforce compliance and distribute rewards based on user history and verification status.

## Architecture (Explanation)
The module utilizes a decentralized identity model:
- **KYC Registry**: `kyc-registry.clar` stores verification levels and status for all protocol participants.
- **Badges**: `identity-badge.clar` implements SIP-009 NFTs to represent specific achievements or verification tiers.
- **Privacy**: Only necessary verification flags are stored on-chain; sensitive data remains off-chain.

## Core Contracts (Reference)

### `kyc-registry.clar`
The primary registry for user verification data.

| Function | Signature | Description |
|----------|-----------|-------------|
| `set-identity-status` | `(set-identity-status (principal uint uint (string-ascii 3)) (response bool uint))` | Admin-only update of a user's tier, flags, and three-character country code. |
| `get-identity-status` | `(get-identity-status (principal) (tuple {tier:uint, flags:uint, country:(string-ascii 3)}))` | Returns the stored status or a zero/default tuple when no record exists. |
| `has-identity-status` | `(has-identity-status (principal) (bool))` | Distinguishes a stored identity record from the default tuple returned by `get-identity-status`. |
| `is-sanctioned` | `(is-sanctioned (principal) (bool))` | Returns the registry's own sanction decision; flag `u2` means sanctioned. |
| `get-tier` | `(get-tier (principal) (uint))` | Returns the stored tier or `u0` when no record exists. |

The registration gate uses `has-identity-status`, the registry tier, and
`is-sanctioned`; it does not infer record existence from the default tuple or
from a separate compliance-manager boolean. The registry has no freshness
timestamp of its own, so the gate's freshness requirement applies to the
companion `compliance-manager` record.

### `identity-badge.clar`
Reputation and achievement tokens.

| Function | Signature | Description |
|----------|-----------|-------------|
| `mint` | `(mint (recipient principal) (badge-id uint))` | Awards a specific badge to a user. Authorized only. |

## Integration Examples (How-to)

### Checking User Verification
```clarity
(let ((status (contract-call? .kyc-registry get-identity-status tx-sender)))
  (asserts! (contract-call? .kyc-registry has-identity-status tx-sender) (err u5001))
  (asserts! (>= (get tier status) u1) (err u5001))
)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/identity`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- Identity Standard: Verified Principals
- Standard: Hexagonal Architecture
