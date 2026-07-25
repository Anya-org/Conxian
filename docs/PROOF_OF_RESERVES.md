# Proof-of-Reserves Verification Boundary

## Scope

`contracts/security/proof-of-reserves.clar` verifies a bounded registry of
secp256k1 attestors over one exact reserve snapshot. It is a cryptographic
attestation boundary, not an audit, oracle qualification, deployment record, or
claim that represented off-chain backing exists.

## Canonical shared snapshot

Clients build the exact typed tuple below and compute
`sha256(to-consensus-buff?(tuple))` using SIP-005 consensus serialization.
JSON, textual Clarity, concatenation, and ABI encoding are not interchangeable.

| Field | Type | Value/meaning |
|---|---|---|
| `domain` | `(string-ascii 24)` | `CONXIAN_POR_SNAPSHOT_V1` |
| `schema-version` | `uint` | `u1` |
| `network` | `uint` | native `chain-id` |
| `verifying-contract` | `principal` | `.proof-of-reserves` |
| `asset` | `principal` | submitted SIP-010 trait contract |
| `on-chain-balance` | `uint` | live balance of the PoR contract principal |
| `total-supply` | `uint` | live SIP-010 total supply |
| `off-chain-backing` | `uint` | attested external backing in token base units |
| `as-of-height` | `uint` | observation `burn-block-height` |
| `expiry-height` | `uint` | exclusive burn-height expiry |
| `nonce` | `uint` | replay protection per asset and attestor |

Submission samples balance and supply inside the contract; callers cannot
supply those authoritative values. The digest helper accepts them only so a
client can reproduce the exact preimage before signing.

## Per-attestor envelope

Each signer signs `sha256(to-consensus-buff?(tuple))` for:

| Field | Type | Value |
|---|---|---|
| `domain` | `(string-ascii 24)` | `CONXIAN_POR_ATTESTOR_V1` |
| `schema-version` | `uint` | `u1` |
| `network` | `uint` | native `chain-id` |
| `verifying-contract` | `principal` | `.proof-of-reserves` |
| `snapshot-digest` | `(buff 32)` | shared digest |
| `attestor` | `principal` | registered signer and `tx-sender` |

This preserves shared-snapshot agreement while preventing cross-attestor
signature reuse.

## Registry, signatures, replay, and quorum

- The owner registers at most 10 principals with active compressed secp256k1
  public keys `(buff 33)`.
- Signatures are canonical recoverable `r || s || recovery-id` values and must
  be exactly 65 bytes. Tests use `elliptic` canonical low-S signing.
- `secp256k1-verify` succeeds before an attestation or nonce is stored.
- Quorum is configurable from 1 through 10 and is recomputed by folding the
  bounded principal list. No mutable raw count is authoritative.
- Rotation increments `key-version`; deactivation clears active status. Old
  records immediately stop counting because quorum compares current active
  registry key and version with the validated record.
- A principal contributes at most once per shared digest. A used
  `{asset, attestor, nonce}` cannot authorize another snapshot.

## Burn-height boundaries

- Future observations fail.
- Observation age is inclusive: `current - as-of <= 1008`.
- Expiry is exclusive: evidence is valid only while `current < expiry`.
- `expiry > as-of` and `expiry - as-of <= 1008` are required.
- Ordering checks precede subtraction to prevent uint underflow.

## Activation and reconciliation

Candidates are stored by shared digest. Only a candidate reaching current
distinct-attestor quorum becomes active; split or non-quorate candidates do not
replace an existing active snapshot.

The reconciliation formula is:

```text
on-chain-balance + off-chain-backing >= total-supply
```

To avoid addition overflow, the implementation checks
`on-chain-balance >= total-supply`, or otherwise checks
`off-chain-backing >= total-supply - on-chain-balance`.

`is-fully-backed` and `get-proof-status` are non-mutating public functions,
rather than `define-read-only`, because Clarity does not permit dynamic trait
calls from read-only functions. Both live-call the SIP-010 trait and fail closed
for absent/invalid/expired metadata, token errors, changed balance or supply,
insufficient backing, lost quorum, deactivation, or rotation.

## APIs

- Digest helpers: `get-shared-snapshot-digest`,
  `get-attestor-envelope-digest`.
- Registry: `add-attestor`, `rotate-attestor-key`, `deactivate-attestor`,
  `set-quorum`.
- Submission: `submit-attestation`.
- Authoritative decisions: trait-based `is-fully-backed` and
  `get-proof-status`.
- Diagnostic only: `get-active-snapshot-digest`, `get-snapshot`,
  `get-validated-attestation`, `get-attestor`, `get-attestors`, `get-quorum`.
  Raw diagnostic state is never sufficient for a positive reserve decision.

## Verification

```bash
bash scripts/run-tests.sh tests/security/proof-of-reserves.test.ts
python3 scripts/verify_proof_of_reserves_boundary.py
python3 -m unittest tests/test_verify_proof_of_reserves_boundary.py
```

Expected evidence covers same-snapshot quorum; signature, key, field, schema,
network, verifier, and asset mutation; replay; duplicate/split signers;
stale/future/expired evidence; rotation/deactivation; live state drift; and
unsafe consumer rejection.

## Non-claims

Checked-in plans are metadata/preflight artifacts. This implementation does not
claim auditor or oracle qualification, production support, mainnet/testnet
deployment, signing, broadcast, or proof of real-world custody.
