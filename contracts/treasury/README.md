# Treasury Module

## Overview (Explanation)
The Treasury module manages the protocol's capital allocation and revenue distribution. It implements the "Fiscal Dam" (CXIP-013), a 6-way revenue split that ensures the long-term sustainability of the Conxian ecosystem by funding treasury, bounties, LP incentives, grants, buy-backs, and insurance.

## Architecture (Explanation)
This module uses a hub-and-spoke model for fund management:
- **Registry**: `cxd-treasury.clar` maintains the global allocation policy.
- **Distribution**: `revenue-distributor.clar` executes multi-way splits for STX and FTs.
- **Storage**: Specialized vaults like `opex-vault.clar` (Operational), `founder-vault.clar` (Vesting), and `conxian-vaults.clar` (General).

## Core Contracts (Reference)

### `revenue-distributor.clar`
The primary engine for splitting incoming revenue across protocol stakeholders.

| Function | Signature | Description |
|----------|-----------|-------------|
| `distribute-stx` | `(distribute-stx (amount uint))` | Splits STX revenue according to the current 6-way policy. |
| `distribute-token` | `(distribute-token (token <sip-010-ft-trait>) (amount uint))` | Splits FT revenue according to the current 6-way policy. |
| `set-destinations` | `(set-destinations (new-lp principal) (new-treasury principal) (new-bounty principal) (new-grant principal) (new-buyback principal) (new-ins principal))` | Updates the destination principals for revenue. Admin only. |

### `cxd-treasury.clar`
The policy management contract for the CXD ecosystem.

| Function | Signature | Description |
|----------|-----------|-------------|
| `record-diverted-claim` | `(record-diverted-claim (token principal) (amount uint))` | Records claims diverted to the treasury for later allocation. |
| `get-allocation-percentages` | `(get-allocation-percentages)` | Returns the current percentage weights for the 6-way split. |
| `set-authorized-principals` | `(set-authorized-principals (agent principal) (distributor principal))` | Sets the principals authorized to trigger rebalancing. |

### `conxian-vaults.clar`
Multi-asset storage for protocol-controlled liquidity.

| Function | Signature | Description |
|----------|-----------|-------------|
| `deposit` | `(deposit (token <sip-010-ft-trait>) (amount uint))` | Deposits tokens into the protocol vault. |
| `withdraw` | `(withdraw (token <sip-010-ft-trait>) (amount uint) (recipient principal))` | Withdraws tokens from the vault. Authorized only. |
| `get-total-assets` | `(get-total-assets (token principal))` | Returns the total balance of a specific asset held in the vaults. |

## Integration Examples (How-to)

### Distributing Protocol Fees
When a module (like the DEX) collects fees, it should route them through the distributor:
```clarity
(contract-call? .revenue-distributor distribute-token .cxd-token u1000000)
```

### Checking Treasury Reserves
External audits or risk agents can check total protocol assets:
```clarity
(let ((reserves (contract-call? .conxian-vaults get-total-assets .cxd-token)))
  (print reserves)
)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/treasury`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342
- Standard: Hexagonal, 6-Way Fiscal Dam Split
