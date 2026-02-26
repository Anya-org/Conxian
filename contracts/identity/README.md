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
| `set-identity-status` | `(set-identity-status (user principal) (status bool) (level uint))` | Updates the verification level for a user. Authorized only. |
| `get-identity-status` | `(get-identity-status (user principal))` | Returns the current status and tier for a specific user. |

### `identity-badge.clar`
Reputation and achievement tokens.

| Function | Signature | Description |
|----------|-----------|-------------|
| `mint` | `(mint (recipient principal) (badge-id uint))` | Awards a specific badge to a user. Authorized only. |

## Integration Examples (How-to)

### Checking User Verification
```clarity
(let ((status (unwrap-panic (contract-call? .kyc-registry get-identity-status tx-sender))))
  (asserts! (get status status) (err u5001))
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
