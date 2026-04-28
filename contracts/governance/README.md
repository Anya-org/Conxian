# Governance Module

## Overview (Explanation)
The Governance module implements the Conxian Dual-Council DAO. It separates strategic human oversight (Board) from high-frequency autonomous agent operations (Staff), ensuring the protocol remains both stable and adaptable.

## Architecture (Explanation)
Governance is divided into two primary loops:
- **Strategic Council**: Human-driven voting via `community-voting-engine.clar` and `community-dao.clar` for protocol upgrades.
- **Operational Council**: Agent-driven voting via `proposal-engine.clar` for parameter adjustments (Stability fees, LTV).
- **Enforcement**: `proposal-executor.clar` handles the trustless execution of passed proposals.
- **Identity & Compliance**: BNS integration and regulatory adapters ensure clean-hands governance.

## Core Contracts (Reference)

### `community-dao.clar`
Strategic council proposal management.

| Function | Signature | Description |
|----------|-----------|-------------|
| `create-proposal` | `(title (string-ascii 64)) (description (string-ascii 256)) (token principal)` | Creates a new proposal within the community DAO. |

### `community-voting-engine.clar`
Time-bound voting for strategic proposals.

| Function | Signature | Description |
|----------|-----------|-------------|
| `create-proposal` | `(start-time uint) (end-time uint)` | Creates a new voting proposal with specific times. |

### `community-governance-token.clar`
SIP-010 compliant governance token (CXVG).

| Function | Signature | Description |
|----------|-----------|-------------|
| `transfer` | `(amount uint) (sender principal) (recipient principal) (memo (optional (buff 34)))` | Transfers tokens. |
| `get-balance` | `(user principal)` | Returns the balance of a specific user. |

### `governance-handover.clar`
Administrative lifecycle management.

| Function | Signature | Description |
|----------|-----------|-------------|
| `verify-full-handover` | `()` | Verifies if the governance handover is complete. |
| `execute-handover-step` | `(step uint)` | Executes a specific handover step. |

### `ico-offering.clar`
Initial coin offering management.

| Function | Signature | Description |
|----------|-----------|-------------|
| `buy-tokens` | `(amount uint) (token <sip-010-trait>)` | Allows a user to purchase tokens during an ICO. |

## Integration Examples (How-to)

### Submitting a Community Proposal
```clarity
(contract-call? .community-dao create-proposal
  "Expansion of Revenue Dam"
  "Increasing the share for governance stakers to 30%"
  .cxvg-token
)
```

### Checking Governance Power
```clarity
(contract-call? .reputation-engine get-weighted-voting-power tx-sender)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/governance`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- Governance Model: Dual-Council DAO
- Standard: Hexagonal, CXVG-Weighted, Regulatory-Compliant
