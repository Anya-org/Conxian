# Yield Module

## Overview (Explanation)
The Yield module manages liquidity incentives, token emissions, and automated yield optimization strategies for the Conxian Protocol. It ensures that capital is deployed efficiently to maximize returns for LPs and stakeholders.

## Architecture (Explanation)
The module operates through three main pillars:
- **Incentives**: `cxd-staking.clar` provides rewards for CXD stakers.
- **Emissions**: `token-emission-controller.clar` manages the inflation and distribution of CXD tokens.
- **Optimization**: `yield-optimizer.clar` and `auto-compounder.clar` automate rebalancing and reward compounding.

## Core Contracts (Reference)

### `cxd-staking.clar`
Standard staking contract for CXD holders to earn protocol dividends.

| Function | Signature | Description |
|----------|-----------|-------------|
| `stake` | `(stake (amount uint))` | Locks CXD tokens for rewards. |
| `withdraw` | `(withdraw (amount uint))` | Withdraws staked CXD tokens. |
| `get-reward` | `(get-reward)` | Claims accrued staking rewards. |
| `get-staking-stats` | `(get-staking-stats)` | Returns total staked and current reward rate. |

### `token-emission-controller.clar`
The central authority for CXD supply and distribution targets.

| Function | Signature | Description |
|----------|-----------|-------------|
| `update-epoch` | `(update-epoch)` | Triggers the calculation for the next emission period. |
| `drip-rewards` | `(drip-rewards (target principal))` | Releases rewards to a specific authorized target. |
| `add-emission-target` | `(add-emission-target (target principal) (weight uint))` | Registers a new destination for CXD emissions. |

### `yield-optimizer.clar`
Autonomous strategy manager for protocol-controlled liquidity.

| Function | Signature | Description |
|----------|-----------|-------------|
| `update-strategy` | `(update-strategy (vault principal) (risk-score uint) (apy uint))` | Updates the performance data for a specific vault strategy. |
| `get-best-strategy` | `(get-best-strategy (candidates (list 10 principal)))` | Returns the candidate strategy with the best risk-adjusted yield. |

## Integration Examples (How-to)

### Staking CXD
Users can stake their tokens to earn protocol yield:
```clarity
(contract-call? .cxd-staking stake u100000000)
```

### Triggering Automated Rebalancing
The `ops-engine` can trigger a rebalance when strategies drift:
```clarity
(contract-call? .yield-optimizer rebalance .vault-a .vault-b u5000000 .cxd-token)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/yield`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342
- Standard: Hexagonal, Dynamic Emissions
