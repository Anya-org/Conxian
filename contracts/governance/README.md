# Governance Module

## Overview (Explanation)
The Governance module implements the Conxian Dual-Council DAO. It separates strategic human oversight (Board) from high-frequency autonomous agent operations (Staff), ensuring the protocol remains both stable and adaptable. This module handles everything from token-weighted voting to emergency circuit breakers and treasury management.

## Canonical governance registries

The following contracts provide production-oriented state and authorization
surfaces for the governance paths that previously contained seven-line stubs:

### `sab-election.clar`

- Opens one burn-block-height election cycle at a time and snapshots the
  configured SIP-010 token supply, voting-token principal, quorum BPS, and
  approval BPS. The token and rules are immutable for that cycle; global
  configuration changes apply only to future cycles.
- Records self-nominations with 32-byte metadata hashes and one escrowed,
  token-weighted vote per voter. Voting and claims must use the token bound to
  the cycle, so changing the configured token cannot strand historical escrow.
- Finalization is permissionless after voting ends. Quorum, approval share, and
  tie handling determine whether an optional winner is recorded.
- Voters can reclaim their escrow once per finalized cycle, including failed or
  tied cycles. Thresholds use overflow-safe ceiling arithmetic, and election
  duration inputs are bounded to a one-million burn-block protocol window. The
  contract records election results but does not mint or install governance NFT
  seats.

### `upgrade-controller.clar`

This is an on-chain **release authorization registry**, not a bytecode
replacement mechanism. It records target principals, implementation hashes,
timelocked activation approvals, rollout percentages, and thresholded emergency
rollback approvals. Deployment tooling or target contracts must consume the
authorization record separately; activation never mutates target code. Signer
approvals are keyed to a monotonically increasing signer-set generation.
Enabling/disabling a signer or changing the threshold advances the generation
and invalidates both activation and rollback approvals from earlier
generations. Rollback windows are bounded to one million burn blocks and their
deadline addition is checked for overflow.

### `gauge-manager.clar`

- Registers enabled gauges with metadata hashes and relative-weight caps.
- Accepts one escrowed vote per voter/gauge/epoch, binds an epoch to the token
  used by its first accepted vote, allows voters to support multiple gauges,
  and preserves finalized epoch weights and eligibility snapshots.
- A disabled gauge has zero canonical capped weight in the active epoch even
  when it already has votes. Re-enabling it during that active epoch restores
  eligibility; after finalization, the epoch's eligibility and cap snapshots
  never change when the gauge is later enabled, disabled, or reconfigured.
- Uses an explicit burn-block epoch-end boundary, permissionless epoch
  finalization, and one-time post-finalization vote withdrawals. After the
  first epoch is initialized, `set-epoch-length` schedules the next epoch only
  and cannot rewrite the current boundary.
- Raw and capped relative weights are read-only accounting values. A cap may
  leave some emission weight unallocated; aggregate votes are bounded so the
  BPS calculation cannot overflow. This contract does not call
  `token-emission-controller` or claim to distribute emissions.

`gauge-manager.clar` is the canonical gauge voting/weight registry.
`gauge-orchestrator.clar` is retained as a compatibility surface and must not
be treated as a parallel source of emission truth.

## Architecture (Explanation)
Governance is divided into two primary loops:
- **Strategic Council**: Human-driven voting via `community-voting-engine.clar` and `community-dao.clar` for protocol upgrades and long-term strategy.
- **Operational Council**: Agent-driven and seat-based voting via `proposal-engine.clar` for parameter adjustments (Stability fees, LTV) and day-to-day operations.
- **Enforcement Layer**: `proposal-executor.clar` and `proposal-registry.clar` handle the trustless execution and recording of passed proposals.
- **Treasury & Identity**: `dao-treasury.clar` manages protocol assets, while `reputation-engine.clar` and BNS integration provide identity-based voting boosts.

## Core Contracts (Reference)

### `community-dao.clar`
Strategic council proposal management.

| Function | Signature | Description |
|----------|-----------|-------------|
| `create-proposal` | `(title (string-ascii 64)) (description (string-ascii 256)) (token principal)` | Creates a new proposal within the community DAO. |

### `proposal-engine.clar`
The primary controller for multi-council governance routing.

| Function | Signature | Description |
|----------|-----------|-------------|
| `submit-proposal` | `(proposal-contract <proposal-trait>) (council-id uint) (start-block uint) (end-block uint)` | Submits a new proposal to a specific council. |
| `vote` | `(proposal-id uint) (support bool)` | Casts a weighted vote on an active proposal. |
| `execute-proposal` | `(proposal-id uint) (proposal-contract <proposal-trait>)` | Triggers execution for a passed proposal. |

### `community-governance-token.clar`
SIP-010 compliant governance token (CXVG).

| Function | Signature | Description |
|----------|-----------|-------------|
| `transfer` | `(amount uint) (sender principal) (recipient principal) (memo (optional (buff 34)))` | Transfers CXVG tokens. |
| `get-balance` | `(user principal)` | Returns the CXVG balance of a user. |

### `dao-treasury.clar`
Central treasury managing protocol-owned assets.

| Function | Signature | Description |
|----------|-----------|-------------|
| `deposit` | `(amount uint) (token <sip-010-trait>)` | Deposits tokens into the treasury. |
| `withdraw-to` | `(amount uint) (token <sip-010-trait>) (recipient principal)` | Withdraws tokens to a specific address (Admin only). |
| `allocate-to-strategy` | `(strategy principal) (amount uint)` | Allocates funds to a yield-generating strategy. |

### `reputation-engine.clar`
Identity-anchored voting power management.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-voter-boost` | `(voter principal)` | Calculates voting weight boost (e.g., BNS identity). |
| `get-weighted-voting-power` | `(voter principal) (base-balance uint)` | Returns final voting power after boosts. |

## Integration Examples (How-to)

### Submitting a Community Proposal
```clarity
(contract-call? .community-dao create-proposal
  "Expansion of Revenue Dam"
  "Increasing the share for governance stakers to 30%"
  .cxvg-token
)
```

### Checking Weighted Voting Power
```clarity
(contract-call? .reputation-engine get-weighted-voting-power tx-sender u1000000)
```

### Emergency "Break Glass" Action
```clarity
(contract-call? .emergency-governance trigger-circuit-breaker)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/governance`

Focused coverage for these registries is in:

- `tests/governance/sab-election.test.ts`
- `tests/governance/upgrade-controller.test.ts`
- `tests/governance/gauge-manager.test.ts`

The focused suites cover authorization and validation, exact burn-block phase
boundaries, token-bound escrow/withdrawal behavior, in-flight election-rule
snapshots, quorum/tie outcomes, signer-generation invalidation for activation
and rollback, timelocks, gauge caps, disabled-gauge history, frozen epoch
timing, arithmetic bounds, and source guards against the former
`stub-func`/`unwrap-panic` paths.

## Jargon Definition (Accessibility)
- **Dual-Council DAO**: A governance structure split between human strategic oversight and autonomous/agent operational control.
- **Strategic Council**: The "Board" of the DAO, focusing on high-level protocol upgrades and vision.
- **Operational Council**: The "Staff" or agents, managing high-frequency parameter adjustments.
- **BNS Boost**: A voting power multiplier granted to users with a verified .btc name on the Bitcoin Name System.
- **Circuit Breaker**: An emergency mechanism to pause protocol activity during a security incident.

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- Governance Model: Dual-Council DAO
- Standard: Hexagonal, CXVG-Weighted, Regulatory-Compliant
