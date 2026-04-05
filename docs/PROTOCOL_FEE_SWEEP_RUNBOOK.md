# Protocol fee sweep runbook (ALEX conversion)

This runbook defines a production-safe default for converting protocol-fee balances into a small set of treasury denomination assets using ALEX as the execution venue.

## Core principle

Separate:

1. **Fee accrual** (on-chain, provable custody under Conxian control)
2. **Fee conversion** (keeper-driven, dynamic routing based on current liquidity)

This keeps the protocol’s revenue surface auditable while avoiding brittle on-chain hardcoding of pool hops.

## Invariants (do not violate)

- **Protocol fees are not bounty funding.** The bounty payout wallet must still only receive inbound funding from the ALEX launch vault principal as defined in `docs/bounties/MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md`.
- **Swaps must be slippage-guarded.** Every swap must set an explicit `min-dy` (or equivalent) bound.
- **Keep a gas buffer.** Never sweep the fee-vault STX balance below what is needed to operate (tx fees, emergency actions).

## Definitions

- **Fee vault**: a maintainer-controlled STX principal (ideally multisig) that holds accumulated protocol fees per asset (mainnet principals typically start with `SP` or `SM`).
- **Treasury denomination asset**: the asset(s) the protocol intends to hold long-term (examples: `wxBTC`, `wSTX`, a stable).
- **Conversion keeper**: an operator process that periodically swaps fee-vault balances into denomination assets using ALEX.

## Default policy (launch-safe)

1. **Accrue fees** into a fee vault in the original asset.
2. **Convert periodically** (DCA-style) rather than per-user-transaction.
3. **Converge to one target first** (single denomination asset) before introducing splits.

Recommended launch-safe default:

- Target: `wxBTC` (until Stacks-native `sBTC` has a clearly defined, liquid, canonical route).
- Conversion surface: ALEX `swap-helper-v1-03` with `min-dy` guards.

## Implementation (keeper script)

This repo includes a reference keeper script:

- `scripts/protocol-fee-sweep.ts`

It:

- Fetches SIP-010 balances at the fee vault address (Hiro API `/extended/v1/address/:address/balances`).
- Quotes expected output via ALEX `swap-helper-v1-03/get-helper`.
- Computes `min-dy` via `slippage-bps`.
- Optionally broadcasts swaps via `swap-helper-v1-03/swap-helper`.
- Records unsupported/unquotable balances under `skipped` so they can be audited and handled explicitly (typically via `--allow`).

### Plan-only (no broadcast)

```bash
bun scripts/protocol-fee-sweep.ts \
  --network mainnet \
  --fee-vault SP... \
  --target SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wxbtc-v2 \
  --slippage-bps 200
```

### Execute (broadcast swaps)

```bash
export STX_PRIVATE_KEY='...'

bun scripts/protocol-fee-sweep.ts \
  --network mainnet \
  --fee-vault SP... \
  --target SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wxbtc-v2 \
  --slippage-bps 200 \
  --execute
```

### Safety knobs

- Use `--min-dx` to avoid swapping dust.
- Use `--max-dx` to cap the per-sweep swap size (DCA behavior).
- Use repeatable `--allow` flags to constrain which tokens can be swapped.

## Evidence and monitoring

For each sweep window, record:

- Fee vault pre-sweep balances (raw Hiro balances JSON).
- The keeper plan output JSON (quoted `dy` + `min-dy`).
- Broadcast txids (one per swapped asset).
- Fee vault post-sweep balances (raw Hiro balances JSON).

The dashboard should show two distinct surfaces:

- **Tax sweep monitor** (protocol fee accrual events)
- **Conversion monitor** (keeper-run swaps and net treasury denomination inflows)
