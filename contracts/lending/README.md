# Lending Module

## Overview (Explanation)

The Lending module provides automated money markets for the Conxian Protocol. It allows users to deposit assets to earn interest and borrow assets against their collateral. Interest rates are determined dynamically based on market utilization.

## Architecture (Explanation)

The module utilizes a decentralized reserve system:

- **Manager**: `lending-manager.clar` handles the core lending/borrowing logic and collateralization checks.
- **Economic Model**: `interest-rate-model.clar` provides the mathematical curves for variable interest rates.
- **Security**: Integrates with the `circuit-breaker` for emergency halts.

## Core Contracts (Reference)

### `lending-manager.clar`

The primary engine for money market operations.

| Function | Signature | Description |
|----------|-----------|-------------|
| `deposit` | `(deposit (asset-trait <sip-010-ft-trait>) (amount uint))` | Deposits tokens to earn interest and record reserve data. |
| `borrow` | `(borrow (asset-trait <sip-010-ft-trait>) (amount uint))` | Borrows tokens against deposited collateral. |
| `repay` | `(repay (asset-trait <sip-010-ft-trait>) (amount uint))` | Repays a borrowed position with interest (fees). |
| `withdraw` | `(withdraw (asset-trait <sip-010-ft-trait>) (amount uint))` | Withdraws previously deposited assets. |
| `collect-reserves` | `(collect-reserves (asset-trait <sip-010-ft-trait>))` | Transfers protocol revenue to the `revenue-distributor`. |
| `get-total-deposits` | `(get-total-deposits (asset principal))` | Returns total deposits for a specific asset. |
| `get-total-borrows` | `(get-total-borrows (asset principal))` | Returns total borrows for a specific asset. |
| `get-reserve-data` | `(get-reserve-data (asset principal))` | Returns raw reserve data for a specific asset. |
| `get-user-supply-balance` | `(get-user-supply-balance (user principal) (asset principal))` | Returns supply balance for a user and asset. |
| `get-protocol-tvl` | `(get-protocol-tvl)` | Returns total value locked (Legacy endpoint). |
| `set-admin` | `(set-admin (new-admin principal))` | Updates the administrator principal. |

### `interest-rate-model.clar`

Provider of mathematical curves for interest rate calculations.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-borrow-rate` | `(get-borrow-rate (utilization uint))` | Returns the current borrow rate (APY in basis points). |
| `get-supply-rate` | `(get-supply-rate (utilization uint))` | Returns the current supply rate (APY in basis points). |

## Integration Examples (How-to)

### Depositing Assets

```clarity
(contract-call? .lending-manager deposit .cxd-token u1000000)
```

### Querying Asset Liquidity

```clarity
(let ((deposits (unwrap-panic (contract-call? .lending-manager get-total-deposits .cxd-token))))
  (print deposits)
)
```

## Testing (How-to)

Comprehensive validation is performed using the Vitest framework.

1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/lending`

## Status (Reference)

- Implementation: Production-Ready (v1.2.1)
- Audit Status: Internally Verified (April 2026)
- BIP Compliance: BIP-341, BIP-342
- Standard: Hexagonal, Variable Interest Rates, Diátaxis Compliant
