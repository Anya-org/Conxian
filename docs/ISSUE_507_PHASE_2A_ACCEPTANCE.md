# Issue #507 — Phase 2A sBTC Vault Core

## Objective

Implement a canonical-token-bound sBTC custody and share-accounting core
without pretending to implement the BTC bridge, signer, peg repair, or yield
strategy portions of issue #507.

## Acceptance boundary

| Requirement | Acceptance condition |
|-------------|----------------------|
| Canonical token | Admin injects a SIP-010 token reference exactly once from the initial `none` state while assets and shares are zero; every deposit/withdraw compares `(contract-of token)` with the immutable stored principal. |
| Authorization | Admin-only token, cap, pause, and admin configuration uses the immediate `contract-caller`. |
| Amount safety | Deposit and withdrawal amounts must be nonzero and return explicit local errors. |
| Compliance | Existing regulatory-adapter trait is called for each custody action; adapter errors and negative responses fail closed. |
| Deposit accounting | First deposit is 1:1; later deposits mint floor-pro-rata shares and reject a zero-share result. The live token balance is read before and after transfer, and accounting commits only when the delta is at least the requested amount. |
| Withdrawal accounting | Requested amount is underlying sBTC; aggregate live solvency is checked before the requested amount, then required shares use ceiling rounding and are burned only after the live-liquidity checks. |
| Cap and pause | Deposits cannot exceed the configured cap; pause blocks deposits and allocation but does not block compliant withdrawals. |
| Reconciliation | Totals, user shares, cap, pause state, configured token, asset values, `get-accounting`, and operation print records are available for review. |
| Direct donations | Live token donations are not silently swept into `total-assets` or share price; no generic rescue/sweep path exists in Phase 2A. |
| Strategy boundary | `allocate-to-strategy` always returns `ERR_STRATEGY_DISABLED` and moves no funds. |
| Deployment boundary | No official sBTC privileged mint/burn calls, BTC bridge calls, signer logic, peg repair, or yield strategy is added. |

## Accounting decisions

- `total-assets` is the accounted custody ledger, not an automatic sweep of the
  token's live balance. Accidental/direct token donations do not silently alter
  share price.
- A successful deposit increases both accounted assets and total shares only
  after the token transfer succeeds and the live balance delta is reconciled.
- A successful withdrawal decreases both accounted assets and total shares
  after the vault confirms aggregate live solvency, requested liquidity, and
  the token transfer succeeds.
- The approved token is immutable after the one-time initial configuration;
  zero accounting does not reopen configuration.

## Focused test coverage

`tests/vaults/sbtc-vault.test.ts` covers:

- admin/configuration authorization;
- canonical-token rejection;
- zero deposit and withdrawal amounts;
- compliance rejection;
- first and subsequent deposits with per-user shares;
- deposit receipt reconciliation failure with a test-only under-crediting SIP-010 fixture;
- cap enforcement;
- paused deposit rejection and withdrawal continuity;
- insufficient assets and shares;
- successful withdrawal and token balances;
- one-time token configuration and reconfiguration rejection;
- admin transfer, old-admin rejection, and new-admin success;
- aggregate insolvency rejection with a test-only live-balance reporting fixture;
- `get-accounting` and operation print-event assertions; and
- strategy allocation failing closed.

## Remaining phases and risks

This slice is not production-ready and provides no deployment evidence. A
separate review is required before adding official sBTC bridge/redemption
integration, peg monitoring or repair, strategy custody, or loss accounting.
The live token balance is checked on withdrawal, but direct donations are not
included in `total-assets`; any future reconciliation or yield design must make
that policy explicit before changing share-price semantics. Because strategy
allocation is disabled and donation synchronization is deliberately absent,
the current state transitions remain at a 1:1 asset/share ratio. The focused
suite does not claim non-1:1 floor/ceiling rounding coverage; a future strategy
or donation-sync phase must add a safe harness and invariant tests.

The custody slice also does not use `operational-treasury`. Its post-deploy
sequence is local to the vault: `set-approved-token` once, `set-deposit-cap`,
optional `set-paused`, and optional `set-admin` handoff.

Authoritative public sBTC references:

- [Stacks sBTC overview](https://docs.stacks.co/learn/sbtc)
- [sBTC Clarity contracts](https://docs.stacks.co/learn/sbtc/clarity-contracts)
- [Clarinet sBTC integration](https://docs.stacks.co/clarinet/integrations/sbtc)
- [Stacks mainnet and testnets](https://docs.stacks.co/learn/network-fundamentals/mainnet-and-testnets)
- [stacks-sbtc source repository](https://github.com/stacks-sbtc/sbtc)

## Local validation

The supported package test path is:

```bash
bash scripts/run-tests.sh tests/vaults/sbtc-vault.test.ts

# Compile/bootstrap regression plus the focused vault suite
bash scripts/run-tests.sh tests/check-compile.test.ts tests/vaults/sbtc-vault.test.ts
```

Native `clarinet check` remains a separate environment check when the Clarinet
binary is installed.
