# Yield Module

## Overview (Explanation)
The Yield module manages liquidity incentives, token emissions, and automated yield optimization strategies for the Conxian Protocol. It ensures that capital is deployed efficiently to maximize returns for LPs and stakeholders while maintaining strict risk controls.

## Architecture (Explanation)
The module operates through three main pillars:
- **Incentives**: `cxd-staking.clar` provides pre-funded CXD rewards for compliant stakers.
- **Emissions**: `token-emission-controller.clar` manages the distribution of tokens to authorized targets.
- **Optimization**: `yield-optimizer.clar`, `auto-compounder.clar`, and `enhanced-yield-strategy.clar` are the optimization layer; auto-compounding remains pending Phase 2.
- **Interoperability**: `cross-protocol-integrator.clar` serves as a stub for future external yield source connections.

## Core Contracts (Reference)

### `cxd-staking.clar`
Phase 1 CXD staking contract. The token and compliance routes are deliberately
bound to the local `.cxd-token` and `.regulatory-adapter` contracts, so callers
cannot substitute another SIP-010 asset. Staking requires a positive CXD
balance and a successful Clean Hands compliance response.

Rewards are pre-funded with `fund-rewards`. `reward-rate` is raw CXD base units
per burn block, and the O(1) cumulative reward-per-token accumulator uses a
`1e12` precision scale. Only active stake earns rewards or contributes to
governance weight. An unstake request immediately removes active weight, keeps
the principal protected, and becomes withdrawable through `complete-unstake`
after the configured burn-block cooldown. Each account may have one pending
unstake position.

| Function | Signature | Description |
|----------|-----------|-------------|
| `stake` | `(stake (amount uint))` | Transfers CXD into the contract after pause, balance, and compliance checks. |
| `request-unstake` | `(request-unstake (amount uint))` | Checkpoints rewards and moves active stake into one pending cooldown position. |
| `complete-unstake` | `(complete-unstake)` | Returns the pending CXD principal at or after the cooldown boundary. |
| `claim-rewards` | `(claim-rewards)` | Claims accrued, pre-funded CXD without spending active or pending principal. |
| `get-reward` | `(get-reward)` | Compatibility alias for `claim-rewards`. |
| `fund-rewards` | `(fund-rewards (amount uint))` | Admin-only CXD transfer into the tracked reward reserve. |
| `set-reward-rate` | `(set-reward-rate (rate uint))` | Admin-only raw CXD base units per burn block, bounded for arithmetic safety. |
| `set-cooldown-blocks` | `(set-cooldown-blocks (blocks uint))` | Admin-only burn-block cooldown configuration. |
| `set-paused` | `(set-paused (paused bool))` | Admin-only pause for new staking; claims and completed withdrawals remain open. |
| `reward-per-token` / `get-reward-per-token` | `()` | Current cumulative reward-per-token accumulator. |
| `earned` / `get-earned` | `(earned (account principal))` | Current accrued reward for an account. |
| `get-position` | `(get-position (user principal))` | Active stake, paid accumulator, accrued reward, and pending cooldown data. |
| `get-governance-weight` | `(get-governance-weight (user principal))` | Returns active stake only. |
| `get-staking-stats` | `(get-staking-stats)` | Global active/pending stake, rate, reserve, pause, cooldown, and accumulator data. |

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
**Pending Phase 2.** The current contract is a placeholder and is not part of
the Phase 1 staking guarantees.

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
The caller must first hold CXD and satisfy the compliance adapter. A typical
stake and two-step exit are:
```clarity
(contract-call? .cxd-staking stake u100000000)
(contract-call? .cxd-staking request-unstake u25000000)
(contract-call? .cxd-staking complete-unstake)
```

An administrator pre-funds rewards and configures the raw base-unit rate:
```clarity
(contract-call? .cxd-staking fund-rewards u1000000000)
(contract-call? .cxd-staking set-reward-rate u1000)
(contract-call? .cxd-staking claim-rewards)
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
- `cxd-staking.clar`: Phase 1 implementation with focused Vitest coverage.
- `auto-compounder.clar`: Pending Phase 2.
- `yield-optimizer.clar`, `cross-protocol-integrator.clar`, and `enhanced-yield-strategy.clar`: Existing strategy/integration surfaces; not changed in this phase.
