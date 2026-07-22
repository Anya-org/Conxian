# Yield Module

## Overview (Explanation)
The Yield module manages liquidity incentives, token emissions, and automated yield optimization strategies for the Conxian Protocol. It ensures that capital is deployed efficiently to maximize returns for LPs and stakeholders while maintaining strict risk controls.

## Architecture (Explanation)
The module operates through three main pillars:
- **Incentives**: `cxd-staking.clar` provides pre-funded CXD rewards for compliant stakers.
- **Emissions**: `token-emission-controller.clar` manages the distribution of tokens to authorized targets.
- **Optimization**: `yield-optimizer.clar`, `auto-compounder.clar`, and `enhanced-yield-strategy.clar` are the optimization layer. `auto-compounder.clar` is the Phase 2 trait-driven compounding coordinator.
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
The coordinator is production logic, not a success-returning placeholder. It
accepts a typed `<compoundable-vault-trait>` reference for every vault call and
uses `(contract-of vault)` as the source-vault registry key. The typed reference
prevents the coordinator from pretending it can dynamically call an arbitrary
principal stored in a map.

The production trait is defined in `contracts/traits/compoundable-vault-trait.clar`:

| Trait method | Signature | Semantics |
|--------------|-----------|-----------|
| `get-pending-rewards` | `()` → `(response uint uint)` | Returns the source vault's currently available rewards. |
| `compound` | `(uint principal)` → `(response uint uint)` | Receives the coordinator's minimum output and destination principal, performs the vault's atomic compounding route, and returns actual output. |

#### Configuration API

All configuration functions are admin-only. The admin is initialized to the
contract deployer and can be changed with `set-admin`.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-admin` | `()` | Returns the coordinator administrator. |
| `set-admin` | `(set-admin (principal))` | Transfers administrative control. |
| `register-vault` | `(register-vault (<compoundable-vault-trait>) (principal uint uint uint uint bool))` | Registers or replaces a typed source-vault configuration. The stored fields are destination vault, trigger mode, minimum interval, minimum reward threshold, minimum output, enabled flag, and last successful compound block. Re-registration preserves the last successful block. |
| `update-vault-config` | `(update-vault-config (<compoundable-vault-trait>) (principal uint uint uint uint bool))` | Updates an existing configuration without resetting its interval history. |
| `set-vault-enabled` | `(set-vault-enabled (<compoundable-vault-trait>) (bool))` | Enables or disables a registered source vault. |
| `is-vault-registered` | `(principal)` | Returns whether a source principal is configured. |
| `get-vault-config` | `(principal)` | Returns the optional stored configuration. |

Trigger mode constants are `u1` frequency, `u2` threshold, `u3` either, and
`u4` both. Frequency requires a positive minimum burn-block interval; threshold
requires a positive reward threshold; either and both require both values to be
positive. Every mode requires a positive minimum output. A source and
destination may be the same principal for same-position compounding or
different principals for cross-position compounding.

#### Execution and preflight API

| Function | Signature | Description |
|----------|-----------|-------------|
| `compound` | `(compound (<compoundable-vault-trait>))` | Permissionless trigger. Reads pending rewards, checks registry identity, enabled state, and the configured trigger, calls the typed vault with stored destination/minimum output, checks actual output, then records `last-compound-block`. |
| `compound-for` | `(compound-for (principal <compoundable-vault-trait>))` | Explicit identity-checking variant for integrations that carry a registry key separately. The principal must equal `(contract-of vault)`. |
| `get-trigger-status` | `(principal uint)` | O(1) status helper for off-chain keepers that already read the pending-reward snapshot. |

The trait intentionally combines one read method and one write method. Clarity
does not allow a read-only coordinator function to call a mixed trait because
the trait may dispatch to the write method. Therefore pending-reward reads are
performed directly against the vault by keepers, followed by
`get-trigger-status`; the public `compound` path performs the typed pending
reward call and compounding atomically in one transaction.

`compound` is permissionless and pays no keeper reward in this phase. It is
one source vault per transaction: Clarity cannot batch heterogeneous stored
trait principals or dynamically dispatch a list of vault calls. Off-chain
keepers should batch submission across transactions and use the O(1) preflight
helper to avoid unnecessary calls.

The coordinator propagates vault errors. A disabled, unregistered, identity
mismatch, not-ready, or below-minimum-output call returns an explicit error.
`last-compound-block` is written only after the vault call and minimum-output
assertion succeed. Clarity transaction atomicity therefore rolls back vault and
coordinator state when the vault fails or output is below the configured floor.

The coordinator's explicit errors are `ERR_UNAUTHORIZED` (`u1000`),
`ERR_INVALID_TRIGGER_MODE` (`u1001`), `ERR_INVALID_INTERVAL` (`u1002`),
`ERR_INVALID_THRESHOLD` (`u1003`), `ERR_INVALID_MIN_OUTPUT` (`u1004`),
`ERR_VAULT_NOT_REGISTERED` (`u1005`), `ERR_VAULT_DISABLED` (`u1006`),
`ERR_VAULT_IDENTITY_MISMATCH` (`u1007`), `ERR_TRIGGER_NOT_READY` (`u1008`),
and `ERR_OUTPUT_TOO_LOW` (`u1009`). Vault-specific errors returned by the
typed `compound` method are propagated unchanged.

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
- `auto-compounder.clar`: Phase 2 production coordinator with focused trigger, rollback, and typed-dispatch coverage.
- `yield-optimizer.clar`, `cross-protocol-integrator.clar`, and `enhanced-yield-strategy.clar`: Existing strategy/integration surfaces; not changed in this phase.
