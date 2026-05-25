# Lending Module

## Overview (Explanation)

The Lending module provides automated money markets for the Conxian Protocol. It allows users to deposit assets to earn interest and borrow assets against their collateral. Interest rates are determined dynamically based on **market utilization**, which is the ratio of total borrowed funds to total deposits.

## Architecture (Explanation)

The module utilizes a decentralized reserve system optimized for capital efficiency and risk management. It consists of three primary components:

- **Lending Manager**: `lending-manager.clar` serves as the central entry point for all money market operations. It maintains user balances and reserve states.
- **Economic Model**: `interest-rate-model.clar` provides **utilization-based interest curves**. These are mathematical curves that adjust interest rates dynamically: rates increase as borrowing demand grows to encourage more deposits and maintain pool liquidity.
- **Orchestrator**: `lending-orchestrator.clar` provides an alternative, BME-integrated (Business Machine Engine) execution path for advanced protocol interactions.

The module integrates with the protocol's `oracle-aggregator` for real-time asset pricing and the `enhanced-circuit-breaker` for **fail-closed security**. Fail-closed security is a safety mechanism that automatically pauses the protocol if critical price feeds or contract dependencies become unavailable, preventing incorrect executions during market volatility.

## Core Contracts (Reference)

### `lending-manager.clar`

The primary engine for money market operations.

| Function | Signature | Description |
|----------|-----------|-------------|
| `deposit` | `(deposit (asset-trait <sip-010-ft-trait>) (amount uint))` | Deposits tokens to earn interest and record reserve data. |
| `borrow` | `(borrow (asset-trait <sip-010-ft-trait>) (amount uint))` | Borrows tokens against deposited collateral. |
| `repay` | `(repay (asset-trait <sip-010-ft-trait>) (amount uint))` | Repays a borrowed position with interest. |
| `withdraw` | `(withdraw (asset-trait <sip-010-ft-trait>) (amount uint))` | Withdraws previously deposited assets. |
| `collect-reserves` | `(collect-reserves (asset-trait <sip-010-ft-trait>))` | Transfers protocol revenue to the `revenue-distributor`. |
| `get-total-deposits` | `(get-total-deposits (asset principal))` | Returns total deposits for a specific asset. |
| `get-total-borrows` | `(get-total-borrows (asset principal))` | Returns total borrows for a specific asset. |
| `get-reserve-data` | `(get-reserve-data (asset principal))` | Returns raw reserve data for a specific asset. |
| `get-user-supply-balance` | `(get-user-supply-balance (user principal) (asset principal))` | Returns supply balance for a user and asset. |
| `get-protocol-tvl` | `(get-protocol-tvl)` | Returns total value locked across all assets. |
| `calculate-account-health` | `(calculate-account-health (user principal))` | Returns the current health factor for a user. |

### `interest-rate-model.clar`

Provider of mathematical curves for interest rate calculations.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-borrow-rate` | `(get-borrow-rate (utilization uint))` | Returns the current borrow rate (APY in basis points). |
| `get-supply-rate` | `(get-supply-rate (utilization uint))` | Returns the current supply rate (APY in basis points). |

## Integration Examples (How-to)

### Depositing Assets

To deposit 1000 CXD into the lending pool:

```clarity
(contract-call? .lending-manager deposit .cxd-token u1000000000)
```

### Checking Account Health

To verify if a user is eligible for further borrowing or at risk of liquidation:

```clarity
(let ((health-factor (unwrap-panic (contract-call? .lending-manager calculate-account-health tx-sender))))
  (print health-factor)
)
```

## Testing (How-to)

Comprehensive validation is performed using the Vitest framework and Clarinet SDK.

1. **Prerequisites**: Ensure Node.js and Clarinet are installed.
2. **Setup**: Run `npm install` to install dependencies.
3. **Execution**: Run `npx vitest run tests/lending` to execute the module's test suite.

## Status (Reference)

- **Implementation**: Production-Ready (v1.2.1)
- **Audit Status**: Internally Verified (April 2026)
- **BIP Compliance**: BIP-341 (Taproot), BIP-342 (Scripts)
- **Standards**: Clarity 4, Diátaxis, Hexagonal Architecture
