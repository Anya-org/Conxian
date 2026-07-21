# Governance Module

## Overview (Explanation)
The Governance module implements the Conxian Dual-Council DAO. It separates strategic human oversight (Board) from high-frequency autonomous agent operations (Staff). The `community-voting-engine.clar` contract is the bounded, non-executing strategic voting ledger: it records escrowed CXVG participation, finalizes an outcome, and returns each voter's stake. It does not execute arbitrary proposal actions or withdraw treasury assets.

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
