# Canonical ZKML Evidence Contract

**Status:** Future acceptance contract; disabled in the current protocol.

**Correction date:** July 23, 2026.

`contracts/compliance/zkml-verifier.clar` is a quarantined scaffold. It is
retained in `Clarinet.toml` and the local simnet plan for compilation and
negative regressions, but it is excluded from testnet and mainnet release
artifacts. Until a reviewed cryptographic backend implements this contract,
all verification attempts and status queries return the typed
`unavailable`/`ERR_VERIFIER_UNAVAILABLE` outcome (`err u503`). No positive
verification vector exists.

This document defines the minimum evidence boundary a future implementation
must satisfy. It is not evidence that a backend, verification key, circuit, or
production deployment exists.

## Evidence envelope

Every future evidence record must use a versioned, canonical envelope with all
of the following fields. Field names and encodings are part of the schema and
must not be inferred from an arbitrary proof blob.

| Field | Required contract |
| --- | --- |
| `schema-version` | Explicit integer schema version. A verifier must reject unknown versions as `unsupported`; it must not silently apply another version's rules. |
| `proof-system` | Explicit proof system and verifier profile, such as a reviewed Groth16 or Plonk profile. The profile fixes transcript, commitment, and serialization rules. |
| `curve` | Explicit elliptic-curve identifier. The curve must match the circuit and verification-key profile; a curve mismatch is `rejected` or `unsupported`, never accepted by shape alone. |
| `circuit-id` and `circuit-version` | Stable circuit identity and version, bound to the model statement and verification-key registry entry. |
| `model-id` and model commitment | The canonical model identity and a commitment/digest for the exact model artifact or approved model registry record. |
| `verification-key-id` and verification-key commitment | Stable key identity plus a commitment to the exact verification key used by the backend. A key name without a bound commitment is insufficient. |
| `encoding` | Canonical encoding identifier, field ordering, byte order, length rules, and domain-separation tag. Non-canonical or ambiguous encodings are `malformed` or `unsupported`. |
| `public-inputs` | Ordered, typed public inputs. The order, type, and serialization of every input must be fixed by the circuit profile. |
| `input-hash` | The input/data commitment supplied to the contract boundary, bound into the statement digest rather than merely logged as metadata. |
| `statement-digest` / `transcript-digest` | A domain-separated digest over schema version, proof profile, curve, circuit identity, model identity/commitment, verification-key commitment, ordered public inputs, `model-id`, and `input-hash`. This is the binding that prevents a valid proof from being relabeled for another model or input. |
| `evidence-id`, freshness, and expiry | Unique evidence identifier, issuance time/height, expiry time/height, and any required challenge/nonce. The accepted window and clock source must be explicit. |
| Replay state | A defined replay key (at minimum evidence identifier plus challenge/nonce and statement binding), a consumed/duplicate rule, and the owner of replay state. Reuse must result in `replay`, not acceptance. |
| Backend ownership | Named implementation owner, backend version/release, source revision, deployment/attestation identity, and verification-key registry authority. An unnamed or unqualified external result is `unavailable` or `unsupported`. |
| Typed outcome | One of the stable outcomes below, with an optional bounded reason code. Free-form success text is not an acceptance signal. |

The exact hash, field, curve, proof-system, and serialization choices must be
frozen by a reviewed schema version before a backend is enabled. This contract
does not authorize guessing those values in Clarity.

## Binding and acceptance rules

The future verifier must recompute the canonical statement/transcript digest
from the supplied envelope and compare it with the proof's bound public
statement. `model-id` and `input-hash` must be included in that digest and in
the ordered public-input mapping. A caller must not be able to change either
value without changing the statement that the cryptographic proof verifies.

Acceptance additionally requires all of the following:

1. The schema and proof-system profile are supported and version-matched.
2. The curve, circuit identity, model commitment, and verification-key
   commitment are registered and mutually compatible.
3. The encoding is canonical and the proof parses according to the selected
   profile.
4. The cryptographic backend verifies the proof against the exact ordered
   public inputs and recomputed statement/transcript digest.
5. Freshness, challenge, expiry, and replay checks pass using the declared
   clock and replay owner.
6. The backend identity and release are approved for this profile.

No structural check, fixed byte length, simulated receipt, or status record can
substitute for these cryptographic checks.

## Structural parsing versus cryptographic acceptance

These are separate stages with separate authority:

- **Structural parsing** may validate field presence, schema version, lengths,
  canonical encoding, enum values, and typed field shapes. It may return
  `malformed` or `unsupported`. It must never emit an acceptance event or
  return `accepted`.
- **Cryptographic acceptance** belongs only to the reviewed backend. It must
  verify the proof, key commitment, circuit/model compatibility, ordered
  public inputs, statement/transcript binding, freshness, challenge, expiry,
  replay state, and backend ownership. Only this stage may return `accepted`.

The current Clarity scaffold implements neither stage. It returns
`ERR_VERIFIER_UNAVAILABLE` for every input and emits no `zkml-verified` event.

## Stable typed outcomes

The future interface should preserve machine-readable outcomes:

| Outcome | Meaning |
| --- | --- |
| `accepted` | Cryptographic verification and all binding/freshness/replay/backend checks passed. This outcome is not reachable today. |
| `rejected` | The reviewed backend evaluated the evidence and the proof or statement did not verify. |
| `malformed` | The envelope or encoding cannot be parsed under the declared schema. |
| `unsupported` | The schema, proof system, curve, circuit, encoding, or backend profile is not supported. |
| `unavailable` | No approved verifier backend is available to evaluate the evidence. |
| `binding-mismatch` | The proof does not bind to the supplied model, input, circuit, key, or ordered public inputs. |
| `stale` | Freshness, challenge, or expiry requirements failed. |
| `replay` | The evidence or challenge has already been consumed or is otherwise duplicated. |

Callers must treat every outcome except `accepted` as non-compliant for any
compliance, settlement, routing, custody, deployment, or mainnet-readiness
decision. In particular, `unavailable` must not be converted into a boolean
success or a success-shaped status record.
