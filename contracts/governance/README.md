# Governance Module

## Overview (Explanation)
The Governance module implements the Conxian Dual-Council DAO. It separates strategic human oversight (Board) from high-frequency autonomous agent operations (Staff), ensuring the protocol remains both stable and adaptable.

## Architecture (Explanation)
Governance is divided into two primary loops:
- **Strategic Council**: Human-driven voting via `community-voting-engine.clar` for protocol upgrades.
- **Operational Council**: Agent-driven voting via `proposal-engine.clar` for parameter adjustments (Stability fees, LTV).
- **Enforcement**: `proposal-executor.clar` handles the trustless execution of passed proposals.

## Core Contracts (Reference)

### `proposal-engine.clar`
The heart of the Operational Council.

| Function | Signature | Description |
|----------|-----------|-------------|
| `submit-proposal` | `(submit-proposal (title (string-ascii 64)) (description (string-utf8 2048)) (executor <proposal-executor-trait>))` | Submits a new operational proposal. |
| `vote` | `(vote (proposal-id uint) (vote-for bool))` | Casts a vote using governance power (CXVG). |
| `execute-proposal` | `(execute-proposal (proposal-id uint) (executor <proposal-executor-trait>))` | Triggers the execution of a passed proposal. |

### `reputation-engine.clar`
Calculates weighted voting power.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-weighted-voting-power` | `(get-weighted-voting-power (user principal))` | Returns the total voting weight (CXVG + Reputation). |

## Integration Examples (How-to)

### Submitting a Parameter Update
```clarity
(contract-call? .proposal-engine submit-proposal
  "Increase Stability Fee"
  "Adjusting fee to 5.5% due to volatility"
  .stability-fee-executor
)
```

### Voting on a Proposal
```clarity
(contract-call? .proposal-engine vote u42 true)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/governance`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- Governance Model: Dual-Council DAO
- Standard: Hexagonal, CXVG-Weighted
