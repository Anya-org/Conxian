# Conxian Enterprise Module

## Overview (Explanation)
The Enterprise module provides industrial-grade financial primitives for institutional clients, including tiered account management, advanced order types, and structured finance instruments. It is designed to bridge traditional institutional requirements with the Conxian decentralized protocol.

## Architecture (Explanation)
The module follows a layered approach:
- **Enterprise API**: `enterprise-api.clar` manages institutional account registration and KYC logic.
- **Enterprise Facade**: `enterprise-facade.clar` provides a high-level interface for institutional operations.
- **Advanced Order Manager**: `advanced-order-manager.clar` serves as the institutional execution engine for TWAP/VWAP orders with integrated escrow.
- **Ops Loan Manager**: `ops-loan-manager.clar` enables structured B2B finance through Junior/Senior tranches.

## Enterprise Subscription MVP (Issue #503)

The subscription MVP is an STX-only, prepaid billing layer. Purchases and
renewals are explicit transactions; the protocol never pulls funds
automatically. The implementation deliberately keeps plan prices as owner
configuration rather than protocol constants, so publication and activation
are separate operations.

### Plan registry

`enterprise-plan-registry.clar` stores immutable versioned records keyed by
`{ plan-id, version }`. The four fixed tier identifiers are `u1` Bronze, `u2`
Silver, `u3` Gold, and `u4` Platinum. A published plan starts inactive and
becomes purchasable only after the owner explicitly activates it. Prices,
required KYC tier, and generic feature limits are set at publication time and
cannot be edited afterward; activation is the only mutable plan field.

| Function | Signature | Description |
|----------|-----------|-------------|
| `publish-plan` | `(uint uint uint uint uint uint)` | Publishes an inactive plan version with owner-supplied prices and KYC tier. |
| `publish-feature` | `(uint uint (string-ascii 32) bool uint)` | Adds one immutable generic feature/limit record to a plan version. |
| `set-plan-active` | `(uint uint bool)` | Explicitly activates or deactivates a published plan version. |
| `get-plan` | `(uint uint)` | Reads an optional versioned plan record. |
| `get-plan-feature` | `(uint uint (string-ascii 32))` | Reads an optional generic feature record for a plan version. |

### Subscription lifecycle

`enterprise-subscription.clar` stores one subscription per subscriber. Monthly
and annual billing periods are fixed at `u4320` and `u51840` burn blocks. An
active renewal extends from the existing `paid-through` height; a renewal at
or after expiry starts at the current `burn-block-height`. Cancellation is
period-end only: it marks the record without refunds, proration, credits, or
debt, and entitlement remains derived directly from
`burn-block-height < paid-through`.

| Function | Signature | Description |
|----------|-----------|-------------|
| `subscribe` | `(uint uint uint uint)` | Pays the selected active plan in full STX and creates the subscription. |
| `renew` | `(uint uint uint uint)` | Pays a new period explicitly and extends the subscription. |
| `cancel` | `()` | Marks an active subscription cancelled for period-end termination. |
| `get-subscription` | `(principal)` | Reads lifecycle state and current active status. |
| `is-entitled` | `(principal (string-ascii 32))` | Reads a generic feature entitlement. |
| `get-entitlement` | `(principal (string-ascii 32))` | Reads entitlement, limit, usage, remaining units, and paid-through. |
| `record-usage` | `(principal (string-ascii 32) (buff 32) uint)` | Records authorized consumer usage with a namespaced replay key and limit check. |

KYC tier and AML status are checked on every subscribe and renew through
`compliance-hooks.clar`. No PII is stored on-chain; feature identifiers are
generic strings and product-specific mappings remain in consumer contracts.
Only explicitly registered consumer contract principals may record usage.
`enterprise-facade.clar` exposes a generic forwarding boundary for that
consumer path without inventing product mappings.

### Gross-STX Fiscal Dam route

Every subscription payment enters the canonical route in full:

```text
enterprise-subscription
  -> revenue-automation.route-stx-revenue
  -> revenue-distributor.route-stx-revenue
  -> cxd-treasury.record-stx-revenue
```

The subscription contract first takes exact STX custody, calls the route, and
writes payment/subscription state only after the route succeeds. A successful
payment leaves zero STX in subscription, automation, and distributor custody.
`cxd-treasury` records an immutable `{ source, payment-id }` receipt and adds
the gross amount to six accounting buckets. The first five allocations use
safe floor arithmetic and the sixth bucket receives the integer remainder, so
bucket totals equal gross STX exactly. The buyback bucket is governed STX; the
contracts do not claim native-STX buyback execution.

## Core Contracts (Reference)

### `enterprise-api.clar`
Institutional account and KYC management.

| Function | Signature | Description |
|----------|-----------|-------------|
| `register-account` | `(tier uint)` | Registers a new institutional account with a specific tier. |
| `update-kyc-status` | `(user principal) (status bool)` | Updates the KYC compliance status for an institutional user. |
| `submit-advanced-order` | `(order-type (string-ascii 10)) (params (buff 128))` | Submits an advanced institutional order. |

### `enterprise-facade.clar`
High-level interface for enterprise services.

| Function | Signature | Description |
|----------|-----------|-------------|
| `set-enterprise-active` | `(active bool)` | Toggles the global operational status of the Enterprise module. |
| `register-account` | `(user principal) (tier uint) (limit uint)` | Registers an enterprise account with specified limits. |
| `submit-twap-order` | `(token-in principal) (token-out principal) (amount uint) (intervals uint) (interval-blocks uint)` | Submits an industrial-scale TWAP order. |

### `ops-loan-manager.clar`
Structured B2B finance.

| Function | Signature | Description |
|----------|-----------|-------------|
| `create-ops-loan` | `(loan-id (string-ascii 32)) (amount uint) (rate uint) (borrower principal)` | Creates a new structured operational loan. |

## Integration Examples (How-to)

### Creating an Institutional Account
```clarity
(contract-call? .enterprise-api register-account u2)
```

### Submitting a TWAP Order
```clarity
(contract-call? .enterprise-facade submit-twap-order
  .stx-token
  .cxd-token
  u1000000000
  u10
  u144
)
```

## Testing (How-to)
Verify structured finance and enterprise flows using the specialized test suite:
`npm test tests/apex-readiness.test.ts`

## Status (Reference)
- Implementation: Active Development (Apex v1.1.0 aligned)
- Audit Status: Internal Review (March 2026)
- Standards compliance: BIP-341, BIP-342, BIP-174
- Goal: Institutional liquidity bridging (CON-452)
