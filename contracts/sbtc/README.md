# sBTC Module

## Phase 2A boundary

The current approved sBTC slice is custody-only. Users are expected to obtain
already-issued canonical sBTC through official sBTC infrastructure outside this
repository, then deposit and later withdraw that same token through
`contracts/vaults/sbtc-vault.clar`.

The Phase 2A vault:

- accepts only the admin-configured SIP-010 token principal;
- records accounted assets and per-user shares with deterministic rounding;
- enforces a deposit cap, pause behavior, compliance checks, and explicit
  transfer/error handling; and
- leaves strategy allocation disabled until a separate approval and accounting
  design exists.

No contract in this slice:

- wraps native BTC or redeems BTC for sBTC;
- calls privileged official sBTC mint or burn functions;
- treats `btc-adapter`, DLC, BitVM2, or oracle stubs as settlement proof;
- monitors or repairs the BTC/sBTC peg; or
- claims a deployed or production-ready integration.

## Related contracts

The existing sBTC directory contains research and integration-adjacent
contracts. They are not implicitly part of the Phase 2A custody boundary:

| Contract | Current boundary |
|----------|------------------|
| `dlc-manager.clar` | Existing DLC/BitVM2-oriented placeholder surface; not redemption proof for the vault. |
| `dlc-bond.clar` | DLC bond lifecycle model; not an sBTC custody adapter. |
| `dlc-orchestrator.clar` | DLC orchestration model; not a BTC bridge or signer. |
| `contracts/interfaces/btc-adapter.clar` | Interface stub only; not called by `sbtc-vault.clar`. |

## Later phases

Any future implementation must be reviewed separately for:

1. official sBTC deposit/redemption integration and failure handling;
2. peg data, freshness, deviation thresholds, and emergency response; and
3. strategy adapters, allocation authorization, loss accounting, and paused
   withdrawal guarantees.

The issue-focused acceptance boundary is recorded in
`docs/ISSUE_507_PHASE_2A_ACCEPTANCE.md`.

## Validation

Run the custody/accounting tests with:

```bash
bash scripts/run-tests.sh tests/vaults/sbtc-vault.test.ts
```

This documents local simnet behavior only; it is not deployment evidence.
