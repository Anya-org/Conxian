# Treasury Module

## Overview (Explanation)
The Treasury module manages the protocol's capital allocation and revenue distribution. It implements the "Fiscal Dam" (CXIP-013) and enforces mandatory protocol fees via the Revenue Automation engine.

## Architecture (Explanation)
- **Automation**: `revenue-automation.clar` enforces a non-negotiable 100 bps protocol fee.
- **Registry**: `cxd-treasury.clar` maintains the global allocation policy.
- **Distribution**: `revenue-distributor.clar` executes token buy-backs and burns.
- **Integration Billing**: `integration-fee-collector.clar` sends 100% of
  settled STX integration fees through the same distributor route; there is no
  partner split or direct bypass to `operational-treasury`.
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

### `cxd-treasury.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `rebalance` | `(treasury uint) (bounty uint) (lp uint) (grant uint) (buyback uint) (insurance uint)` | Updates 6-way split (Admin only). |
| `set-authorized-principals` | `(agent principal) (distributor principal)` | Sets authorized actors (Admin only). |
| `initialize` | `(new-admin principal)` | Initializes the treasury (Admin only). |
| `get-allocation-percentages` | `()` | Returns the current fiscal split. |
| `get-protocol-status` | `()` | Returns compliance and version status. |

### `revenue-distributor.clar` integration route
| Function | Signature | Description |
|----------|-----------|-------------|
| `distribute-stx` | `(uint)` | Existing STX route used by the collector under contract context. |

The collector calls the existing route from contract custody after receiving
an exact settlement from the configured payer. No distributor setter or
separate integration route is added; the distributor remains the system of
record for downstream revenue routing and CXIP-013 behavior.

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
| `get-category-report` | `(period uint) (token principal) (category uint)` | Reports cap, spent, committed, and remaining capacity. |
| `get-treasury-health` | `(token principal)` | Returns the tracked per-token balance and reserve health. |
| `get-treasury-health-live` | `(token <sip-010-ft-trait>)` | Public live balance report for callers that need an external SIP-010 read. |

`release-funds-to-sbc` intentionally keeps the existing signature because
`agents/payment-forge.clar` calls it directly. Contract-to-contract
authorization uses `contract-caller`, so payment-forge can be rotated without
hardcoding a principal.

### `opex-vault.clar`
OPEX budgets and reservations are keyed by `{ period, token, category }`.
Deposits and expenses are tracked per token in native units. The administrator
is an implicit approver on a fresh deployment; additional approvers can be
configured and the threshold must remain within the active approver count.

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

`execute-expense` accepts the SIP-010 trait again because Clarity does not
support dynamic contract calls from a stored principal. It verifies that the
provided token principal matches the recorded expense before transferring.

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
```clarity
(contract-call? .opex-vault deposit .cxd-token u100000000)
(contract-call? .opex-vault create-expense
  .cxd-token u3 u25000000 tx-sender "infrastructure invoice")
(contract-call? .opex-vault approve-expense u1)
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
