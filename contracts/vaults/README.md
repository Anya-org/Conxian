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
| `set-approved-token` | `(set-approved-token (token <sip-010-ft-trait>))` | Stores `(contract-of token)` as the canonical token. Reconfiguration is blocked while assets or shares remain. |
| `set-deposit-cap` | `(set-deposit-cap (new-cap uint))` | Sets the maximum accounted assets; the cap must be nonzero and cannot be below current assets. |
| `set-paused` | `(set-paused (new-paused bool))` | Blocks deposits and allocation when true, while withdrawals remain available. |
| `set-admin` | `(set-admin (new-admin principal))` | Transfers configuration authority. |

### Custody API

The contract implements `.vault-traits.vault-trait` with the trait's
`(amount, token)` argument order:

| Function | Signature | Behavior |
|----------|-----------|----------|
| `deposit` | `(deposit (amount uint) (token <sip-010-ft-trait>))` | Requires the configured token, a positive amount, an open vault, a configured cap, and a compliant caller before transferring sBTC in. |
| `withdraw` | `(withdraw (amount uint) (token <sip-010-ft-trait>))` | Treats `amount` as underlying sBTC, checks live token liquidity, and transfers out after burning the caller's required shares. It remains available while paused. |
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
  share price.
- Every successful deposit and withdrawal emits the token, user, asset amount,
  share amount, and post-operation totals. The read-only accounting getters
  expose the same reconciliation fields.

### Security boundary

- The approved token is compared by `(contract-of token)` on every state-changing
  custody call.
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
simnet tests:

```bash
bash scripts/run-tests.sh tests/vaults/sbtc-vault.test.ts
```

## Status

Phase 2A is implemented locally on the issue #507 branch. This is not a
production-readiness or deployment claim. Later phases must separately approve
official sBTC bridge/redemption integration, peg monitoring/repair, and any
strategy custody and loss-accounting design.
