# sBTC Phase 2 offline evidence snapshot

This directory is a review-only snapshot of the minimum upstream inputs used by
the issue #507 Phase 2 evidence harness. It is pinned to official
`stacks-sbtc/sbtc` release `v1.3.3`, commit
`11567fc6a111c130177e64380503acca8546aab6`.

`manifest.json` records immutable source URLs and SHA-256 hashes. The target
network matrix deliberately leaves all live principals, signer state, and the
Emily endpoint `unresolved`. Nothing in this directory authorizes a network
call, transaction construction, signing, broadcast, mint, burn, initialization,
or Bitcoin settlement claim.

Run the deterministic offline gate from the repository root:

```bash
npm run verify:sbtc-phase2
```

Expected current decision:

- offline snapshot and recipient-vector review: `GO`;
- official network integration: `NO-GO`;
- Bitcoin recipient settlement claim: `NO-GO`.
