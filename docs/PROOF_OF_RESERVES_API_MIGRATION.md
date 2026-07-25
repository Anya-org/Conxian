# Proof-of-Reserves API Migration

**Effective source date:** July 25, 2026

This note describes a breaking source/API replacement. It does not claim a
deployment, mainnet readiness, external audit, or oracle qualification.

## Legacy replacement

The former allowlist-and-ledger API accepted caller-controlled reserve amounts
and stored opaque signature bytes. It is not compatible with the current
snapshot-bound verifier and must not be used as reserve authority.

| Legacy surface | Current replacement |
|----------------|---------------------|
| `add-attestor(attestor)` | `set-attestor(attestor, compressed-secp256k1-public-key)` |
| `submit-attestation(asset, off-chain-amount, signature)` | `submit-attestation(asset, schema, domain, signature-algorithm, network, chain-id, registry-epoch, observed-balance, observed-supply, off-chain-backing, snapshot-height, expires-at, nonce, recoverable-signature)` |
| `sync-on-chain-balance(asset, balance)` | Removed. Submission and status paths read SIP-010 balance/supply directly. |
| raw `asset-reserves` / `attestations` state | Non-authoritative diagnostic candidates plus `accepted-reserves`; consumers may gate only through `is-fully-backed` or `get-proof-status`. |
| repeated sender count | Distinct registered signer approvals over one common snapshot digest. |
| partial owner handoff | `set-contract-owner(new-owner)` atomically assigns both owner and governance authority to `new-owner`. |
| infallible digest helpers | `get-snapshot-digest(...) -> (response (buff 32) uint)` and `get-attestation-digest(...) -> (response (buff 32) uint)`; callers must unwrap only successful validated results. |

## Canonical signing table

The common snapshot digest maps each accepted ASCII configuration value to an
explicit byte tag and hashes the tag to a fixed 32-byte leaf. Each `uint` leaf
uses Clarity's native `sha256(uint)` encoding, while fixed 32-byte identities
and digests are included directly. The ordered identity and reserve leaves are
hashed into two groups, then those group hashes are concatenated and hashed to
produce the `(buff 32)` snapshot digest. Public helpers reject unsupported or
inconsistent schema, domain, algorithm, network, chain, and registry-epoch
inputs before computing a digest.

| Layer | Ordered fields |
|-------|----------------|
| Snapshot identity | `domain`, `schema-version`, `chain-id`, `network`, `registry-epoch`, `asset-identity` |
| Snapshot reserves | `observed-on-chain-balance`, `observed-total-supply`, `off-chain-backing`, `snapshot-height`, `expires-at` |
| Signer envelope | `attestation-domain`, `schema-version`, `signature-algorithm`, `snapshot-digest`, `sha256(compressed-public-key)`, `nonce` |

The fixed algorithm identifier is the ASCII string `secp256k1`. Public keys are
compressed 33-byte secp256k1 keys. Signatures are 65-byte recoverable secp256k1
signatures (`r[32] || s[32] || recovery-id[1]`). Any other algorithm identifier
is rejected by both the public digest helper and attestation submission.

## Registry and consumer invariants

- Effective registry/configuration/control changes increment `registry-epoch`;
  previously accepted proof status fails closed until a new quorum is promoted.
- An accepted snapshot is replaced only by a candidate with a strictly greater
  `snapshot-height`. This monotonic rule intentionally favors safety over
  availability: a corrected snapshot at the same burn height cannot replace
  the accepted snapshot, so status remains fail-closed until a later-height
  snapshot reaches quorum.
- Idempotent setters return `(ok false)` without invalidating proof state.
  Removing a missing or already inactive attestor/asset returns the relevant
  validation error without advancing the epoch.
- `set-contract-owner` changes owner and governance in one transaction. The
  former owner immediately loses attestor, asset, network, chain, governance,
  and ownership mutation authority.
- Rotated and removed attestor keys remain permanently reserved and cannot be
  reactivated or assigned to another principal.
- An asset identity cannot be assigned to multiple token principals.
- Attestation submission is direct-sender only (`tx-sender == contract-caller`)
  to prevent proxy or `as-contract` signer substitution.
- Production treasury, compliance, settlement, routing, and readiness code may
  consume only `is-fully-backed` or `get-proof-status`. Repository validation is
  enforced by `scripts/verify_por_consumer_guard.py` and its fixture tests.

## Test isolation

Focused PoR scenarios create fresh `initSimnet('Clarinet.toml')` instances and
use deterministic fixed private keys. Rejection-invariance cases also isolate
each malformed, incorrect-key, altered-signature, and semantic failure before
proving the same nonce remains usable. Registry epochs, nonces, candidates,
balances, and accepted snapshots therefore cannot leak between scenarios.
