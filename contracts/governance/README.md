# Governance Module

## Overview (Explanation)
The Governance module implements the Conxian Dual-Council DAO. It separates strategic human oversight (Board) from high-frequency autonomous agent operations (Staff), ensuring the protocol remains both stable and adaptable. This module handles everything from token-weighted voting to emergency circuit breakers and treasury management.

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
