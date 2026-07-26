# Treasury Module

## Overview (Explanation)
The Treasury module manages the protocol's capital allocation and revenue distribution. It implements the "Fiscal Dam" (CXIP-013) and provides one canonical protocol-fee settlement engine with scheduled and narrowly fixed-100 stream policies. The phase-1 collector is designed to replace a designated legacy charge on a registered fee base, never to add a second charge to the same flow. The approved phase-2 source-custody API lets an authorized source prepay that collector-computed fee from its own custody without accepting a caller-selected debit or recipient.

## Architecture (Explanation)
- **Canonical collection**: `protocol-fee-collector.clar` keeps ordinary streams on the 200/150/100 burn-height schedule and supports one immutable fixed policy at exactly 100 bps for explicitly registered FT streams. It enforces immutable source/stream/asset/policy registration, pauses fail closed, prevents `(source, settlement-id)` replay, carries numerator residuals, and records native-unit accounting.
- **Canonical custody**: Payer-custody FT/STX settlements transfer payer -> `.protocol-fee-collector`. Source-custody settlements instead invoke an authenticated source callback with the collector-computed debit and fixed `.protocol-fee-collector` recipient; the collector proves the exact live-balance delta and leaves untracked excess untouched.
- **Explicit routing**: Authorized admin or approved governance/timelock calls route collector-held assets only to the fixed `.operational-treasury` principal after treasury initialization. Each asset's routed total cannot exceed its collected total, and collection/routing totals remain separate.
- **Legacy compatibility**: `revenue-automation.clar` retains the legacy 100 bps token fee path and also exposes the full gross-STX enterprise adapter. It remains a compatibility surface until phase 2 migrates each approved source; do not compose it with the canonical collector on the same fee base.
- **DEX custody boundary**: `concentrated-liquidity-pool.collect-protocol-fees` and `swap-aggregator.collect-protocol-fees` fail closed until dedicated, segregated DEX fee custody and canonical settlement exist. Neither entrypoint is extraction evidence, and neither may be composed with a legacy or canonical charge on the same base.
- **Registry**: `cxd-treasury.clar` maintains the global allocation policy.
- **Distribution**: `revenue-distributor.clar` routes token assets to the BME buy-back/burn path and accepts legacy or enterprise gross-STX routes into the Fiscal Dam; native STX buyback execution is not claimed.
- **Integration Billing**: `contracts/integrations/integration-fee-collector.clar` remains a separate legacy integration settlement surface. It sends 100% of settled STX through the distributor route; there is no partner split, 1% deduction, or direct bypass to `operational-treasury`. It is not the phase-1 protocol-fee collector and is not evidence of downstream realization for phase-1 collector events.
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
| `route-stx-revenue` | `(uint principal uint)` | Moves a full gross STX payment from an authorized source into `revenue-distributor`. |
| `authorize-stx-source` | `(principal)` | Authorizes an explicit source contract for the gross-STX adapter. |
| `set-admin` | `(new-admin principal)` | Updates the publish-time administrator; there is no `initialize` entrypoint. |

`revenue-automation` initializes `admin` directly to the contract publish
transaction sender. It exposes `set-admin` for the current admin handoff and
does not expose `initialize(admin)`. This contract is a legacy compatibility
surface; new fee-bearing lending flows must use `protocol-fee-collector` and
must not compose both paths on the same base.

### `protocol-fee-collector.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `set-governance` | `(new-governance principal)` | Admin-only assignment of the immediate governance/emergency contract caller. Production deployments must use the approved DAO/timelock contract, not a wallet. |
| `set-authorized-source` | `(source principal) (authorized bool)` | Admin-only source authorization/revocation. Governance cannot rewrite source configuration. |
| `register-ft-stream` | `(source principal) (stream-id uint) (token principal) (route uint)` | Registers one immutable SIP-010 asset stream on collector ingress (admin only). |
| `register-stx-stream` | `(source principal) (stream-id uint) (route uint)` | Registers one immutable native STX stream on collector ingress (admin only). |
| `register-ft-fixed-100-bps-stream` | `(source principal) (stream-id uint) (token principal) (route uint)` | Registers the sole fixed policy by construction: exactly 100 bps. No arbitrary-rate or policy mutation API exists. |
| `set-stream-active` | `(source principal) (stream-id uint) (asset-kind uint) (asset (optional principal)) (active bool)` | Activates or deactivates one registered stream (admin only); use `none` for native STX. |
| `pause` / `unpause` | `()` | Fail-closed settlement switch callable by admin or the configured governance contract. It does not change custody. |
| `set-activation-burn-height` | `(new-height uint)` | Sets the non-retroactive schedule anchor before the first settlement (admin only). |
| `settle-ft` | `(token <sip-010-ft-trait>) (stream-id uint) (eligible-fee-base uint) (settlement-id (buff 32))` | Calculates residual-aware fee and atomically transfers SIP-010 units from payer to `.protocol-fee-collector`. |
| `settle-stx` | `(stream-id uint) (eligible-fee-base uint) (settlement-id (buff 32))` | Calculates residual-aware fee and atomically transfers STX from payer to `.protocol-fee-collector`. |
| `preview-source-ft` | `(source principal) (stream-id uint) (asset principal) (eligible-fee-base uint)` | Read-only preview of the authenticated source/stream/asset schedule, assessed fee, and next residual. |
| `preview-source-stx` | `(source principal) (stream-id uint) (eligible-fee-base uint)` | Read-only native-STX preview using the same schedule and residual arithmetic as settlement. |
| `settle-source-ft` | `(source <protocol-fee-source-trait>) (token <sip-010-ft-trait>) (stream-id uint) (eligible-fee-base uint) (settlement-id (buff 32))` | Recomputes the fee, calls the source's exact-debit callback, and accepts custody only when the collector's live FT balance increases by exactly the assessed amount. |
| `settle-source-stx` | `(source <protocol-fee-source-trait>) (stream-id uint) (eligible-fee-base uint) (settlement-id (buff 32))` | Native-STX equivalent of `settle-source-ft`, including exact live-balance-delta proof. |
| `route-ft` | `(token <sip-010-ft-trait>) (amount uint)` | After secure treasury initialization, routes still-unrouted collector-held FT custody to the immutable `.operational-treasury` destination (admin or governance contract). |
| `route-stx` | `(amount uint)` | After secure treasury initialization, routes still-unrouted collector-held STX custody to the immutable `.operational-treasury` destination (admin or governance contract). |
| `recover-excess-ft` | `(token <sip-010-ft-trait>) (amount uint)` | Recovers only live FT balance above tracked collected-but-not-routed custody to the immutable `.operational-treasury` destination; does not change normal route/revenue totals. |
| `recover-excess-stx` | `(amount uint)` | Recovers only live STX balance above tracked collected-but-not-routed custody to the immutable `.operational-treasury` destination; does not change normal route/revenue totals. |
| `get-accounting` | `(source principal) (stream-id uint) (asset-kind uint) (asset (optional principal))` | Reads cumulative eligible, assessed, settled-at-collector-ingress, residual, and settlement-count state; use `none` for native STX. |
| `get-settlement` | `(source principal) (settlement-id (buff 32))` | Reads the immutable `(source, settlement-id)` record used by indexers. |
| `get-stream-rate-policy` | `(source principal) (stream-id uint)` | Returns scheduled/u0 for an ordinary stream, fixed/u100 for a fixed stream, and `none` when no stream exists. |
| `get-stream-rate-at-burn-height` | `(source principal) (stream-id uint) (height uint)` | Returns the exact `{rate-policy, rate-bps, phase}` tuple used for settlement. |
| `get-asset-accounting` | `(asset-kind uint) (asset (optional principal))` | Separates collected-at-collector totals from routed-to-treasury totals and route count; use `none` for native STX. |
| `get-excess-recovery-accounting` | `(asset-kind uint) (asset (optional principal))` | Reads separate excess-recovered totals by asset; use `none` for native STX. |

The launch rate is 200 bps for the half-open interval
`[activation, activation + 52,560)`, growth is 150 bps for
`[activation + 52,560, activation + 157,680)`, and mature is 100 bps from
`activation + 157,680` onward. `52,560` is the 365-day approximation and
`157,680` is the three-year approximation at six ten-minute burn blocks per
hour. These are policy clocks, not exact wall-time dates.

Ordinary registrations have no policy-map row and resolve as
`RATE_POLICY_SCHEDULED = u1`. Fixed registrations resolve as
`RATE_POLICY_FIXED = u2`, `rate-bps = u100`, and `PHASE_FIXED = u4` at every
height. Preview, settlement, accounting, immutable receipts, and events include
`rate-policy`, distinguishing fixed 100 bps from scheduled-mature 100 bps.
Collector error `u4126` denotes malformed policy state and fails closed.

Settlement arithmetic carries `base * rate-bps + prior-remainder` over the
10,000 denominator. A positive base that produces zero fee is still recorded
with its residual and does not attempt a zero-value transfer. Asset and route
identity cannot be replaced after registration, so residual/accounting state
cannot be erased by reconfiguration.

### Phase-2 source-custody settlement

Source custody is a callback protocol, not a second fee calculator. A source's
single atomic entrypoint derives the same read-only preview, stores a private
pending debit keyed by the current transaction payer, and immediately calls
`settle-source-ft` or `settle-source-stx` in the same call stack. A separate
externally callable prepare-then-consume flow is not a valid source pattern,
and a `block-height` equality is not proof of same-transaction state. The
collector authenticates the immediate source caller, recomputes the preview,
and passes only the assessed amount plus the fixed collector recipient to the
source callback. The callback must authenticate the collector, recipient,
asset, amount, and its private pending record before transferring. The
collector measures its live balance before and after the callback and requires
an exact delta equal to the assessed amount; underpay, overpay,
wrong-destination, no-transfer, callback, transfer, replay, or accounting
failures roll back the complete settlement. A zero-assessed settlement skips
the token/STX transfer but still consumes the authenticated pending record and
records residual/accounting state. Any pre-existing untracked collector excess
is not counted as a settlement.

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

The approved phase-2 lending slices migrate both active repayment engines,
`lending-manager.repay` and `lending-orchestrator.repay`. Their eligible base is
exactly the interest portion
`floor(amount * 1000 / 10000)`, and `total-reserves` receives interest net of the
collector fee. `lending-manager` remains scheduled; `lending-orchestrator`
binds only fixed-100 streams. Each source requires an immutable admin-controlled
asset-to-stream mapping and fails closed when the mapping is absent or
mismatched. Each uses its own monotonic nonce hashed to a fixed `(buff 32)`
settlement ID and does not expose a caller-controlled fee debit. Because a
static self-trait edge is not accepted by the current dependency graph, each
`repay` call includes the corresponding source trait and rejects any principal
other than that same lending contract. The legacy
`revenue-automation.collect-revenue` call is not composed with this path.

DEX migration remains explicitly deferred because concentrated-liquidity-pool
custody/execution is still stubbed. The 50/30/20 partnership split and
swap-aggregator equivalent fail closed rather than report success without
segregated custody. The 50/30/20 partnership split and deployment broadcasting
are not part of this implementation. The checked-in production deployment
plans and generator remain preflight-only and are not deployment or
deployability evidence.

The collector admin is the contract publish transaction sender; it has no
`initialize` entrypoint. A future checked bootstrap must initialize
`.operational-treasury`, configure the approved governance/timelock/multisig,
and call collector `set-admin(new-admin)` from the publish-time admin before
registering any source.
Retaining deployer admin is not production-ready. The deliberate immediate
caller model permits the configured admin contract to perform admin operations,
while governance and admin custody operations always use the immutable
`.operational-treasury` destination; no caller can redirect custody to an
arbitrary recipient. Direct deposits are recoverable only as live balance above
tracked collected-but-not-routed custody, with separate excess-recovered
accounting and events.

See [`docs/PROTOCOL_FEE_KPI_SPEC.md`](../../docs/PROTOCOL_FEE_KPI_SPEC.md) for
the indexed volume, fee, revenue, allocation, and USD-normalization schema.

### `cxd-treasury.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `rebalance` | `(treasury uint) (bounty uint) (lp uint) (grant uint) (buyback uint) (insurance uint)` | Updates the 6-way split for authorized admin/agent callers, enforcing the configured LP minimum, insurance maximum, and exact 10,000-bps sum. |
| `set-authorized-principals` | `(agent principal) (distributor principal)` | Sets authorized actors (Admin only). |
| `set-bounds` | `(uint uint)` | Sets the existing LP-minimum and insurance-maximum safety bounds (Admin only). |
| `authorize-stx-source` | `(principal)` | Authorizes a source contract for gross-STX receipts. |
| `revoke-stx-source` | `(source principal)` | Revokes the authorized STX source (Admin only). |
| `record-stx-revenue` | `(principal uint uint)` | Receives distributor STX, snapshots the six-way split, and records an immutable receipt. |
| `record-diverted-claim` | `(token principal) (amount uint)` | Records a diverted claim for priority stakers. |
| `set-stx-bucket-recipient` | `(uint principal)` | Configures one governed destination for a stable bucket ID (Admin only). |
| `clear-stx-bucket-recipient` | `(uint)` | Removes a bucket destination and returns releases to fail-closed state. |
| `release-stx-bucket` | `(uint uint uint)` | Transfers custody from one configured bucket once per `{bucket, release-id}` and decrements only after success. |
| `get-stx-receipt` | `(principal uint)` | Reads one immutable source/payment receipt. |
| `get-stx-bucket-balances` | `()` | Reads the six accumulated gross-STX accounting buckets. |
| `get-stx-bucket-balance` | `(bucket uint)` | Reads the accumulated balance of a specific gross-STX bucket. |
| `get-stx-bucket-recipient` | `(bucket uint)` | Reads the configured recipient for a specific bucket. |
| `get-stx-accounting` | `()` | Proves gross receipts equal current buckets plus governed releases. |
| `get-stx-release-receipt` | `(uint uint)` | Reads one immutable bucket release receipt. |
| `get-policy-version` | `()` | Reads the monotonically increasing allocation policy version. |
| `initialize` | `(new-admin principal)` | Initializes the treasury (Admin only). |
| `set-admin` | `(new-admin principal)` | Updates the administrative principal. |
| `get-allocation-percentages` | `()` | Returns the current fiscal split. |
| `get-bounds` | `()` | Reads the safety boundaries configured for the LP-minimum and insurance-maximum limits. |
| `get-total-gross-stx-received` | `()` | Reads the lifetime gross STX receipts received. |
| `get-total-released-stx` | `()` | Reads the lifetime gross STX released. |
| `get-protocol-status` | `()` | Returns compliance and version status. |

### `revenue-distributor.clar` routes
| Function | Signature | Description |
|----------|-----------|-------------|
| `initialize` | `(principal)` | Performs the deployer/admin-authorized administrator handoff exactly once. |
| `set-admin` | `(principal)` | Updates the administrator through the current-admin-only handoff path. |
| `distribute-stx` | `(uint)` | Compatibility route for authorized legacy sources; it terminates in the Fiscal Dam. |
| `route-stx-revenue` | `(uint principal uint)` | Enterprise adapter hop callable only by configured `revenue-automation`. |

The collector does **not** call these routes during settlement. Payer-custody
settlements transfer assessed FT or STX from the payer to
`.protocol-fee-collector`; source-custody settlements obtain the same assessed
amount through the authenticated source callback. A later explicit
`route-ft`/`route-stx` operation may forward only still-unrouted, collected
custody to the fixed `.operational-treasury` destination after initialization;
`recover-excess-ft`/`recover-excess-stx` may forward only unaccounted live
balance to that same fixed destination. Failed transfers roll back route or
recovery accounting and events. Collection at ingress,
routed treasury inflow, realized downstream revenue, and Fiscal Dam allocation
remain separate evidence stages. This deliberate boundary removes the
collector-to-distributor-to-DEX dependency cycle.

The compatibility `distribute-stx` route is used by
`integration-fee-collector`, while the enterprise `route-stx-revenue` route is
called by `revenue-automation` after source authorization. Both routes move
gross STX through `cxd-treasury`; neither uses `swap-router` for STX and neither
bypasses the six-way Fiscal Dam. The canonical settled-STX endpoint for these
routes is `cxd-treasury`; older descriptions that said settled STX ends at
`swap-router` are obsolete.

### Enterprise gross-STX route

Subscription payments use the following custody sequence:

```text
source contract -> revenue-automation -> revenue-distributor -> cxd-treasury
```

Each hop authenticates its immediate caller and authorized source. The
subscription contract records payment state only after the final hop succeeds,
so a route failure rolls back custody and accounting together. Receipts are
replay-protected by source and payment ID. Allocation percentages are read at
payment time, snapshotted into each receipt, and identified by a monotonically
increasing policy version; the first five buckets use safe floor math and the
sixth bucket receives all integer remainder. The buyback allocation is an STX
accounting bucket, not a claim that native-STX buyback execution exists.

### Governed STX bucket release

The six stable bucket IDs are `u1` treasury, `u2` bounty, `u3` LP, `u4` grant,
`u5` buyback, and `u6` insurance. No recipient is preconfigured in production
plans. Governance must configure an audited recipient with
`set-stx-bucket-recipient` before `release-stx-bucket` can transfer custody;
otherwise the contract fails closed. Release IDs are unique per bucket,
over-release is rejected, and `get-stx-accounting` preserves total gross
receipt evidence after release. Buyback remains only a governed STX bucket
until a separate native-STX adapter is approved.

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

### @desc Payment-forge settlement authorization description
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
