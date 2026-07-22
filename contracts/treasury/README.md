# Treasury Module

## Overview (Explanation)
The Treasury module manages the protocol's capital allocation and revenue distribution. It implements the "Fiscal Dam" (CXIP-013) and provides one canonical scheduled protocol-fee settlement path. The phase-1 collector is designed to replace a designated legacy charge on a registered fee base, never to add a second charge to the same flow.

## Architecture (Explanation)
- **Canonical collection**: `protocol-fee-collector.clar` resolves 200/150/100 bps from an explicit activation burn-block height, enforces immutable source/stream/asset registration, pauses fail closed, prevents `(source, settlement-id)` replay, carries numerator residuals, and records native-unit accounting.
- **Canonical custody**: FT and STX settlements transfer payer -> `.protocol-fee-collector`. The collector never accepts a caller-supplied ingress destination.
- **Explicit routing**: Authorized admin or approved governance/timelock calls route collector-held assets only to the fixed `.operational-treasury` principal after treasury initialization. Each asset's routed total cannot exceed its collected total, and collection/routing totals remain separate.
- **Legacy compatibility**: `revenue-automation.clar` remains a legacy 100 bps surface until phase 2 migrates each approved source. Do not compose it with the canonical collector on the same fee base.
- **Registry**: `cxd-treasury.clar` maintains the global allocation policy.
- **Distribution**: `revenue-distributor.clar` executes token buy-backs and burns.
- **Integration Billing**: `integration-fee-collector.clar` remains a separate
  legacy integration settlement surface. It is not the phase-1 protocol-fee
  collector and is not evidence of downstream realization for collector events.
- **Fiscal allocations**: `fiscal-vault-oracle.clar` registers SBC beneficiaries,
  reserves period/category caps, and releases SIP-010 assets only from approved
  allocations.
- **Operating expenses**: `opex-vault.clar` holds SIP-010 deposits and runs a
  period-scoped, N-of-M expense approval workflow.

## Core Contracts (Reference)

### `revenue-automation.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `collect-revenue` | `(token <sip-010-ft-trait>) (amount uint) (payer principal)` | Calculates and transfers 1% fee. |
| `initialize` | `(admin principal)` | Sets the initial administrator (Admin only). |
| `set-admin` | `(new-admin principal)` | Updates the admin principal (Admin only). |

### `protocol-fee-collector.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `set-governance` | `(new-governance principal)` | Admin-only assignment of the immediate governance/emergency contract caller. Production deployments must use the approved DAO/timelock contract, not a wallet. |
| `set-authorized-source` | `(source principal) (authorized bool)` | Admin-only source authorization/revocation. Governance cannot rewrite source configuration. |
| `register-ft-stream` | `(source principal) (stream-id uint) (token principal) (route uint)` | Registers one immutable SIP-010 asset stream on collector ingress (admin only). |
| `register-stx-stream` | `(source principal) (stream-id uint) (route uint)` | Registers one immutable native STX stream on collector ingress (admin only). |
| `set-stream-active` | `(source principal) (stream-id uint) (asset-kind uint) (asset (optional principal)) (active bool)` | Activates or deactivates one registered stream (admin only); use `none` for native STX. |
| `pause` / `unpause` | `()` | Fail-closed settlement switch callable by admin or the configured governance contract. It does not change custody. |
| `set-activation-burn-height` | `(new-height uint)` | Sets the non-retroactive schedule anchor before the first settlement (admin only). |
| `settle-ft` | `(token <sip-010-ft-trait>) (stream-id uint) (eligible-fee-base uint) (settlement-id (buff 32))` | Calculates residual-aware fee and atomically transfers SIP-010 units from payer to `.protocol-fee-collector`. |
| `settle-stx` | `(stream-id uint) (eligible-fee-base uint) (settlement-id (buff 32))` | Calculates residual-aware fee and atomically transfers STX from payer to `.protocol-fee-collector`. |
| `route-ft` | `(token <sip-010-ft-trait>) (amount uint)` | After secure treasury initialization, routes still-unrouted collector-held FT custody to the immutable `.operational-treasury` destination (admin or governance contract). |
| `route-stx` | `(amount uint)` | After secure treasury initialization, routes still-unrouted collector-held STX custody to the immutable `.operational-treasury` destination (admin or governance contract). |
| `get-accounting` | `(source principal) (stream-id uint) (asset-kind uint) (asset (optional principal))` | Reads cumulative eligible, assessed, settled-at-collector-ingress, residual, and settlement-count state; use `none` for native STX. |
| `get-settlement` | `(source principal) (settlement-id (buff 32))` | Reads the immutable `(source, settlement-id)` record used by indexers. |
| `get-asset-accounting` | `(asset-kind uint) (asset (optional principal))` | Separates collected-at-collector totals from routed-to-treasury totals and route count; use `none` for native STX. |

The launch rate is 200 bps for the half-open interval
`[activation, activation + 52,560)`, growth is 150 bps for
`[activation + 52,560, activation + 157,680)`, and mature is 100 bps from
`activation + 157,680` onward. `52,560` is the 365-day approximation and
`157,680` is the three-year approximation at six ten-minute burn blocks per
hour. These are policy clocks, not exact wall-time dates.

Settlement arithmetic carries `base * rate-bps + prior-remainder` over the
10,000 denominator. A positive base that produces zero fee is still recorded
with its residual and does not attempt a zero-value transfer. Asset and route
identity cannot be replaced after registration, so residual/accounting state
cannot be erased by reconfiguration.

Authority is deliberately split. Configuration functions (`set-authorized-source`,
stream registration/activation, activation height, and governance assignment)
are admin-only: a direct admin EOA must satisfy `contract-caller = tx-sender =
admin`, while a configured admin contract must be the immediate
`contract-caller`. Pause/unpause and custody routes accept the admin or the
configured governance contract as the immediate caller. A governance wallet is
not a production role; deployments must assign the approved DAO/timelock or
emergency contract. Production source registrations should use contracts that
derive their own base from successful economic operations; an admin-authorized
EOA is an operational trust boundary, not trustless KPI proof.

Phase 1 does not authorize or wire DEX/lending sources and does not change
`conxian-access.clar`. Deployment wiring initializes
`.operational-treasury` before assigning the collector's approved timelock
governance caller; the collector also rejects every route until the treasury's
initialized flag is true. No source registration is included.

See [`docs/PROTOCOL_FEE_KPI_SPEC.md`](../../docs/PROTOCOL_FEE_KPI_SPEC.md) for
the indexed volume, fee, revenue, allocation, and USD-normalization schema.

### `cxd-treasury.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `rebalance` | `(treasury uint) (bounty uint) (lp uint) (grant uint) (buyback uint) (insurance uint)` | Updates 6-way split (Admin only). |
| `set-authorized-principals` | `(agent principal) (distributor principal)` | Sets authorized actors (Admin only). |
| `initialize` | `(new-admin principal)` | Initializes the treasury (Admin only). |
| `get-allocation-percentages` | `()` | Returns the current fiscal split. |
| `get-protocol-status` | `()` | Returns compliance and version status. |

### `revenue-distributor.clar` downstream route
| Function | Signature | Description |
|----------|-----------|-------------|
| `distribute-stx` | `(uint)` | Existing downstream STX route; not called by the phase-1 collector. |

The phase-1 collector does **not** call this route. It first transfers assessed
FT or STX from the payer to `.protocol-fee-collector`. A later explicit
`route-ft`/`route-stx` operation may forward only still-unrouted, collected
custody to the fixed `.operational-treasury` destination after initialization;
failed transfers roll back route accounting and events. Collection at ingress,
routed treasury inflow, realized downstream revenue, and Fiscal Dam allocation
remain separate evidence stages. This deliberate boundary removes the
collector-to-distributor-to-DEX dependency cycle.

### `conxian-vaults.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `deposit` | `(token <sip-010-ft-trait>) (amount uint)` | Deposits FT into the vault. |
| `withdraw` | `(token <sip-010-ft-trait>) (amount uint)` | Withdraws FT from the vault. |
| `get-balance` | `(user principal) (token principal)` | Returns user balance for token. |
| `get-protocol-status` | `()` | Returns compliance and version status. |

### `fiscal-vault-oracle.clar`
Fiscal category IDs are stable and documented in the contract: `u1` operations,
`u2` payroll, `u3` infrastructure, `u4` grants, `u5` liquidity, `u6` compliance,
`u7` reserves, and `u8` other. Caps, spending, and outstanding approved
commitments are keyed by `{ period, token, category }`; token amounts remain in
the token's native units and are never aggregated across assets.

| Function | Signature | Description |
|----------|-----------|-------------|
| `set-authorized-principals` | `(new-admin principal) (new-governance principal) (new-payment-forge principal)` | Configures admin, governance, and the compatibility release caller. |
| `set-current-period` | `(new-period uint)` | Advances the non-decreasing accounting period. |
| `register-sbc` | `(sbc (string-ascii 32)) (beneficiary principal)` | Registers the beneficiary used by the legacy release wrapper. |
| `set-category-cap` | `(token principal) (category uint) (cap uint)` | Sets the current period cap and rejects reductions below spent plus committed. |
| `create-allocation` | `(sbc (string-ascii 32)) (token principal) (category uint) (amount uint)` | Creates one pending allocation for an SBC/token pair. |
| `approve-allocation` | `(sbc (string-ascii 32)) (token principal)` | Approves and reserves the allocation against its category cap. |
| `cancel-allocation` | `(sbc (string-ascii 32)) (token principal)` | Cancels an active allocation and releases its commitment. |
| `release-funds-to-sbc` | `(sbc (string-ascii 32)) (amount uint) (token <sip-010-ft-trait>)` | Backwards-compatible payment-forge API; validates live balance, reserve, cap, commitment, and beneficiary before transfer. |
| `get-allocation` | `(sbc (string-ascii 32)) (token principal)` | Returns allocation status, amount, and released total. |
| `get-allocation-by-id` | `(allocation-id uint)` | Returns the immutable historical record for one allocation ID. |
| `get-active-allocation-id` | `(sbc (string-ascii 32)) (token principal)` | Returns the currently active allocation ID for a pair, if any. |
| `get-category-report` | `(period uint) (token principal) (category uint)` | Reports cap, spent, committed, and remaining capacity. |
| `get-treasury-health` | `(token principal)` | Returns the tracked per-token balance and reserve health. |
| `get-treasury-health-live` | `(token <sip-010-ft-trait>)` | Public live balance report for callers that need an external SIP-010 read. |

`release-funds-to-sbc` intentionally keeps the existing signature because
`agents/payment-forge.clar` calls it directly. Contract-to-contract
authorization uses `contract-caller`, so payment-forge can be rotated without
hardcoding a principal.

Allocation records are stored by monotonically increasing `allocation-id`.
The `{ sbc, token }` pair has separate active and latest-ID indexes: the active
index drives approval, cancellation, and release compatibility calls, while
the latest index keeps pair lookup useful after a terminal allocation. A
completed or cancelled allocation clears only the active index, so reusing a
pair creates a new ID without overwriting `get-allocation-by-id` history.

### Payment-forge settlement authorization
`agents/payment-forge.clar` keeps the public
`settle-sbc-obligation(sbc, amount, token)` signature, but settlement is
fail-closed unless `contract-caller` is either the configured settlement
authority or an active settlement operator. The initial authority is the
deploying `tx-sender`; no principal is hardcoded. The payment-forge admin can
rotate the authority with `set-settlement-authority` and can add or remove
operators with `set-settlement-operator`. These setters are admin-only and
accept both EOAs and contract principals. A contract integration must be
configured explicitly because authorization follows the immediate
`contract-caller`, not the transaction origin.

### `opex-vault.clar`
OPEX budgets and reservations are keyed by `{ period, token, category }`.
Deposits and expenses are tracked per token in native units. The administrator
is an implicit approver on a fresh deployment; additional approvers can be
configured and the threshold must remain within the active approver count.
Each new reservation is checked against the token's global tracked balance,
not only its category budget. Execution also rechecks the live token balance
against every outstanding reservation so settling one expense cannot make the
remaining reservations insolvent.

| Function | Signature | Description |
|----------|-----------|-------------|
| `set-authorized-principals` | `(new-admin principal) (new-governance principal)` | Configures administrative actors. |
| `set-approver` | `(approver principal) (active bool)` | Adds or removes a non-admin approver. |
| `set-approval-threshold` | `(threshold uint)` | Sets the required N-of-M approvals. |
| `deposit` | `(token <sip-010-ft-trait>) (amount uint)` | Transfers the declared amount into the vault and records the token balance. |
| `set-category-budget` | `(token principal) (category uint) (budget uint)` | Sets the current period budget without reducing below spent plus reserved. |
| `create-expense` | `(token <sip-010-ft-trait>) (category uint) (amount uint) (payee principal) (memo (string-ascii 128))` | Creates a compliant, budgeted, reserved pending expense. |
| `approve-expense` | `(expense-id uint)` | Records one approval; duplicate and submitter self-approval are rejected. |
| `execute-expense` | `(expense-id uint) (token <sip-010-ft-trait>)` | Rechecks threshold, compliance, budget, and balance, then transfers and settles accounting. |
| `cancel-expense` | `(expense-id uint)` | Cancels a pending expense and releases its reservation. |
| `get-expense` | `(expense-id uint)` | Returns the detailed expense record and status. |
| `get-category-report` | `(period uint) (token principal) (category uint)` | Reports budget, spent, reserved, and remaining budget. |
| `get-summary` | `(token principal)` | Reports balance, reserved, and available funds for one token. |
| `get-summary-live` | `(token <sip-010-ft-trait>)` | Reports tracked balance alongside the live SIP-010 balance and both solvency views. |

`execute-expense` accepts the SIP-010 trait again because Clarity does not
support dynamic contract calls from a stored principal. It verifies that the
provided token principal matches the recorded expense before transferring. It
also checks tracked balance, reservations, and the supplied token's live vault
balance at execution time. `get-summary` and the expense reports describe
tracked accounting; `get-summary-live` explicitly exposes live versus tracked
values. A direct token transfer into the vault can increase the live balance,
but it is not spendable tracked funding until recorded through `deposit`.

The admin is an implicit approver, so admin rotation is rejected when the new
principal is already an active approver. Approver removal is rejected if it
would leave the configured threshold above the remaining distinct eligible
approvers; duplicate and self-approval are rejected as well.

## Integration Examples (How-to)

### Rebalancing the Fiscal Dam
Authorized agents can rebalance the treasury split:
```clarity
(contract-call? .cxd-treasury rebalance u4000 u3000 u2000 u500 u500 u0)
```

### Depositing Assets to Vault
Users can secure their assets in Conxian Vaults:
```clarity
(contract-call? .conxian-vaults deposit .cxd-token u100000000)
```

### Funding OPEX and approving an expense
The creator and approver must be distinct immediate callers. Configure the
governance and approver principals before creating an expense, then submit and
approve from separate transactions. The addresses below are simnet-style
examples; replace them with the principals for the deployment.
```clarity
;; Run as the admin/deployer.
(contract-call? .opex-vault set-authorized-principals
  'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ
  'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
(contract-call? .opex-vault set-approver
  'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG true)
(contract-call? .opex-vault deposit .cxd-token u100000000)

;; Run as the configured governance principal (ST1SJ3D...).
(contract-call? .opex-vault create-expense
  .cxd-token u3 u25000000 tx-sender "infrastructure invoice")

;; Run as the distinct configured approver principal (ST2CY5...).
(contract-call? .opex-vault approve-expense u1)

;; Run as the configured governance principal or another authorized executor.
(contract-call? .opex-vault execute-expense u1 .cxd-token)
```

## Jargon (Accessibility)
- **Fiscal Dam**: A mechanism that captures protocol revenue and redirects it into various strategic buckets (Treasury, Buy-backs, etc.).
- **POL (Protocol-Owned Liquidity)**: Liquidity held and controlled by the protocol treasury rather than individual users.
- **Fail-closed**: A security design pattern where a system defaults to its most secure state (e.g., stopping transfers) if an error or anomaly is detected.
- **BME (Burn-and-Mint Equilibrium)**: An economic model where tokens are burned to create deflationary pressure while new tokens are minted based on protocol activity.
- **100 bps**: One hundred basis points, equivalent to 1%.

## Testing (How-to)
`npx vitest run --config vitest.config.ts tests/treasury/fiscal-vault-oracle.test.ts tests/treasury/opex-vault.test.ts`

## Status (Reference)
- Implementation: Fiscal allocation and OPEX infrastructure (v1.0.0)
- Standard: Hexagonal, 6-Way Fiscal Dam Split
