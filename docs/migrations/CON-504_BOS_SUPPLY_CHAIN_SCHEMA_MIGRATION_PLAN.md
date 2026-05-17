# CON-504 BOS supply-chain migration plan and rollback notes

## Scope

Migration file: `conxian-nexus/migrations/20260424000000_bos_supply_chain_schema.sql`

This migration introduces:

- Canonical append-only BOS event/proof lineage tables:
  - `sc_checkpoint_events`
  - `sc_proof_manifests`
  - `sc_event_proofs`
  - `sc_verification_runs`
- Derived read-model/indexing tables:
  - `sc_subject_state`
  - `sc_anomalies`
  - `sc_verification_state`
- Invariant triggers for:
  - append-only enforcement (`UPDATE`/`DELETE` blocked on lineage tables),
  - monotonic `ingest_seq` (per `dataset_id`) and monotonic `sequence` (per stream),
  - stream/predecessor shape checks,
  - proof-window and verification consistency checks,
  - lightweight derived-model updates on insert.

## Deployment plan

1. **Preflight checks**
   - Confirm `conxian-nexus` release includes this migration and the writer path inserts BOS events in sorted ingest order.
   - Confirm no legacy process writes unsorted backfill rows into `sc_checkpoint_events`.

2. **Apply migration**
   - Run from `conxian-nexus/` with the production migration workflow:
     - `sqlx migrate run`
   - Migration is SQL-only and should run transactionally.

3. **Post-apply smoke checks**
   - Verify expected tables exist.
   - Verify append-only triggers are attached on lineage tables.
   - Insert a minimal happy-path checkpoint sample and verify:
     - row lands in `sc_checkpoint_events`,
     - `sc_subject_state` updates,
     - no trigger exception.

4. **Operational enablement**
   - Enable BOS collector/verifier writes only after smoke checks pass.
   - For any historical ingest, replay strictly in ascending `(dataset_id, ingest_seq)` order.

## Rollback strategy

### Fast-fail rollback (migration errors before commit)

- If migration fails inside the transaction, PostgreSQL rolls back automatically.
- Fix SQL and re-run the migration.

### Controlled rollback (migration applied, little/no production data)

If migration applied but must be reverted before significant ingest, execute a controlled reverse script in this order:

1. Stop BOS writers to these tables.
2. Drop triggers on new tables.
3. Drop trigger functions.
4. Drop derived tables (`sc_subject_state`, `sc_anomalies`, `sc_verification_state`).
5. Drop lineage tables (`sc_verification_runs`, `sc_event_proofs`, `sc_proof_manifests`, `sc_checkpoint_events`).

Use explicit `IF EXISTS` and reverse dependency order.

### Data-preserving rollback (migration applied with live data)

Do **not** hard-drop tables with active lineage data unless explicitly approved.

Recommended approach:

1. Freeze writers.
2. Snapshot/back up all `sc_*` tables.
3. Roll application behavior back to pre-CON-504 code path.
4. Keep migrated tables for forensics and forward-fix.
5. Ship a follow-up forward migration to adjust schema safely (preferred over destructive rollback).

## Operational cautions

- `sc_checkpoint_events` monotonic trigger serializes writes per `dataset_id` via advisory transaction lock; this is intentional to prevent out-of-order concurrency races.
- Backfills that are not sorted by `ingest_seq` or stream `sequence` will fail fast by trigger design.
- `sc_event_proofs` only accepts proofs for checkpoint-kind events inside the referenced manifest window.
- Append-only lineage means corrections should be represented as new events/manifests/runs, not row mutation.
- Derived tables are convenience projections and can be rebuilt from canonical lineage tables if needed.

## Assumptions recorded

- Event/proof hashes use 64-char lowercase/uppercase hex shape checks.
- `sc_subject_state` and `sc_anomalies` are intentionally lightweight read models updated via row triggers (no expensive rebuild logic in trigger path).
- Verification state is represented by append-only `sc_verification_runs` + upserted `sc_verification_state` latest snapshot.
