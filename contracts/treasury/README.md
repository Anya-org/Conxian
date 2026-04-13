# Treasury Module

## Overview (Explanation)
The Treasury module manages the protocol's capital allocation and revenue distribution. It implements the "Fiscal Dam" (CXIP-013) and enforces mandatory protocol fees via the Revenue Automation engine. This ensures the long-term sustainability of the Conxian ecosystem by funding treasury, bounties, LP incentives, grants, buy-backs, and insurance.

## Architecture (Explanation)
This module uses a hub-and-spoke model for fund management:
- **Automation**: `revenue-automation.clar` enforces a non-negotiable 100 bps protocol fee on core transactions (CON-60).
- **Registry**: `cxd-treasury.clar` maintains the global allocation policy and tracks accrued claims.
- **Distribution**: `revenue-distributor.clar` executes token buy-backs and burns via the BME engine.
- **Storage**: Specialized vaults like `conxian-vaults.clar` provide secure multi-asset storage with RBAC integration.
- **Off-Chain Persistence**: External settlement events (PAPSS, BRICS) are recorded in the `cnx_bos.cxn_external_settlement_logs` table within the Neon database for institutional reporting and audit.

## Core Contracts (Reference)

### `revenue-automation.clar`
Enforces the 100 bps (1%) protocol fee extraction required for Apex BME.

| Function | Signature | Description |
|----------|-----------|-------------|
| `collect-revenue` | `(token <sip-010-ft-trait>) (amount uint) (payer principal)` | Calculates and transfers 1% fee to the distributor. |
| `set-admin` | `(new-admin principal)` | Updates the administrative principal. |

### `revenue-distributor.clar`
The primary engine for routing protocol fees to the BME engine for burn or swap-and-burn.

| Function | Signature | Description |
|----------|-----------|-------------|
| `distribute-token` | `(token <sip-010-ft-trait>) (amount uint)` | Routes tokens to the BME engine for burning (CXD) or swapping for CXD then burning. |
| `distribute-stx` | `(amount uint)` | Placeholder for STX revenue distribution. |
| `initialize` | `(new-admin principal)` | Initializes the administrative principal. |
| `set-bme-vault` | `(new-vault principal)` | Updates the BME engine principal used for distributions. |

### `cxd-treasury.clar`
The policy management contract for the CXD ecosystem, implementing CXIP-013.

| Function | Signature | Description |
|----------|-----------|-------------|
| `rebalance` | `(treasury uint) (bounty uint) (lp uint) (grant uint) (buyback uint) (insurance uint)` | Updates the 6-way split percentages (must sum to 10000). |
| `record-diverted-claim` | `(token principal) (amount uint)` | Records claims diverted to the treasury for later allocation. |
| `get-allocation-percentages` | `()` | Returns the current percentage weights for the 6-way split. |
| `get-accrued-claim` | `(token principal)` | Returns the total accrued claim for a specific token. |
| `set-authorized-principals` | `(agent principal) (distributor principal)` | Authorizes specific contracts to trigger rebalancing or record claims. |

### `conxian-vaults.clar`
Multi-asset storage for protocol-controlled liquidity with role-based access control.

| Function | Signature | Description |
|----------|-----------|-------------|
| `deposit` | `(token <sip-010-trait>) (amount uint)` | Deposits tokens into the protocol vault (requires RBAC role). |
| `withdraw` | `(token <sip-010-trait>) (amount uint)` | Withdraws tokens from the vault (requires RBAC role). |
| `get-balance` | `(user principal) (token principal)` | Returns the vault balance for a specific user and token. |
| `get-total-assets` | `(token principal)` | Returns the total balance of a specific asset held in the vaults. |

## External Data Schema (Institutional Reporting)

### `cnx_bos.cxn_external_settlement_logs` (Neon DB)
Used for tracking settlements that occur on external networks (e.g., PAPSS) but are referenced by on-chain transactions.

| Field | Type | Description |
|-------|------|-------------|
| `id` | BIGINT | Primary key (identity). |
| `native_tx_hash` | TEXT | Reference to the Stacks on-chain transaction hash. |
| `external_tx_reference` | TEXT | The reference ID from the external settlement network. |
| `settlement_network_origin` | TEXT | Origin network (e.g., 'PAPSS', 'BRICS'). |
| `fiat_value_pegged` | NUMERIC(20, 2) | Pegged fiat value of the settlement. |
| `currency_code` | CHAR(3) | ISO-4217 currency code (default `USD`). |
| `created_at` | TIMESTAMPTZ | Insertion timestamp (default `now()`). |
| `metadata` | JSONB | Provider payload / reconciliation attributes. |

## Integration Examples (How-to)

### Enforcing Protocol Fees
Core modules call the automation engine during value-transfer events:
```clarity
(contract-call? .revenue-automation collect-revenue .cxd-token u1000000 tx-sender)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/treasury`

## Status (Reference)
- Implementation: Production-Ready (v1.2.1)
- Audit Status: Internally Verified (April 2026)
- BIP Compliance: BIP-341, BIP-342
- Standard: Hexagonal, 6-Way Fiscal Dam Split, Diátaxis Compliant
