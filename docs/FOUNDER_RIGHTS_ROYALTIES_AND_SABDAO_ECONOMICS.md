# Founder rights, royalties, and SAB/DAO economics (CON-424)

This document captures a **public-safe, protocol-level** definition of:

- founder/operator rights (control vs cashflow)
- token / rights inventory
- protocol fee capture + allocation surfaces
- SAB wallet ownership boundaries
- a concrete gap list for what still blocks enforceable, on-chain income

It is intentionally written as **policy + engineering requirements**, not a promise of value, payout, or timeline.

## Canonical rights model

Separate rights into three distinct surfaces:

1. **Control (governance):** who can change policy (fees, splits, authorized reporters, admin rotation).
2. **Cashflow (royalty / recovery):** who receives a bounded, rules-based share of protocol revenue.
3. **Talent incentives (builders/operators):** how contributors earn without relying on discretionary founder action.

### Founder vs operator

- **Founder** is an **economic beneficiary** under defined rules.
- **Operator** is an **execution role** (keepers/agents), and should be replaceable and narrowly permissioned.

### Founder’s Cut (royalty)

**Canonical semantics (decision-ready):**

- **Rate:** `10 bps` (`0.1%`).
- **Semantics:** a **carve-out from captured protocol fees**, not an additive fee on users.
- **Asset:** recorded **in-kind** (per fee asset), with optional conversion policy downstream.
- **Recipient:** a **contract-level vault** (not a personal wallet), optionally vesting-enabled.

## Wallet custody boundary (bootstrap vs SAB vs DAO)

The custody model should be staged:

1. **Bootstrap wallet (temporary):** may be used to deploy and initialize the system, but must not be treated as the durable treasury or royalty recipient.
2. **SAB/system wallets (durable custody):** protocol funds accrue to contract principals with narrow, auditable methods.
3. **DAO/timelock (policy control):** parameter changes (fees/splits/authorized reporters/admin rotation) are gated behind governance, not operator discretion.

## Token / rights inventory (current pinned Conxian contracts)

The pinned Conxian protocol contract set (submodule `Conxian/`) defines a **multi-token + NFT** surface:

- SIP-010 FTs: `CXD`, `CXVG`, `CXS`, `CXLP`, `CXTR`
- SIP-009 NFT: `CXLP position` (concentrated liquidity position)

These are “protocol rights” assets. STX, sBTC, and stablecoins are settlement/collateral rails, not governance rights by themselves.

## Canonical fee capture and revenue routing (target)

The system should treat fee handling as two separate steps:

1. **Fee accrual:** fees are provably accumulated under protocol-controlled custody.
2. **Fee conversion + allocation:** keepers/agents convert and route according to governance policy.

Target flow (high level):

```
user tx
  -> module fee is charged (swap/lending/etc)
  -> protocol fee balance accrues in a fee vault / treasury contract
  -> allocation policy applies:
      - Founder’s Cut carve-out -> founder vault (off-the-top from captured protocol fees)
      - from the remaining captured protocol fees:
        - reserve / continuity
        - operating treasury
        - contributor incentives
        - optional buyback/burn sink (BME)
```

## Fastest route to real on-chain income (minimal viable operating path)

The fastest path is to make **one fee surface** (swaps) real end-to-end:

1. **Make fee accrual enforceable**
   - Ensure swaps actually transfer the fee portion into a protocol-controlled vault (not just print events).
   - Ensure the vault is a system wallet implemented as a contract principal, not any standard principal (including personal or multisig wallets).
2. **Use keeper-driven conversion rather than hardcoding swap paths**
   - Use the existing keeper runbook + script: `docs/PROTOCOL_FEE_SWEEP_RUNBOOK.md` and `scripts/protocol-fee-sweep.ts`.
3. **Start with a single, conservative allocation policy**
   - Reserve + ops continuity before discretionary sinks.
   - Founder’s Cut remains bounded and non-discretionary via the vault.

Note: this repo’s canonical gate currently marks CSF mainnet launch as `No-Go` (see `docs/CSF_MAINNET_READINESS_GATE.md`). Treat that gate as the “is it safe to run this on mainnet?” decision boundary.

## What’s missing / not enforceable yet (gap list)

This is a concrete, code-anchored list of gaps in the pinned `Conxian/` contracts.

### Fee accrual is mostly telemetry today

- `Conxian/contracts/dex/swap-router.clar`
  - calls `bme-engine/register-fee-activity`, but does not fail the swap if registration fails.
- `Conxian/contracts/core/bme-engine.clar`
  - requires authorized reporters, but no default reporters are set.
  - `swap-and-burn` is explicitly simulated (prints an event; does not execute swaps).

### Revenue automation is stubbed

- `Conxian/contracts/revenue-automation.clar`
  - `claim-revenue` is a stub (`print` + `(ok true)`), and does not implement “tax sweep” or Founder’s Cut.

### Distribution logic is incomplete

- `Conxian/contracts/treasury/revenue-distributor.clar`
  - `distribute-stx` is stubbed (`(ok true)`).
  - no Founder’s Cut carve-out is applied.

### Founder and ops vaults are not yet production-safe

- `Conxian/contracts/treasury/founder-vault.clar`
  - allocation storage exists, but there is no claim path in this version.
  - uses hardcoded testnet-style principals (`ST...`).
- `Conxian/contracts/treasury/opex-vault.clar`
  - `deposit` is stubbed and does not actually custody or route funds.

### Mainnet principals + custody boundaries are unresolved

- Multiple contracts in `Conxian/contracts/**` still hardcode `ST...` principals.
- Until mainnet principals are defined and deployed, “who receives what” cannot be made enforceable.

## Open decisions to finalize (so this becomes enforceable)

1. **Founder’s Cut conversion policy:** always in-kind vs optional conversion to a single denomination asset (e.g. CXD).
2. **Primary revenue model:** whether BME is the canonical sink for captured fees, and what (if any) “budget allocator” remains for ops/incentives.
3. **Founder recovery facility (optional):** whether founder bootstrap reimbursement exists at all, and if so, the cap + payout ordering rules (must remain governance-controlled).
