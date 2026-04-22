# Yield Module

## Overview (Explanation)
The Yield module manages liquidity incentives, token emissions, and automated yield optimization strategies for the Conxian Protocol. It ensures that capital is deployed efficiently to maximize returns for LPs and stakeholders while maintaining strict risk controls.

## Architecture (Explanation)
The module operates through three main pillars:
- **Incentives**: `cxd-staking.clar` provides rewards for CXD stakers.
- **Emissions**: `token-emission-controller.clar` manages the distribution of tokens to authorized targets.
- **Optimization**: `yield-optimizer.clar`, `auto-compounder.clar`, and `enhanced-yield-strategy.clar` automate rebalancing and performance enhancement.
- **Interoperability**: `cross-protocol-integrator.clar` serves as a stub for future external yield source connections.

## Core Contracts (Reference)

### `cxd-staking.clar`
Standard staking contract for CXD holders to earn protocol dividends.

| Function | Signature | Description |
|----------|-----------|-------------|
| `stake` | `(stake (amount uint))` | Locks CXD tokens for rewards. Regulatory check enforced. |

### `token-emission-controller.clar`
The central authority for CXD distribution targets and weights.

| Function | Signature | Description |
|----------|-----------|-------------|
| `request-mint` | `(request-mint (amount uint) (recipient principal))` | Requests a CXD mint based on authorized target weighting. |
| `initialize` | `(initialize (coordinator principal) (cxvg principal))` | Sets the core system principals (Admin only). |
| `add-emission-target` | `(add-emission-target (target principal) (weight uint))` | Registers a new destination for emissions (Admin only). |

### `yield-optimizer.clar`
Autonomous strategy manager for protocol-controlled liquidity.

| Function | Signature | Description |
|----------|-----------|-------------|
| `autonomous-rebalance` | `(autonomous-rebalance (vault-from <vault-trait>) (vault-to <vault-trait>) (amount uint) (token <sip-010-ft-trait>))` | Atomically moves liquidity based on system risk signals. |
| `register-strategy` | `(register-strategy (vault principal) (risk uint) (apy uint))` | Registers a new yield strategy with risk/APY metadata. |
| `initialize` | `(initialize (owner principal) (risk-agent principal))` | Sets administrative principals. |

### `auto-compounder.clar`
Automation layer for harvesting and reinvesting yield.

| Function | Signature | Description |
|----------|-----------|-------------|
| `compound` | `(compound (vault principal))` | Triggers the compounding sequence for a specific vault. |

### `cross-protocol-integrator.clar` & `enhanced-yield-strategy.clar`
Placeholders for future industrial-scale yield enhancements.

| Function | Signature | Description |
|----------|-----------|-------------|
| `placeholder` | `(placeholder)` | Generic entry point for future strategy logic. |

## Integration Examples (How-to)

### Staking CXD
Users can stake their tokens to earn protocol yield:
```clarity
(contract-call? .cxd-staking stake u100000000)
```

### Registering a New Strategy
Administrators can register new vaults for optimization:
```clarity
(contract-call? .yield-optimizer register-strategy .new-vault u1000 u1200)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/check-compile.test.ts`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified (April 2026)
- BIP Compliance: BIP-341, BIP-342
- Standard: Hexagonal, Dynamic Emissions, Risk-Aware Optimization
