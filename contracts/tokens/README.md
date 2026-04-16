# Tokens Module

## Overview (Explanation)
The Tokens module defines the various assets and accounting units used within the Conxian Protocol. This includes the primary governance token (CXD), the voting power token (CXVG), and specialized tokens for staking, liquidity, and treasury operations. It also manages concentrated liquidity position NFTs (CXLP).

## Architecture (Explanation)
All fungible tokens in this module follow the SIP-010 standard, while the position NFTs follow the SIP-009 standard.
- **CXD**: The core utility and stable unit, using a Burn-Mint Equilibrium (BME) model.
- **CXVG**: Non-transferable voting power token issued to participants.
- **CXS/CXLP/CXTR**: Specialized tokens for staking, liquidity provisioning, and treasury management.
- **CXLP Position NFT**: Represents specific concentrated liquidity positions in the DEX.

## Core Contracts (Reference)

### `cxd-token.clar`
The primary SIP-010 token for the Conxian ecosystem.

| Function | Signature | Description |
|----------|-----------|-------------|
| `transfer` | `(transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))` | Standard SIP-010 transfer. |
| `mint` | `(mint (amount uint) (recipient principal))` | Mints new CXD. Authorized minters only. |
| `burn` | `(burn (amount uint) (owner principal))` | Burns CXD. Authorized burners only. |
| `add-minter` | `(add-minter (minter principal))` | Adds an authorized minter (Admin only). |
| `add-burner` | `(add-burner (burner principal))` | Adds an authorized burner (Admin only). |
| `get-balance` | `(get-balance (w principal))` | Returns the balance of an account. |

### `cxvg-token.clar`
Governance Voting Power token.

| Function | Signature | Description |
|----------|-----------|-------------|
| `mint` | `(mint (amount uint) (recipient principal))` | Mints CXVG tokens. Regulatory check enforced. |
| `burn` | `(burn (amount uint) (owner principal))` | Burns CXVG tokens. |
| `transfer` | `(transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))` | Transfers CXVG with regulatory checks. |

### `cxs-token.clar`, `cxlp-token.clar`, `cxtr-token.clar`
Standard SIP-010 tokens for Staking, Liquidity, and Treasury.

| Function | Signature | Description |
|----------|-----------|-------------|
| `transfer` | `(transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))` | Standard SIP-010 transfer. |
| `get-balance` | `(get-balance (w principal))` | Returns token balance. |

### `token-system-coordinator.clar`
Administrative interface for system-wide token minting and burning.

| Function | Signature | Description |
|----------|-----------|-------------|
| `mint-cxd` | `(mint-cxd (token <ft-mintable-trait>) (amount uint) (recipient principal))` | Mints CXD with regulatory validation. |
| `mint-cxvg` | `(mint-cxvg (token <ft-mintable-trait>) (amount uint) (recipient principal))` | Mints CXVG with regulatory validation. |
| `burn-cxd` | `(burn-cxd (token <ft-mintable-trait>) (amount uint) (owner principal))` | Burns CXD via mintable trait. |

### `cxlp-position-nft.clar`
SIP-009 NFT for concentrated liquidity positions.

| Function | Signature | Description |
|----------|-----------|-------------|
| `mint-position` | `(mint-position (owner principal) (pool principal) (token0 principal) (token1 principal) (tick-lower int) (tick-upper int) (liquidity uint))` | Mints a new position NFT. |
| `transfer` | `(transfer (token-id uint) (sender principal) (recipient principal))` | Transfers a position NFT. |
| `get-position` | `(get-position (position-id uint))` | Returns position details. |

## Integration Examples (How-to)

### Checking Token Balance
Standard SIP-010 balance check:
```clarity
(let ((balance (unwrap-panic (contract-call? .cxd-token get-balance tx-sender))))
  (print balance)
)
```

### Minting via Coordinator
Authorized agents can mint tokens through the coordinator:
```clarity
(contract-call? .token-system-coordinator mint-cxd .cxd-token u100000000 tx-sender)
```

## Testing (How-to)
Validation is performed using the Clarinet and Vitest frameworks.
1. Check syntax: `clarinet check`
2. Run unit tests: `clarinet test tests/tokens`
3. Integration testing: `npx vitest run ui/tests`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- SIP Compliance: SIP-010 (Fungible), SIP-009 (Non-Fungible)
- Standards: Layer 1-6 Compliant
- Nakamoto Readiness: High
