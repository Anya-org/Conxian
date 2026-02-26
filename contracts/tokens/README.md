# Tokens Module

## Overview (Explanation)
The Tokens module defines the various assets and accounting units used within the Conxian Protocol. This includes the primary governance token (CXD), the voting power token (CXVG), and specialized tokens for liquidity and treasury.

## Architecture (Explanation)
All tokens in this module follow the SIP-010 standard for Fungible Tokens.
- **CXD**: The core utility and governance token.
- **CXVG**: A non-transferable token representing voting power, earned through staking or delegation.
- **Accounting**: Tokens like `cxtr-token.clar` and `cxlp-token.clar` are used for internal protocol accounting.

## Core Contracts (Reference)

### `cxd-token.clar`
The primary SIP-010 token for the Conxian ecosystem.

| Function | Signature | Description |
|----------|-----------|-------------|
| `transfer` | `(transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))` | Standard SIP-010 transfer. |
| `mint` | `(mint (amount uint) (recipient principal))` | Creates new CXD tokens. Authorized minters only. |
| `get-voting-power` | `(get-voting-power (user principal))` | Returns the governance voting weight for a user. |

### `cxvg-token.clar`
Governance Voting Power token (non-transferable).

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-balance` | `(get-balance (who principal))` | Returns the voting power balance of a specific user. |
| `mint` | `(mint (amount uint) (recipient principal))` | Issues voting power. Authorized by governance only. |

## Integration Examples (How-to)

### Checking Token Balance
Standard SIP-010 balance check:
```clarity
(let ((balance (unwrap-panic (contract-call? .cxd-token get-balance tx-sender))))
  (print balance)
)
```

### Delegating Voting Power
Users can delegate their governance influence:
```clarity
(contract-call? .cxd-token delegate .governance-agent)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/tokens`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- SIP Compliance: SIP-010
- Standard: Hexagonal, Nakamoto Ready
