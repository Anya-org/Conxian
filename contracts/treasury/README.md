# Treasury Module

## Overview (Explanation)
The Treasury module manages the protocol's capital allocation and revenue distribution. It implements the "Fiscal Dam" (CXIP-013) and enforces mandatory protocol fees via the Revenue Automation engine.

## Architecture (Explanation)
- **Automation**: `revenue-automation.clar` retains the legacy 100 bps token
  fee path and also exposes the full gross-STX enterprise adapter.
- **Registry**: `cxd-treasury.clar` maintains the global allocation policy.
- **Distribution**: `revenue-distributor.clar` executes token buy-backs and burns
  for token routes; native STX buyback execution is not claimed.
- **Integration Billing**: `integration-fee-collector.clar` sends 100% of
  settled STX integration fees through the same distributor route; there is no
  partner split, 1% deduction, or direct bypass to `operational-treasury`.
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
| `initialize` | `(admin principal)` | Sets the initial administrator (Admin only). |
| `set-admin` | `(new-admin principal)` | Updates the admin principal (Admin only). |

### `cxd-treasury.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `rebalance` | `(treasury uint) (bounty uint) (lp uint) (grant uint) (buyback uint) (insurance uint)` | Updates the 6-way split for authorized admin/agent callers, enforcing the configured LP minimum, insurance maximum, and exact 10,000-bps sum. |
| `set-authorized-principals` | `(agent principal) (distributor principal)` | Sets authorized actors (Admin only). |
| `set-bounds` | `(uint uint)` | Sets the existing LP-minimum and insurance-maximum safety bounds (Admin only). |
| `authorize-stx-source` | `(principal)` | Authorizes a source contract for gross-STX receipts. |
| `record-stx-revenue` | `(principal uint uint)` | Receives distributor STX, snapshots the six-way split, and records an immutable receipt. |
| `set-stx-bucket-recipient` | `(uint principal)` | Configures one governed destination for a stable bucket ID (Admin only). |
| `clear-stx-bucket-recipient` | `(uint)` | Removes a bucket destination and returns releases to fail-closed state. |
| `release-stx-bucket` | `(uint uint uint)` | Transfers custody from one configured bucket once per `{bucket, release-id}` and decrements only after success. |
| `get-stx-receipt` | `(principal uint)` | Reads one immutable source/payment receipt. |
| `get-stx-bucket-balances` | `()` | Reads the six accumulated gross-STX accounting buckets. |
| `get-stx-accounting` | `()` | Proves gross receipts equal current buckets plus governed releases. |
| `get-stx-release-receipt` | `(uint uint)` | Reads one immutable bucket release receipt. |
| `get-policy-version` | `()` | Reads the monotonically increasing allocation policy version. |
| `initialize` | `(new-admin principal)` | Initializes the treasury (Admin only). |
| `get-allocation-percentages` | `()` | Returns the current fiscal split. |
| `get-protocol-status` | `()` | Returns compliance and version status. |

### `revenue-distributor.clar` STX routes
| Function | Signature | Description |
|----------|-----------|-------------|
| `distribute-stx` | `(uint)` | Compatibility route for authorized legacy sources; it now terminates in the Fiscal Dam. |
| `route-stx-revenue` | `(uint principal uint)` | Enterprise adapter hop callable only by configured `revenue-automation`. |

The collector calls the existing route from contract custody after receiving
an exact settlement from the configured payer. Both the compatibility and
enterprise paths move gross STX through `cxd-treasury`; neither uses
`swap-router` for STX and neither bypasses the six-way Fiscal Dam.
The canonical settled-STX endpoint is `cxd-treasury`; older descriptions that
said settled STX ends at `swap-router` are obsolete.

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
