# Issue #507 — Phase 2 sBTC Integration Evidence and Go/No-Go Gate

## Status and purpose

This is a research and acceptance artifact for the future official sBTC
network-integration phase. It does not add an external requirement, Clarinet
remapping, network call, signer action, mint/burn path, or deployment evidence.

Phase 1/2A merged via [PR #546](https://github.com/Conxian/Conxian/pull/546) at
commit `11d598c2ec098088032d1e78f608887dd8441d5b`. That delivery remains a
custody-only vault for already-issued canonical sBTC. It is not official bridge,
signer, peg, yield, deployment, or settlement proof.

The offline evidence harness is now pinned to official `stacks-sbtc/sbtc`
release `v1.3.3`, commit
`11567fc6a111c130177e64380503acca8546aab6`. Its current decision is:

- **GO** for deterministic offline snapshot integrity and recipient-tuple
  vector review only;
- **NO-GO** for official target-network integration; and
- **NO-GO** for any Bitcoin recipient settlement claim.

Run the gate with `npm run verify:sbtc-phase2` and its focused tests with
`npm run test:sbtc-phase2`.

## Official source set

Use only official Stacks/sBTC sources when resolving the matrix. A source URL is
not by itself evidence that a target-network principal or operation is currently
available; the acceptance pack must record the exact page, API response, source
revision, and verification date.

- [Stacks sBTC overview](https://docs.stacks.co/learn/sbtc)
- [Official sBTC Clarity contracts](https://docs.stacks.co/learn/sbtc/clarity-contracts)
- [Emily API](https://docs.stacks.co/learn/sbtc/emily-api)
- [sBTC deposit operation](https://docs.stacks.co/learn/sbtc/sbtc-operations/deposit)
- [BTC to sBTC integration guide](https://docs.stacks.co/more-guides/sbtc/bridging-bitcoin/btc-to-sbtc)
- [sBTC to BTC integration guide](https://docs.stacks.co/more-guides/sbtc/bridging-bitcoin/sbtc-to-btc)
- [Clarinet sBTC integration](https://docs.stacks.co/clarinet/integrations/sbtc)
- [Stacks mainnet and testnets](https://docs.stacks.co/learn/network-fundamentals/mainnet-and-testnets)
- [Official stacks-sbtc source repository](https://github.com/stacks-sbtc/sbtc)
- [Official stacks-sbtc releases](https://github.com/stacks-sbtc/sbtc/releases)
- [Official stacks-sbtc commit history](https://github.com/stacks-sbtc/sbtc/commits/main)
- [Pinned v1.3.3 release](https://github.com/stacks-sbtc/sbtc/releases/tag/v1.3.3)
- [Pinned v1.3.3 commit](https://github.com/stacks-sbtc/sbtc/commit/11567fc6a111c130177e64380503acca8546aab6)

The checked-in review snapshot is under
[`evidence/sbtc/phase2/v1.3.3/`](../evidence/sbtc/phase2/v1.3.3/). Its manifest
contains full-commit immutable source URLs and SHA-256 hashes for the upstream
withdrawal contract, registry contract, and public Emily OpenAPI schema. These
files were independently fetched from the immutable URLs and byte-compared to a
detached checkout of the pinned commit before inclusion.

## Unresolved target-network matrix

No dynamic principal is hardcoded or guessed in this artifact. The
machine-readable source of truth is
[`target-network-matrix.json`](../evidence/sbtc/phase2/v1.3.3/target-network-matrix.json).
The following entries remain unresolved and are release blockers:

| Evidence item | Mainnet | Testnet / target network | Required evidence |
|---|---|---|---|
| Canonical sBTC SIP-010 token principal | **UNRESOLVED** | **UNRESOLVED** | Official network documentation plus on-chain read-back from the approved source revision. |
| Official registry principal and ABI | **UNRESOLVED** | **UNRESOLVED** | Pinned Clarity source, deployed principal, network, and read-only verification. |
| Deposit contract and availability | **UNRESOLVED** | **UNRESOLVED** | Official contract source, exact function schema, target-network deployment, and supported deposit status. |
| Withdrawal contract and availability | **UNRESOLVED** | **UNRESOLVED** | Official contract source, exact function schema, target-network deployment, and confirmed withdrawal availability. |
| Signer/bootstrap configuration | **UNRESOLVED** | **UNRESOLVED** | Official signer/bootstrap source and signer-derived network identity; no guessed address is acceptable. |
| Signer state/liveness | **UNRESOLVED** | **UNRESOLVED** | Authoritative target-network signer-set/state read-back with verification time and source. |
| Emily endpoint/version and operation schema | **UNRESOLVED** | **UNRESOLVED** | Official API documentation, target endpoint, API version, and response fixture captured without secrets. |
| Upstream release/commit | `v1.3.3` / `11567fc6a111c130177e64380503acca8546aab6` | `v1.3.3` / `11567fc6a111c130177e64380503acca8546aab6` | Snapshot pin only; it does not resolve a live target network. |

The absence of a value is intentional. Do not copy an example principal from a
guide into production configuration unless the guide is explicitly authoritative
for the target network and the value is verified on that network.

## Required upstream pin before implementation

Before adding an official sBTC external requirement or network remapping, the
implementation proposal must use the reviewed `stacks-sbtc/sbtc` release and
immutable commit above. Floating branches, an unpinned package, or a moving API
contract are not acceptable. The offline snapshot now supplies:

1. the exact upstream repository, release, and full commit;
2. the withdrawal and registry Clarity sources used for evidence review;
3. the public Emily OpenAPI `0.1.0` schema used by the harness; and
4. SHA-256 integrity metadata for each vendored input.

Official network integration still additionally requires:

1. the target network and a complete token/registry/deposit/withdrawal/signer
   principal matrix; and
2. a live verification record showing that any future remapping matches that
   pinned source.

Until the live matrix exists, this repository must not add official sBTC
requirements, remappings, or transaction construction.

## Read-only Emily and state-machine boundary

Emily is an external observation and coordination surface for sBTC deposit and
withdrawal operations. A future evidence harness may query it read-only to
correlate an operation identifier, status, Stacks transaction, and eventual
Bitcoin transaction. It must not treat an API response, a Stacks confirmation,
or a user-supplied transaction ID as settlement proof by itself.

The boundary is deliberately one-way for this phase. The harness models the
registry states as `pending | accepted | rejected` and Emily withdrawal states
as `pending | accepted | confirmed | failed`; it does not merge these two
state machines. The registry mapping preserves the upstream optional boolean:
`none` is pending, `some true` is accepted, and `some false` is rejected.

- `sbtc-vault.clar` does not call Emily, notify signers, mint or burn sBTC, or
  submit Bitcoin transactions;
- an off-chain evidence worker may read the pinned API and source-defined state
  machine, but may not sign, broadcast, or mutate protocol state as part of a
  unit test;
- state names and transitions must come from the pinned upstream release; do
  not invent local substitutes for the states defined by that source, and
  verify any rejection or refund semantics against the pinned release; and
- an Emily `confirmed` status or confirmed Stacks-side operation is not a
  Bitcoin payout proof until the
  official post-condition and Bitcoin-side recipient evidence are both present.

## Recipient tuple and post-condition test scope

The evidence harness exercises the exact recipient tuple defined by the pinned
withdrawal ABI rather than a free-form address string. Versions `0x00` through
`0x04` require 20-byte `hashbytes`; versions `0x05` and `0x06` require 32-byte
`hashbytes`. Unsupported versions, malformed hex, and wrong lengths fail
deterministically. The vectors are recorded in
[`recipient-vectors.json`](../evidence/sbtc/phase2/v1.3.3/recipient-vectors.json).

The test fixture preserves and compares:

- target network;
- Stacks sender/account and the official withdrawal contract;
- Bitcoin recipient encoding (the documented recipient type/version and hash
  bytes, or the exact upstream equivalent);
- requested sBTC amount;
- documented `max-fee` or equivalent fee bound; and
- the upstream request identifier/nonce used to correlate Emily and chain state.

The post-condition and state-machine tests must verify, using the pinned source
names and schemas:

1. the sender transfers exactly the required sBTC amount plus any documented
   fee bound to the official withdrawal contract;
2. the recipient tuple is encoded without truncation, substitution, or replay;
3. the request identifier is unique and remains bound to the original sender,
   amount, fee bound, and recipient tuple;
4. accepted, failed/rejected, retry, and refund behavior preserves the vault's
   accounting and withdrawal-liquidity invariants; and
5. a final Bitcoin-side transaction, when the official flow exposes one, pays
   the exact recipient tuple and satisfies the documented amount/fee and
   confirmation/finality requirements.

The current slice tests tuple validation and the pinned ABI's `amount + max-fee`
lock calculation offline. Unsigned transaction construction remains
intentionally blocked because both canonical token and withdrawal principals
are unresolved and chain-unverified. Even if a caller supplies a
chain-verification-shaped input, this harness does not fabricate transaction
bytes; an exact reviewed builder is a later increment. No network fixture is
replaced with a guessed principal or a live flaky call.

## No-broadcast, no-mint, and no-settlement-proof constraints

This research slice must remain fail-closed:

- no Bitcoin or Stacks transaction broadcast;
- no signer key, signer bootstrap, or Emily mutation;
- no official sBTC mint or burn call;
- no `set-approved-token`, `set-deposit-cap`, `set-paused`, or `set-admin`
  network initialization from a checked-in plan;
- no use of `deployments/mainnet-manifest-v1.yaml` as current authority;
- no claim that a deployment plan, workflow success, transaction ID, dashboard
  log, Stacks confirmation, Emily status, DLC/BitVM2 path, or oracle response
  alone proves Bitcoin recipient settlement; and
- no production principal is introduced until it is verified against the
  pinned official source and target network.

The checked-in simnet, testnet, and full-system mainnet plans may publish the
vault source, but publication is not vault initialization or sBTC integration
evidence. See [`DEPLOYMENT_RUNBOOK_VAULTS.md`](DEPLOYMENT_RUNBOOK_VAULTS.md).

## Go/no-go acceptance criteria

### Go requires all of the following

- An immutable upstream `stacks-sbtc/sbtc` release or commit is pinned and
  reviewed.
- The target network is named and its official token, registry, deposit,
  withdrawal, and signer/bootstrap principals are all verified; no matrix cell
  is unresolved.
- Withdrawal availability and the exact official ABI/state machine are verified
  on the target network, including rejection/refund and retry behavior where
  applicable.
- The Emily endpoint, API version, operation schema, and read-only evidence
  procedure are pinned.
- Recipient tuple encoding, exact post-conditions, fees, request correlation,
  and finality requirements have deterministic tests.
- Unit tests use deterministic adversarial fixtures and do not broadcast,
  mint, burn, or call live external services.
- Any external requirement/remapping is reviewed against the pinned source and
  the active `Clarinet.toml` dependency graph.
- Deployment and initialization follow the structured receipt-producing path
  required by [issue #531](https://github.com/Conxian/Conxian/issues/531); no
  plan-only artifact is treated as deployment proof.

### No-go remains mandatory when any of the following is true

- a principal, signer identity, or ABI is inferred from an example or guessed;
- registry, deposit, withdrawal, bootstrap, or signer evidence is unresolved;
- upstream source is floating or not reproducibly pinned;
- target-network withdrawal support is unavailable or unverified;
- Emily data is being used as a write path or as sole settlement proof; or
- the proposed test requires a live network, signer secret, broadcast, mint,
  burn, or an unreviewed production initialization call.

The validator returns actionable `NO-GO` reason codes for missing/floating pins,
hash mismatches, missing withdrawal/registry/Emily evidence, unresolved matrix
cells, invalid state models or recipient vectors, and prohibited sole-proof
settlement claims. The current unresolved matrix is an intentional passing test
condition only because the command reports network integration as `NO-GO`.

## Dependencies and review links

- [Issue #507 — Complete sBTC Vault Implementation](https://github.com/Conxian/Conxian/issues/507)
- [Issue #500 — production oracle configuration](https://github.com/Conxian/Conxian/issues/500)
- [Issue #526 — ALEX activation decision](https://github.com/Conxian/Conxian/issues/526)
- [Issue #531 — structured receipt-producing deployment path](https://github.com/Conxian/Conxian/issues/531)
- [PR #534 — auto-compounding infrastructure](https://github.com/Conxian/Conxian/pull/534)
- [PR #546 — merged Phase 1/2A custody core](https://github.com/Conxian/Conxian/pull/546)

Issue #500, #526, and PR #534 are adjacent dependencies, not authorization to
add bridge, oracle, ALEX, or yield behavior to the custody-only vault. Issue
#531 is a deployment/evidence dependency, not proof that a deployment has
occurred.

## Evidence pack template

Before a future Phase 2 implementation PR can change the current **NO-GO**:

| Field | Required value |
|---|---|
| Source revision | Pinned upstream release/tag or immutable commit SHA. |
| Target network | Explicit network name and date/time of verification. |
| Principal matrix | Token, registry, deposit, withdrawal, signer/bootstrap principals with official source citations and on-chain read-back. |
| ABI/state machine | Exact functions, argument types, operation states, retry/refund semantics, and source paths. |
| Emily evidence | Read-only endpoint/version, request/response schema, and redacted deterministic fixture. |
| Post-conditions | Exact asset amount, fee bound, recipient tuple, request correlation, and finality checks. |
| Deployment evidence | Structured receipts, source hash, plan hash, and post-initialization read-back; no plan-only claim. |
| Decision | Named approver, date, and explicit GO or NO-GO. |

The machine gate accepts only explicit `mainnet` or `testnet` target-network
values. Each required matrix ID must appear exactly once with its expected kind:
`token`, `registry`, `deposit`, `withdrawal`, and `bootstrap-signers` are
`contract`; `signer-state` is `state`; and `emily` is `service`. Unexpected,
duplicate, missing, or wrong-kind cells fail closed.

Contract cells require a network-valid contract principal, `chainVerified: true`,
a past UTC `verifiedAt`, immutable official `stacks-sbtc/sbtc`
provenance (`sourceUrl`, pinned `sourceCommit`, and `sourceSha256`), plus an
on-chain `readBack` whose principal and source hash match. Signer state requires
the same chain/provenance/timestamp guarantees and a substantive state value
matched by its read-back; the schema does not invent a signer identity or
threshold. Emily requires a non-placeholder HTTPS endpoint, API/schema version,
`liveVerified: true`, a past UTC verification timestamp, and equivalent pinned
`schemaEvidence`. Verification booleans without those fields never grant GO.

**Last updated**: July 25, 2026.
