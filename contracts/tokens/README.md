# Tokens Module

## Overview (Explanation)
The Tokens module manages all native protocol assets including CXD (Sovereign Debt), CXVG (Governance), and CXLP (Liquidity). It enforces strict regulatory compliance via the Sovereign Guard and ensures compatibility with the SIP-010 and SIP-009 standards.

## Architecture (Explanation)
- **Core Assets**: `cxd-token.clar` and `cxvg-token.clar` implement the protocol's primary financial and governance instruments.
- `cxlp-token.clar`: The Liquible Provider token issued for DEX liquidity.
- `cxtr-token.clar`: The Treasury Reward token used for meritocratic distributions.
- **Coordination**: `token-system-coordinator.clar` manages system-wide minting and burning policies.
- **Compliance**: Integrates with the `regulatory-adapter.clar` to enforce jurisdictional sharding and travel rule requirements.

## Core Contracts (Reference)

### `cxd-token.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `mint` | `(amount uint) (recipient principal)` | Mints new CXD. Authorized minters only. |
| `add-minter` | `(minter principal)` | Adds an authorized minter (Admin only). |
| `set-token-uri` | `(new-uri (optional (string-ascii 256)))` | Updates metadata (Admin only). |

### `cxvg-token.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `mint` | `(amount uint) (recipient principal)` | Mints CXVG tokens. Regulatory check enforced. |
| `initialize` | `(admin principal)` | Sets the initial administrator (Admin only). |
| `set-owner` | `(new-owner principal)` | Updates the contract owner (Admin only). |

### `cxlp-token.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `transfer` | `(amount uint) (sender principal) (recipient principal) (memo (optional (buff 34)))` | SIP-010 compliant transfer. |
| `get-balance` | `(who principal)` | Returns the token balance for a user. |

## Jargon (Accessibility)
- **SIP-010**: The standard for fungible tokens on the Stacks blockchain.
- **Sovereign Debt (CXD)**: The primary currency of the Conxian ecosystem, backed by protocol collateral.
- **Vanguard Token (CXVG)**: A governance token that grants voting rights within the Conxian Vanguard DAO.
- **Liquidity Provider Token (CXLP)**: A token representing a user's share in a concentrated liquidity pool.
- **Treasury Reward Token (CXTR)**: A token distributed as an incentive for protocol-aligned activities.
- **Jurisdictional Sharding**: A technique used to partition token functionality or eligibility based on the user's legal jurisdiction.

## Testing (How-to)
`npx vitest run tests/tokens-utility.test.ts`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- SIP Compliance: SIP-010, SIP-009
