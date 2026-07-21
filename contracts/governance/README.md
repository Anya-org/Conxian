# Governance Module

## Overview (Explanation)
The Governance module implements the Conxian Dual-Council DAO. It separates strategic human oversight (Board) from high-frequency autonomous agent operations (Staff). The `community-voting-engine.clar` contract is the bounded, non-executing strategic voting ledger: it records escrowed CXVG participation, finalizes an outcome, and returns each voter's stake. It does not execute arbitrary proposal actions or withdraw treasury assets.

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
- **Strategic Council**: Human-driven, escrowed CXVG voting via `community-voting-engine.clar` and `community-dao.clar` for protocol upgrades and long-term strategy. The voting engine only records and settles the vote; action execution remains a separate, explicitly reviewed concern.
- **Operational Council**: Agent-driven and seat-based voting via `proposal-engine.clar` for parameter adjustments (Stability fees, LTV) and day-to-day operations.
- **Enforcement Layer**: `proposal-executor.clar` and `proposal-registry.clar` handle the trustless execution and recording of passed proposals.
- **Treasury & Identity**: `dao-treasury.clar` manages protocol assets. Compliance is checked through the routed regulatory adapter. Reputation weighting is deliberately deferred until a trustworthy reputation source is available.

## Core Contracts (Reference)

### `community-dao.clar`
Strategic council proposal management.

| Function | Signature | Description |
|----------|-----------|-------------|
| `create-proposal` | `(title (string-ascii 64)) (description (string-ascii 256)) (token principal)` | Creates a new proposal within the community DAO. |

### `community-voting-engine.clar`
Escrowed CXVG voting lifecycle with permissionless finalization and stake claims.

The contract reads the token and compliance principals from
`operational-treasury` under the canonical keys `cxvg-token` and
`regulatory-adapter`. Callers still pass SIP-010 and regulatory adapter trait
implementations because principals loaded from a map cannot be arbitrary
`contract-call?` targets. Every call verifies that each supplied
`(contract-of ...)` matches the registered route; missing or mismatched routes
fail closed.

The proposal's total-supply snapshot is an aggregate denominator, not a
per-wallet balance snapshot. CXVG acquired after proposal creation may still
be escrowed during the voting window, but cumulative escrow cannot exceed the
immutable snapshot. The engine rejects snapshots above its published
`get-max-safe-supply` bound so the finalization basis-point arithmetic remains
within Clarity's uint range.

Claims validate the immutable token principal stored in the proposal. They do
not require that the current `operational-treasury` token route still points
to that principal, so a route rotation after escrow or finalization does not
strand historical claims. Voting and proposal creation continue to require
the live canonical token and compliance routes.

This replaces the former two-argument mock `create-proposal` entry point. The
public signature now includes the voting window, thresholds, and routed token
and compliance traits; no production call sites were found for the old stub.

| Function | Signature | Description |
|----------|-----------|-------------|
| `create-proposal` | `(start-block uint) (end-block uint) (quorum-bps uint) (approval-bps uint) (token <sip-010-ft-trait>) (compliance <regulatory-adapter-trait>)` | Creates a future, bounded proposal and snapshots nonzero CXVG total supply. The proposer must be compliant. |
| `vote` | `(proposal-id uint) (support bool) (amount uint) (token <sip-010-ft-trait>) (compliance <regulatory-adapter-trait>)` | Escrows a nonzero CXVG amount from the voter to `community-voting-engine`. A principal may vote once, during `[start-block, end-block)`, and must be compliant. |
| `finalize-proposal` | `(proposal-id uint)` | Permissionlessly finalizes once the exclusive end block is reached. Quorum uses escrow participation against the supply snapshot; approval uses the proposal threshold and ties fail. |
| `claim-stake` | `(proposal-id uint) (token <sip-010-ft-trait>)` | Returns a voter's escrow after finalization, whether the proposal passed or failed. Claims are one-time. |
| `get-proposal` | `(proposal-id uint)` | Returns proposal metadata, snapshot, thresholds, escrow totals, and outcome flags. |
| `get-vote` | `(proposal-id uint) (voter principal)` | Returns the immutable vote direction, amount, and claim state. |
| `get-max-safe-supply` | `()` | Returns the maximum proposal snapshot accepted for safe basis-point arithmetic. |

### `proposal-engine.clar`
The primary controller for multi-council governance routing.

| Function | Signature | Description |
|----------|-----------|-------------|
| `submit-proposal` | `(proposal-contract <proposal-trait>) (council-id uint) (start-block uint) (end-block uint)` | Submits a new proposal to a specific council. |
| `vote` | `(proposal-id uint) (support bool)` | Casts a weighted vote on an active proposal. |
| `execute-proposal` | `(proposal-id uint) (proposal-contract <proposal-trait>)` | Triggers execution for a passed proposal. |

### CXVG voting asset: `contracts/tokens/cxvg-token.clar`
The production SIP-010 governance token used for escrowed voting power is
`cxvg-token.clar`.

| Function | Signature | Description |
|----------|-----------|-------------|
| `transfer` | `(amount uint) (sender principal) (recipient principal) (memo (optional (buff 34)))` | Transfers CXVG tokens. |
| `get-balance` | `(user principal)` | Returns the CXVG balance of a user. |

`community-governance-token.clar` is not the voting asset and is not used by
`community-voting-engine.clar`.

### `dao-treasury.clar`
Central treasury managing protocol-owned assets.

| Function | Signature | Description |
|----------|-----------|-------------|
| `deposit` | `(amount uint) (token <sip-010-trait>)` | Deposits tokens into the treasury. |
| `withdraw-to` | `(amount uint) (token <sip-010-trait>) (recipient principal)` | Withdraws tokens to a specific address (Admin only). |
| `allocate-to-strategy` | `(strategy principal) (amount uint)` | Allocates funds to a yield-generating strategy. |

### Reputation weighting (deferred)
The current engine uses raw escrowed CXVG amounts only. It does not call
`reputation-engine.clar`, apply BNS boosts, or claim identity-based voting
weight. Reputation weighting remains deferred until its source and weighting
rules are trustworthy and independently reviewed.

## Integration Examples (How-to)

### Creating a Community Proposal
```clarity
(contract-call? .community-voting-engine create-proposal
  (+ stacks-block-height u10)
  (+ stacks-block-height u100)
  u1000
  u6000
  .cxvg-token
  .regulatory-adapter
)
```

### Casting an Escrowed Vote
```clarity
(contract-call? .community-voting-engine vote
  u1
  true
  u1000000
  .cxvg-token
  .regulatory-adapter
)
```

The operational treasury must already contain matching routes before either
call can succeed. The example uses the current production token and adapter;
the engine still verifies both against the registry at runtime.

Fresh deployments register both routes after all contracts are published.
For simnet, the Clarinet SDK regenerates the default publish plan and does not
reliably execute custom emulated post-deploy calls, so
`tests/setup-test-env.ts` is the supported fresh-simnet wiring artifact and
uses the runtime deployer. `scripts/gen-deployment-plans.py` emits explicit
post-publication calls for testnet and mainnet. The bootstrap and generated
plans are checked by `scripts/assert-community-voting-wiring.py`.

### Finalizing and Claiming
```clarity
(contract-call? .community-voting-engine finalize-proposal u1)
(contract-call? .community-voting-engine claim-stake u1 .cxvg-token)
```

Finalization does not execute an action. A separate governance flow must
explicitly define and authorize any future action execution; that capability
is outside this contract's security boundary and is deferred.

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
- **Escrowed CXVG voting power**: The raw CXVG amount transferred into the voting engine for one immutable vote.
- **Route verification**: Runtime comparison between a trait argument's `(contract-of ...)` principal and the matching operational-treasury registry entry.
- **Circuit Breaker**: An emergency mechanism to pause protocol activity during a security incident.

## Status (Reference)
- Implementation: Escrowed CXVG lifecycle implemented; external audit still required
- Governance Model: Dual-Council DAO with a non-executing strategic voting ledger
- Voting Model: Raw escrowed CXVG, quorum and approval thresholds, strict tie failure
- Deferred: Reputation weighting and arbitrary action execution
