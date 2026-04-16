# BOS supply-chain verification and proof pipeline (CON-442)

This document specifies how BOS converts legacy supply-chain checkpoints into (1) immutable, append-only state updates and (2) public, verifiable proof artifacts.

## Ethos fit (what BOS optimizes for)

- **Sovereignty and portability by default:** authoritative integrity claims are anchored on-chain and proof artifacts are content-addressed, so verification does not depend on a single vendor or database.
- **ZSE by default (public-safe surfaces):** checkpoint payloads are public-safe; sensitive documents are represented only as hash commitments.
- **Fail-closed:** missing checkpoints and integrity breaks become explicit protocol facts (gap/anomaly events). No silent drops or inferred state.
- **Determinism:** event canonicalization, ordering, and commitment construction are deterministic, so independent parties can rebuild and verify roots.
- **Role separation:** evidence is produced by signed events; storage is append-only; views are derived and rebuildable.

## System overview

### Actors

- **Legacy adapter:** maps upstream checkpoint systems into a BOS event payload.
- **Collector/validator:** verifies signatures and schema, then persists events into an append-only log.
- **Nakamoto Guardian (attestor):** publishes explicit `gap`/`anomaly` events and enforces policy (freshness, allowlists, replay rules).
- **Commitment builder:** constructs deterministic commitments (hash chains + Merkle/MMR roots) over the event log.
- **Anchorer:** writes commitment roots to an on-chain registry.
- **Verifier/renderer:** derives verification views from signed events + anchored commitments.

### Happy-path flow

```text
Legacy sources -> adapter -> signed checkpoint events -> collector/validator
  -> append-only event log -> commitment builder -> on-chain anchor
    -> proof manifest + bundles -> verification views
```

## Event model

### Envelope

Checkpoint transport uses Signed Event Envelope v1:

- `docs/protocols/SIGNED_EVENT_ENVELOPE_V1.md`

The supply-chain pipeline is a strict consumer of the envelope rules (canonicalization, payload hash recomputation, event id derivation, signature suite verification, freshness, and allowlists).

### Event kinds

- `supplychain.checkpoint.v1`: a single legacy checkpoint represented as a signed event.
- `supplychain.gap.v1`: an explicit statement that a required checkpoint is missing beyond policy.
- `supplychain.anomaly.v1`: an explicit integrity or policy violation statement.

Checkpoint events are authored by upstream publishers. Gap and anomaly events are authored by a BOS attestor (typically Nakamoto Guardian) and are part of the same append-only evidence stream.

### `supplychain.checkpoint.v1` payload (public-safe)

Minimum fields:

- `subject_id`: stable id of the tracked unit (lot/batch/container/shipment/invoice).
- `checkpoint_type`: stable enum (for example `manufactured`, `qc_pass`, `handoff`, `shipped`, `received`).
- `checkpoint_at`: unix seconds representing when the checkpoint occurred.
- `meta`: public-safe origin tags (system name, facility code, lane, and similar).
- `commitments`: map of `label -> sha256(hex)` for any internal-only documents/attachments.

Replay protection is provided by the envelope’s `sequence` and `event_id` dedupe rules.

### `supplychain.gap.v1` payload

Minimum fields:

- `subject_id`
- `expected_checkpoint_type`
- `expected_after_sequence`: the envelope `sequence` value (for the same `publisher` and `subject_id`) after which the checkpoint was expected.
- `observed_until`: unix seconds at which the gap condition was evaluated by the attestor.
- `reason_code`
- `commitments` (hash commitments to internal incident notes)

### `supplychain.anomaly.v1` payload

Minimum fields:

- `code`: stable anomaly code (see recommended codes below).
- `severity`: stable enum (for example `info`, `warn`, `error`).
- `subject_id` (optional)
- `related_event_id` (optional): the `event_id` of an accepted checkpoint event.
- `observed_envelope_hash` (optional): hash of an observed-but-rejected envelope when no valid `event_id` can be accepted.
- `details` (optional): public-safe details for operators and verifiers.
- `commitments` (optional): hash commitments to internal reports/logs.

The `sc_anomalies` projection is derived by indexing `supplychain.anomaly.v1` events (and may additionally index `supplychain.gap.v1` events) so anomaly state remains reconstructable from append-only evidence.

## Storage model (append-only + derived)

### Append-only canonical log

Store every accepted envelope in an append-only table (conceptually `sc_checkpoint_events`) that contains:

- Tenant/dataset scope: `dataset_id`
- Envelope identifiers: `event_id`, `publisher`, `kind`, `sequence`
- Ingest ordering: `ingest_seq` (monotonic per `dataset_id`, assigned by the collector)
- Supply-chain selectors: `subject_id`, `checkpoint_type`, `checkpoint_at`
- Canonical payload and signature material: `payload_json`, `payload_hash`, `sigs_json`
- Commitment material: `leaf_hash`, optional `stream_prev_event_id`, optional `stream_chain_hash`

Enforce append-only semantics with database constraints/triggers that reject `UPDATE`/`DELETE` on the canonical log.

### Derived, rebuildable tables

Derived projections are operational conveniences and must be rebuildable from the append-only log:

- `sc_subject_state`: latest known checkpoint state per `subject_id` plus an `integrity_status`.
- `sc_anomalies`: stable anomaly records (see codes below).
- `sc_commitment_windows`: anchored commitment windows and publication metadata.

If the pipeline also records rejected/invalid submissions, those records must be append-only and public-safe (for example by storing only `observed_envelope_hash` plus a `code`, and putting any sensitive details behind hash commitments).

### Trigger behavior

Triggers should keep work lightweight:

- On insert into the canonical log, enqueue projection updates and window-building work.
- Do not build Merkle/MMR structures inside triggers.

## Commitment scheme

To support both timeline integrity and public inclusion proofs, use a hybrid scheme.

### Per-subject hash chain (timeline integrity)

Maintain a per-`subject_id` hash chain:

- Each checkpoint event stores a `stream_chain_hash = sha256(prev_stream_chain_hash || leaf_hash)`.
- A gap or reorder breaks the chain and must emit a `supplychain.anomaly.v1` (or a derived anomaly record).

This makes missing or reordered checkpoints observable without requiring Merkle proofs.

### Windowed Merkle/MMR root (public inclusion)

Build periodic commitment windows over a deterministic ordering. For `SC-CHECKPOINT-V1`, the canonical ordering key is `(dataset_id asc, ingest_seq asc)`.

The commitment builder must export `events.ndjson` in that exact order so any verifier can rebuild the same root without relying on database state.

For each window, compute:

- `root_sha256`
- `scheme_id` (for example `SC-CHECKPOINT-V1`)
- Window boundaries (`start_seq`, `end_seq` or a deterministic event-count boundary)

For `SC-CHECKPOINT-V1` windows, boundaries are defined over `ingest_seq` within a single `dataset_id`.

Independent parties must be able to rebuild the same root from the exported events for the window.

Leaf hashing for `SC-CHECKPOINT-V1`:

- `leaf_hash = event_id` (the 32-byte SHA-256 digest as defined by Signed Event Envelope v1)

## On-chain anchoring

Each window root is anchored in a registry contract as the immutable integrity claim for the dataset/window.

Requirements:

- Do not hardcode principals in contract implementations; resolve authoritative principals dynamically via the operational treasury/principal registry pattern.
- Store at minimum: `dataset_id`, window bounds, `root_sha256`, `scheme_id`.
- Optionally bind the off-chain manifest by also storing `manifest_sha256`.

## Proof artifacts

### Proof manifest

The proof manifest is the primary public artifact for a commitment window. It should be content-addressed and include:

- Commitment identity: `v`, `dataset_id`, `scheme_id`, window bounds
- Integrity: `root_sha256`, on-chain anchor reference (chain, txid, height)
- Artifacts: URIs for exported events and proof material
- Counts: events, subjects
- Public-safe anomaly summary

Example shape:

```json
{
  "v": 1,
  "dataset_id": "supplychain.checkpoints.v1",
  "scheme_id": "SC-CHECKPOINT-V1",
  "window": { "start_seq": "120000", "end_seq": "129999" },
  "root_sha256": "<hex>",
  "anchoring": {
    "chain": "stacks",
    "registry_contract_id": "<resolved-contract-id>",
    "txid": "<hex>",
    "block_height": 123456
  },
  "artifacts": {
    "events_uri": "ipfs://.../events.ndjson",
    "proofs_uri": "ipfs://.../proofs.ndjson",
    "anomalies_uri": "ipfs://.../anomalies.json"
  },
  "counts": { "events": 10000, "subjects": 1820 },
  "anomaly_summary": {
    "INVALID_SIGNATURE": 0,
    "SEQUENCE_GAP": 12,
    "STATE_MACHINE_VIOLATION": 3
  }
}
```

### Proof bundles

Recommended bundle files (public-safe):

- `events.ndjson`: all signed envelopes in the window in the deterministic order used for commitment.
- `proofs.ndjson`: inclusion proofs per `event_id` (or publish the commitment structure so proofs can be derived).
- `anomalies.json`: public-safe anomaly details.

ZSE constraints for public artifacts:

- `subject_id` must be public-safe (pseudonymous or otherwise classified as non-sensitive) and must not contain names, emails, phone numbers, physical addresses, or internal account identifiers.
- `meta` must be limited to public-safe tags and codes.
- `details` in gap/anomaly events and `anomalies.json` must be public-safe; any sensitive details must be referenced only via hash commitments.

## Verification views

Verification views are renderers of evidence, not sources of truth.

Minimum views:

1. **Subject timeline view**
   - All checkpoints for `subject_id` with signature validity, inclusion status (which window), and chain integrity status.
2. **Commitment window view**
   - Window bounds, root, scheme id, on-chain anchor reference, and anomaly summary.

Minimum client-side verification algorithm:

1. Fetch the manifest.
2. Fetch the on-chain registry root for the manifest’s `(dataset_id, window)`.
3. Recompute the leaf hash for the selected checkpoint from the signed envelope canonical payload.
4. Verify the Merkle/MMR inclusion proof to `root_sha256`.
5. Confirm `root_sha256` equals the on-chain registry root.

## Anomaly detection and missing-checkpoint handling

Anomalies must have stable codes so dashboards and automation can enforce policy deterministically.

Recommended codes:

- `INVALID_SIGNATURE`
- `PUBLISHER_NOT_ALLOWLISTED`
- `PAYLOAD_HASH_MISMATCH`
- `DUPLICATE_EVENT_ID`
- `NON_MONOTONIC_SEQUENCE`
- `SEQUENCE_GAP`
- `OUT_OF_ORDER_CHECKPOINT_AT`
- `STATE_MACHINE_VIOLATION`
- `WINDOW_ROOT_MISMATCH`
- `ANCHOR_LATE`

Missing checkpoints are handled by explicit `supplychain.gap.v1` events. Downstream transitions that require a missing checkpoint must halt or degrade explicitly.

## Multi-tenancy and jurisdictional sharding

For BaaP multi-tenancy, the pipeline must support strict state isolation:

- `dataset_id` is tenant-scoped (for example by namespace or BNS-like identifier).
- Allowlists are tenant-scoped (publisher keys and permitted `subject_id` domains).
- Commitment windows and manifests are per-tenant, so proofs remain portable across deployments.

Commitment windows must never mix events across `dataset_id` boundaries.
