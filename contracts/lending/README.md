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
| `deposit` | `(deposit (asset-trait <sip-010-ft-trait>) (amount uint))` | Deposits tokens to earn interest. |
| `borrow` | `(borrow (asset-trait <sip-010-ft-trait>) (amount uint))` | Borrows tokens against deposited collateral. |
| `repay` | `(repay (asset-trait <sip-010-ft-trait>) (amount uint))` | Repays a borrowed position with interest. |
| `seize-collateral` | `(seize-collateral (asset-trait <sip-010-ft-trait>) (user principal) (liquidator principal) (amount uint))` | Liquidates an undercollateralized user. Authorized only. |
| `collect-reserves` | `(collect-reserves (asset-trait <sip-010-ft-trait>))` | Transfers protocol revenue to the `revenue-distributor`. |

## Integration Examples (How-to)

### Depositing Assets
```clarity
(contract-call? .lending-manager deposit .cxd-token u1000000)
```

### Borrowing against Collateral
```clarity
(contract-call? .lending-manager borrow .cxd-token u500000)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/lending`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342
- Standard: Hexagonal, Variable Interest Rates
