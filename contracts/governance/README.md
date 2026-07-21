# Governance Module

## Overview (Explanation)
The Governance module contains Conxian's proposal, execution, treasury, and emergency-governance contracts. The active path is the proposal pipeline; the community-voting and upgrade-controller source stubs are retained for future design work but are intentionally excluded from active deployment.

## Architecture (Explanation)
Governance is organized around the active proposal path and supporting systems:
- **Active proposal path**: `proposal-engine.clar` routes proposals, `proposal-registry.clar` records them, and `proposal-executor.clar` handles execution.
- **Separate timelock primitive**: `timelock.clar` is deployed independently for delayed execution, but the current proposal path does not route through it; explicit integration remains pending.
- **Source-only stubs**: `community-voting-engine.clar` and `upgrade-controller.clar` are intentionally excluded from active deployment pending an architecture/API design. This does not implement a voting facade or proxy-upgrade semantics.
- **Treasury & identity**: `dao-treasury.clar` manages protocol assets, while `reputation-engine.clar` remains available for future governance design.

## Core Contracts (Reference)

### `community-dao.clar`
Community proposal data model; the community voting implementation is deferred.

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
Source component for future identity-anchored voting design; not an active strategic voting path.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-voter-boost` | `(voter principal)` | Calculates voting weight boost (e.g., BNS identity). |
| `get-weighted-voting-power` | `(voter principal) (base-balance uint)` | Returns final voting power after boosts. |

## Integration Notes (How-to)

Active proposals should follow `proposal-engine` → `proposal-registry` → `proposal-executor`. The separately deployed `timelock` primitive is not currently wired into this path, and explicit integration remains pending. The community-voting and upgrade-controller stubs have no supported integration until their architecture and APIs are designed.

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/governance`

## Jargon Definition (Accessibility)
- **Proposal path**: The active sequence from proposal submission through registry and execution.
- **Source-only stub**: A preserved contract source file that is not included in active deployment.
- **Circuit breaker**: An emergency mechanism to pause protocol activity during a security incident.

## Status (Reference)
- Active path: `proposal-engine`, `proposal-registry`, and `proposal-executor`.
- Separate deployed primitive: `timelock` is available for delayed execution but is pending explicit integration with the active proposal path.
- Source-only stubs: `community-voting-engine.clar` and `upgrade-controller.clar` remain preserved but are excluded from active deployment pending architecture/API design.
- No voting facade or proxy-upgrade semantics are claimed by this module.
