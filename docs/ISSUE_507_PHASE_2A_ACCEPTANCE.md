# Issue #507 — Phase 2A sBTC Vault Core

## Objective

Implement a canonical-token-bound sBTC custody and share-accounting core
without pretending to implement the BTC bridge, signer, peg repair, or yield
strategy portions of issue #507.

## Acceptance boundary

| Requirement | Acceptance condition |
|-------------|----------------------|
| Canonical token | Admin injects a SIP-010 token reference; every deposit/withdraw compares `(contract-of token)` with the stored principal. |
| Authorization | Admin-only token, cap, pause, and admin configuration uses the immediate `contract-caller`. |
| Amount safety | Deposit and withdrawal amounts must be nonzero and return explicit local errors. |
| Compliance | Existing regulatory-adapter trait is called for each custody action; adapter errors and negative responses fail closed. |
| Deposit accounting | First deposit is 1:1; later deposits mint floor-pro-rata shares and reject a zero-share result. |
| Withdrawal accounting | Requested amount is underlying sBTC; required shares use ceiling rounding and are burned only after live liquidity checks. |
| Cap and pause | Deposits cannot exceed the configured cap; pause blocks deposits and allocation but does not block compliant withdrawals. |
| Reconciliation | Totals, user shares, cap, pause state, configured token, asset values, and operation print records are available for review. |
| Strategy boundary | `allocate-to-strategy` always returns `ERR_STRATEGY_DISABLED` and moves no funds. |
| Deployment boundary | No official sBTC privileged mint/burn calls, BTC bridge calls, signer logic, peg repair, or yield strategy is added. |

## Accounting decisions

- `total-assets` is the accounted custody ledger, not an automatic sweep of the
  token's live balance. Accidental/direct token donations do not silently alter
  share price.
- A successful deposit increases both accounted assets and total shares after
  the token transfer succeeds.
- A successful withdrawal decreases both accounted assets and total shares
  after the vault confirms live token liquidity and the token transfer
  succeeds.
- Reconfiguration of the approved token is blocked while either accounted
  assets or shares are nonzero.

## Focused test coverage

`tests/vaults/sbtc-vault.test.ts` covers:

- admin/configuration authorization;
- canonical-token rejection;
- zero deposit and withdrawal amounts;
- compliance rejection;
- first and subsequent deposits with per-user shares;
- cap enforcement;
- paused deposit rejection and withdrawal continuity;
- insufficient assets and shares;
- successful withdrawal and token balances;
- active-vault token reconfiguration rejection; and
- strategy allocation failing closed.

## Remaining phases and risks

This slice is not production-ready and provides no deployment evidence. A
separate review is required before adding official sBTC bridge/redemption
integration, peg monitoring or repair, strategy custody, or loss accounting.
The live token balance is checked on withdrawal, but direct donations are not
included in `total-assets`; any future reconciliation or yield design must make
that policy explicit before changing share-price semantics.

## Local validation

The supported package test path is:

```bash
bash scripts/run-tests.sh tests/vaults/sbtc-vault.test.ts
```

Native `clarinet check` remains a separate environment check when the Clarinet
binary is installed.
