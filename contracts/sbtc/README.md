# sBTC Module

## Phase 2A boundary

Phase 1/2A merged via [PR #546](https://github.com/Conxian/Conxian/pull/546) at
commit `11d598c2ec098088032d1e78f608887dd8441d5b`. That delivery remains a
custody-only core and is not official bridge, signer, peg, yield, deployment,
or settlement proof.

The current approved sBTC slice is custody-only. Users are expected to obtain
already-issued canonical sBTC through official sBTC infrastructure outside this
repository, then deposit and later withdraw that same token through
`contracts/vaults/sbtc-vault.clar`.

The Phase 2A vault:

- accepts only the admin-configured SIP-010 token principal, configured once
  from the initial unconfigured state;
- records accounted assets and per-user shares with deterministic rounding;
- reconciles every successful deposit against the live token balance delta;
- rejects aggregate insolvency before any withdrawal transfer;
- enforces a deposit cap, pause behavior, compliance checks, and explicit
  transfer/error handling; and
- leaves strategy allocation disabled until a separate approval and accounting
  design exists.

Direct token donations remain visible in the token's live balance but are not
silently added to `total-assets` or used to change the share price. This slice
has no generic rescue or sweep function. Any donation synchronization, strategy
loss accounting, or peg accounting must be designed and reviewed as a later
phase.

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

## Authoritative public sBTC references

- [Stacks sBTC overview](https://docs.stacks.co/learn/sbtc)
- [sBTC Clarity contracts](https://docs.stacks.co/learn/sbtc/clarity-contracts)
- [Clarinet sBTC integration](https://docs.stacks.co/clarinet/integrations/sbtc)
- [Stacks mainnet and testnets](https://docs.stacks.co/learn/network-fundamentals/mainnet-and-testnets)
- [stacks-sbtc source repository](https://github.com/stacks-sbtc/sbtc)

The issue-focused acceptance boundary is recorded in
`docs/ISSUE_507_PHASE_2A_ACCEPTANCE.md`.

## Validation

Run the custody/accounting tests with:

```bash
bash scripts/run-tests.sh tests/vaults/sbtc-vault.test.ts
```

This documents simnet behavior only; it is not deployment evidence.
The current tests cover the 1:1 custody path and adversarial receipt/solvency
guards. They do not claim non-1:1 rounding coverage because this phase has no
safe state transition that changes the asset/share ratio.
