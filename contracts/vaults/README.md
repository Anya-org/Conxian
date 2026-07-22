# Vaults Module

## Scope

The vaults module contains custody and accounting components. The Phase 2A
slice implemented for issue #507 is intentionally narrow: `sbtc-vault.clar`
holds already-issued canonical sBTC and tracks user shares. It does not bridge
BTC, mint or burn sBTC, repair a peg, or run a yield strategy.

## `sbtc-vault.clar`

### Configuration

Configuration is immediate-caller admin-only and uses runtime principal
injection rather than hardcoded deployment addresses:

| Function | Signature | Behavior |
|----------|-----------|----------|
| `set-approved-token` | `(set-approved-token (token <sip-010-ft-trait>))` | Stores `(contract-of token)` exactly once from the initial `none` state while assets and shares are zero. The token is immutable afterward; there is no rescue or sweep path. |
| `set-deposit-cap` | `(set-deposit-cap (new-cap uint))` | Sets the maximum accounted assets; the cap must be nonzero and cannot be below current assets. |
| `set-paused` | `(set-paused (new-paused bool))` | Blocks deposits and allocation when true, while withdrawals remain available. |
| `set-admin` | `(set-admin (new-admin principal))` | Transfers configuration authority. |

### Custody API

The contract implements `.vault-traits.vault-trait` with the trait's
`(amount, token)` argument order:

| Function | Signature | Behavior |
|----------|-----------|----------|
| `deposit` | `(deposit (amount uint) (token <sip-010-ft-trait>))` | Requires the configured token, a positive amount, an open vault, a configured cap, and a compliant caller. It reads the live balance before and after transfer and commits shares/accounting only when the live delta is at least `amount`. |
| `withdraw` | `(withdraw (amount uint) (token <sip-010-ft-trait>))` | Treats `amount` as underlying sBTC, rejects aggregate insolvency before checking the requested amount, and transfers out only after burning the caller's required shares. It remains available while paused. |
| `allocate-to-strategy` | `(allocate-to-strategy (strategy principal) (amount uint))` | Always returns `ERR_STRATEGY_DISABLED`; no strategy custody path exists in Phase 2A. |

### Share accounting

- The first positive deposit mints shares one-for-one with assets.
- Later deposits mint `floor(amount * total-shares / total-assets)` shares.
  A deposit that floors to zero shares is rejected, preventing silent loss.
- Withdrawals request underlying assets and burn
  `ceil(amount * total-shares / total-assets)` shares. This conservative
  rounding prevents under-burning a user's liability.
- `total-assets` is the accounted custody ledger. Direct token donations are
  visible only in the token's live balance and do not silently change the
  share price. Phase 2A has no generic rescue or sweep path, so future
  donation synchronization requires a separately approved accounting design.
- Before any withdrawal transfer, the live token balance must be at least
  `total-assets`; otherwise the call returns `ERR_INSOLVENT` and no withdrawal
  is serviced.
- A deposit that returns success from the token but increases the live balance
  by less than the requested amount returns `ERR_DEPOSIT_RECONCILIATION` and
  preserves vault accounting.
- Every successful deposit and withdrawal emits the token, user, asset amount,
  share amount, and post-operation totals. The read-only accounting getters
  expose the same reconciliation fields.

### Security boundary

- The approved token is compared by `(contract-of token)` on every state-changing
  custody call.
- The approved token is configured once from the initial unconfigured state and
  cannot be replaced after configuration, even while accounting is zero.
- Compliance calls use the existing regulatory-adapter trait and convert both
  adapter errors and negative responses into explicit local errors.
- Token transfer and balance-call failures are normalized to explicit errors;
  the vault has no `unwrap-panic` path.
- The emergency pause blocks new deposits and allocation but intentionally does
  not freeze compliant withdrawals.
- No BTC bridge, signer, DLC/BitVM2 proof, oracle, peg repair, mint, burn, or
  yield allocation is treated as settlement or implemented here.

## Testing

The focused suite uses the real transfer/balance behavior of the existing
`mock-token` fixture and configures it as the canonical token only inside
simnet tests. It also uses the Clarinet SDK's ad hoc `deployContract` API for
an inline, non-manifest adversarial SIP-010 fixture that under-credits a
transfer or reports an insolvent live balance; no test fixture is added to the
production manifests:

```bash
bash scripts/run-tests.sh tests/vaults/sbtc-vault.test.ts
```

The current custody-only state transitions keep the initial asset/share ratio
at 1:1: strategy allocation is disabled and direct donations are not synced
into `total-assets`. The focused tests therefore do not claim non-1:1 floor or
ceiling rounding coverage. A future strategy or donation-sync phase must add a
safe harness and its invariant tests before making that claim.

## Status

Phase 1/2A merged via [PR #546](https://github.com/Conxian/Conxian/pull/546) at
commit `11d598c2ec098088032d1e78f608887dd8441d5b`. The merged implementation
remains custody-only: it is not official bridge, signer, peg, yield,
deployment, or settlement proof. Later phases must separately approve official
sBTC bridge/redemption integration, peg monitoring/repair, and any strategy
custody and loss-accounting design.
