# Issue #507 — Phase 2 sBTC Integration Evidence and Go/No-Go Gate

## Status and purpose

This is a research and acceptance artifact for the future official sBTC
network-integration phase. It does not add an external requirement, Clarinet
remapping, network call, signer action, mint/burn path, or deployment evidence.

Phase 1/2A merged via [PR #546](https://github.com/Conxian/Conxian/pull/546) at
commit `11d598c2ec098088032d1e78f608887dd8441d5b`. That delivery remains a
custody-only vault for already-issued canonical sBTC. It is not official bridge,
signer, peg, yield, deployment, or settlement proof. The current Phase 2
decision is **NO-GO** until the evidence gates below are satisfied.

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

## Unresolved target-network matrix

No dynamic principal is hardcoded or guessed in this artifact. The following
entries remain unresolved and are release blockers:

| Evidence item | Mainnet | Testnet / target network | Required evidence |
|---|---|---|---|
| Canonical sBTC SIP-010 token principal | **UNRESOLVED** | **UNRESOLVED** | Official network documentation plus on-chain read-back from the approved source revision. |
| Official registry principal and ABI | **UNRESOLVED** | **UNRESOLVED** | Pinned Clarity source, deployed principal, network, and read-only verification. |
| Deposit contract and availability | **UNRESOLVED** | **UNRESOLVED** | Official contract source, exact function schema, target-network deployment, and supported deposit status. |
| Withdrawal contract and availability | **UNRESOLVED** | **UNRESOLVED** | Official contract source, exact function schema, target-network deployment, and confirmed withdrawal availability. |
| Signer/bootstrap configuration | **UNRESOLVED** | **UNRESOLVED** | Official signer/bootstrap source and signer-derived network identity; no guessed address is acceptable. |
| Emily endpoint/version and operation schema | **UNRESOLVED** | **UNRESOLVED** | Official API documentation, target endpoint, API version, and response fixture captured without secrets. |
| Upstream release/commit | **UNRESOLVED** | **UNRESOLVED** | Immutable upstream release tag or commit SHA recorded in the evidence pack. |

The absence of a value is intentional. Do not copy an example principal from a
guide into production configuration unless the guide is explicitly authoritative
for the target network and the value is verified on that network.

## Required upstream pin before implementation

Before adding an official sBTC external requirement or network remapping, the
implementation proposal must pin one reviewed `stacks-sbtc/sbtc` release tag or
immutable commit SHA. Floating branches, an unpinned package, or a moving API
contract are not acceptable. The pin must include:

1. the exact upstream repository and release/commit identifier;
2. the Clarity contract sources and ABI used by the integration;
3. the Emily API version and response schema used by the client/evidence
   harness;
4. the target network and a complete token/registry/deposit/withdrawal/signer
   principal matrix; and
5. a source hash and review record showing that the remapping matches that
   pinned source.

Until that pin and matrix exist, this repository must not add official sBTC
requirements or remappings.

## Read-only Emily and state-machine boundary

Emily is an external observation and coordination surface for sBTC deposit and
withdrawal operations. A future evidence harness may query it read-only to
correlate an operation identifier, status, Stacks transaction, and eventual
Bitcoin transaction. It must not treat an API response, a Stacks confirmation,
or a user-supplied transaction ID as settlement proof by itself.

The boundary is deliberately one-way for this phase:

- `sbtc-vault.clar` does not call Emily, notify signers, mint or burn sBTC, or
  submit Bitcoin transactions;
- an off-chain evidence worker may read the pinned API and source-defined state
  machine, but may not sign, broadcast, or mutate protocol state as part of a
  unit test;
- state names and transitions must come from the pinned upstream release; do
  not invent local substitutes for the states defined by that source, and
  verify any rejection or refund semantics against the pinned release; and
- a confirmed Stacks-side operation is not a Bitcoin payout proof until the
  official post-condition and Bitcoin-side recipient evidence are both present.

## Recipient tuple and post-condition test scope

Once the official withdrawal ABI is pinned, the evidence harness must exercise
the exact recipient tuple defined by that ABI rather than a free-form address
string. At minimum, the test fixture must preserve and compare:

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

The current slice does not run these tests because the target-network contract
matrix and withdrawal availability are unresolved. No network fixture should be
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
  log, DLC/BitVM2 path, or oracle response proves settlement; and
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

*Last updated: July 22, 2026.*
