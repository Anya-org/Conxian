# SAB migration readiness gates

This document defines first-pass readiness gates and cutover criteria for the SAB migration program.

Canonical tracker:

- Sovereign Coordination Layer: https://sovereign.conxian.com/issue/CON-329/create-sab-migration-control-plane-and-dependency-inventory

This gate is intentionally framed around evidence and invariants, not "progress updates".

## Gate status and review cadence

**Last reviewed:** 2026-04-16

**Canonical live status:** https://sovereign.conxian.com/issue/CON-329/create-sab-migration-control-plane-and-dependency-inventory

Update convention: update this section (including `Last reviewed`) whenever either gate changes (unmet→met or met→unmet), ideally in the same PR/commit that updates the underlying evidence.

## Program-level success metrics

1. **Correctness isolation:** Supabase and Neon are not required for protocol correctness, final auditability, or sovereign accounting truth.
2. **Rebuildability:** all derived datasets can be deterministically rebuilt from Stacks L1 events/state plus the on-chain checkpoint history.
3. **Verifiability:** each derived dataset that is used for decisions has a published dataset ID and an on-chain checkpoint scheme.
4. **Operational control:** sovereign deployments have an owner-operated baseline (ability to run without vendor-specific features).
5. **Local dev parity:** local development can run without Supabase/Neon dependencies for correctness-path testing.

## Prerequisites (milestone alignment)

These prerequisites align pilot readiness expectations to program milestones.

### M0: Architecture baseline (required before any pilot is treated as "ready")

Evidence must exist that:

- the dependency inventory is up to date (what currently depends on Supabase/Neon, by service + dataset), and
- target-state candidates and open questions are explicit.

Canonical evidence pointers:

- [SAB_MIGRATION_DEPENDENCY_INVENTORY.md](SAB_MIGRATION_DEPENDENCY_INVENTORY.md)
- [SAB_DATASTORE_DECISION_LOG.md](SAB_DATASTORE_DECISION_LOG.md)

### Pilot design complete (required before any pilot cutover)

For each pilot domain, "pilot design complete" means the program has commit-pinned artifacts that define:

- the truth model (what is canonical vs derived),
- the in-scope cut list (datasets, consumers, and query surfaces),
- the checkpoint scheme and deterministic rebuild rules, and
- failure modes (safe-halt/degraded behavior) plus rollback triggers.

The evidence can be a spec section, PRD section, or a commit-pinned checklist. The key requirement is that the pilot can be evaluated against something concrete (evidence over assertion).

## Gate 1: Pilot readiness (sovereign baseline pilot)

Gate 1 targets correctness-relevant dependencies (typically the Nexus derived read model) and is considered **met** only when:

- [ ] At least one pilot domain under [Pilot domain readiness gates (CON-335)](#pilot-domain-readiness-gates-con-335) reaches its domain Go decision gate (e.g., `TSQL-G3`) with linked evidence.
- [ ] For that chosen pilot domain, the **common evidence requirements** and **common exit criteria** below are satisfied.

Go decision gates by pilot domain:

- Transactional SQL: `TSQL-G3`
- Proof-carrying analytics: `AN-G3`
- Governance record: `GOV-G3`

### Common evidence requirements (apply to any chosen pilot domain)

- [ ] **Dependency cut list**: which hosted dependency is being piloted (e.g., Neon) and which dataset(s)/services are in-scope.
- [ ] **Target-state spec link**: commit-pinned spec section(s) defining "what correct means" for the pilot.
- [ ] **Sovereign baseline runnable**: a documented way to run the baseline (container compose, k8s manifests, or bare-metal runbook).
- [ ] **Schema/migration ownership**: documented owner and process for evolving schemas.
- [ ] **Checkpoint validation behavior**: defined behavior when checkpoints mismatch (rebuild rules + service degradation rules).
- [ ] **Rollback plan**: explicit rollback trigger and rollback steps.

### Common exit criteria (minimums)

- [ ] Pilot outputs meet the target-state spec and the domain's defined comparison/validation thresholds (dual-run or equivalent) when compared to the existing baseline path (or deltas are explicitly documented and accepted).
- [ ] Any comparison thresholds, SLOs, RPO/RTOs, or divergence deltas referenced by the pilot have commit-pinned evidence (runbook, SLO doc, benchmark artifact, or dashboard snapshot) linked.
- [ ] Pilot can be rebuilt from L1 without manual patching.
- [ ] Pilot roll-forward and rollback are exercised at least once in a controlled environment (including a read-switch rollback where applicable).

### Pilot domain readiness gates (CON-335)

Each domain has:

- **Success metrics** (how we tell it worked)
- **Readiness gates** (what must be true before the program treats the pilot path as ready)
- **No-go and rollback** expectations (when to stop / revert)

#### 1) Transactional SQL pilot (sovereign relational read model)

This gate applies to the Nexus/Glass-Node class of derived read models (currently backed by Postgres/Neon), including any sovereign/self-hostable Postgres baseline.

**Success metrics (minimums)**

- **Correctness parity:** key query surfaces match the hosted baseline for an agreed validation window (validation plan + divergence threshold linked), or any deltas are explicitly documented and accepted.
- **Checkpoint safety:** no unchecked checkpoint mismatches; mismatch behavior is deterministic (rebuild or safe-halt).
- **Performance parity:** p95/p99 latency and throughput are within an agreed delta versus the hosted baseline under the same load profile (SLOs + acceptable delta recorded and linked).
- **Rebuildability:** the in-scope dataset can be rebuilt from Stacks L1 without manual patching.

**Readiness gates (evidence required)**

- **TSQL-G0: Design complete**
  - [ ] Dependency cut list (datasets + consumers + endpoints in scope).
  - [ ] Target-state spec link describing "what correct means" for each in-scope dataset.
  - [ ] Ownership of schema and migrations (who changes what, and how rollouts/rollbacks work).
  - [ ] Checkpoint scheme and deterministic rebuild rules are defined.

- **TSQL-G1: Integration-ready (dual-run + read-switchable)**
  - [ ] Dual-run comparison plan (which queries compare, how often, and the divergence threshold that triggers rollback; threshold evidence linked).
  - [ ] Evidence for dual-run thresholds and SLO deltas is recorded in a commit-pinned artifact, satisfying Gate 1's common exit criteria requirements for thresholds/SLOs.
  - [ ] Read-switch mechanism exists (ability to flip reads between baselines without code changes).
  - [ ] Checkpoint mismatch behavior is defined and wired to explicit service behavior (rebuild vs safe-halt).
  - [ ] Snapshot/export format is defined for any sovereign egress datasets produced from this read model.

- **TSQL-G2: Operational-ready**
  - [ ] Backup/restore plan exists with declared RPO/RTO (RPO/RTO values linked) and evidence of at least one restore drill.
  - [ ] Observability exists for: replication/lag, checkpoint mismatch count, error rate, and p95/p99 latency (dashboards/queries linked).
  - [ ] Operator runbook exists (start/stop, rebuild, safe-halt, rollback, incident triage).

- **TSQL-G3: Go decision (pilot path treated as ready)**
  - [ ] Controlled cutover rehearsal completed (flip reads forward and back) with evidence.
  - [ ] Validation window completed with no correctness regressions beyond the accepted thresholds (threshold evidence linked).

**No-go conditions (do not cut over)**

- No deterministic rebuild path exists for an in-scope dataset.
- Checkpoint mismatch behavior is undefined or would silently serve ambiguous results.
- Read-switch/rollback cannot be executed quickly and safely.

**Rollback triggers (cut over happened; revert now)**

- Sustained correctness divergence beyond the agreed threshold.
- Any evidence of data corruption (e.g., non-deterministic rebuild outputs for the same L1 window).
- Error rates, lag, or latency exceed declared and evidence-linked SLOs for a sustained period (and cannot be mitigated without risking correctness).

Rollback expectation: rollback is primarily a **read flip** back to the prior baseline, followed by rebuild/reconciliation in the sovereign baseline before re-attempting cutover.

#### 2) Proof-carrying analytics pilot (treasury/oracle workflows)

This gate applies to "proof/visual-proof" datasets used as evidence in decision workflows (dashboards, reports, attestations). Analytics layers must remain derived/query systems and must not become a new source of truth.

Canonical constraints to align to:

- [Sovereign data migration / sovereign egress spec](../openspec/changes/sovereign-data-migration-sovereign-egress/specs/sovereign-data-migration-sovereign-egress/spec.md)
- [SAB datastore mapping spec](../openspec/specs/sab-datastore-mapping/spec.md)

**Success metrics (minimums)**

- **Deterministic snapshots:** the same L1 window produces the same canonical snapshot bytes (schema + ordering + serialization).
- **Checkpointed evidence:** each published dataset snapshot is checkpointed on-chain and can be verified independently.
- **Proof verifiability:** proofs (or verification artifacts) can be checked by an independent verifier process without relying on a vendor UI.
- **Operational control:** the pipeline has explicit failure modes (safe-halt/degraded) and does not leak enclave-only secrets.

**Readiness gates (evidence required)**

- **AN-G0: Design complete**
  - [ ] Dataset definitions exist (schema, canonical ordering, serialization format).
  - [ ] Checkpoint scheme is selected and documented (including how snapshot hashes are computed).
  - [ ] "Not a source of truth" constraints are documented for all consumers (what they may and may not assume).
  - [ ] Threat model exists (data poisoning, replay, proof invalidity, and ZSE (Zero Secret Egress) constraints; see [DOCUMENTATION_CLASSIFICATION.md](./DOCUMENTATION_CLASSIFICATION.md)).

- **AN-G1: Integration-ready (end-to-end verification)**
  - [ ] Reproducible pipeline exists from L1 inputs → snapshot → checkpoint → proof/verification artifact.
  - [ ] Independent verification procedure exists (a script/runbook) that validates snapshot + checkpoint + proof.
  - [ ] Consumers can be switched between old/new analytics paths without changing correctness semantics.

- **AN-G2: Operational-ready**
  - [ ] Observability exists for: proof generation failures, verification failures, dataset lag, and checkpoint publication.
  - [ ] Runbook exists for: safe-halt, replay/backfill, and rollback.

- **AN-G3: Go decision (pilot path treated as ready)**
  - [ ] Parallel-run window completed with evidence that published snapshots and proofs validate end-to-end.

**No-go conditions (do not cut over)**

- Snapshots are not deterministic or cannot be reproduced from the same L1 inputs.
- Checkpointing is missing or proofs cannot be verified independently.
- Any consumer would treat the analytics layer as canonical truth.

**Rollback triggers (cut over happened; revert now)**

- Any proof verification failures for published datasets that are not explainable as transient and non-corrupting.
- Evidence of non-deterministic snapshots (same L1 window yields different hashes).

Rollback expectation: stop publishing the affected dataset version, switch consumers back to the prior evidence path, and backfill/rebuild to the last known-good checkpoint.

#### 3) Governance record pilot (governance + audit anchoring)

This gate applies to governance/audit records where the default truth and discoverability must be anchored on-chain. Optional mirrors (Tableland/Fluree/Kwil) may improve query ergonomics but must never become correctness dependencies.

Canonical constraints to align to:

- [SAB datastore mapping spec](../openspec/specs/sab-datastore-mapping/spec.md)

**Success metrics (minimums)**

- **Completeness:** all in-scope governance/audit events are recorded on-chain (or as on-chain-referencable commitments) with no gaps for the validation window.
- **Mirror non-authoritativeness:** disabling any mirror does not prevent governance/audit truth discovery (at worst it reduces UX/query convenience).
- **Rebuildability:** any mirror/index can be rebuilt from on-chain records.

**Readiness gates (evidence required)**

- **GOV-G0: Design complete**
  - [ ] In-scope record types are listed (what counts as a governance/audit record in this pilot).
  - [ ] Source-of-truth rule is explicit: on-chain record/commitment is authoritative; mirrors are optional.
  - [ ] Indexing and reconciliation rules are defined (how mismatches are detected and how services respond).

- **GOV-G1: Integration-ready**
  - [ ] End-to-end flow exists: write/anchor record → index it → serve queries from the canonical source and/or mirror.
  - [ ] Mismatch behavior is explicit (rebuild, safe-halt, or serve-from-chain-only).
  - [ ] Consumers can be switched to a mirror-free mode without breaking correctness.

- **GOV-G2: Operational-ready**
  - [ ] Observability exists for: indexing lag, mismatch counts, and record publication failures.
  - [ ] Runbook exists for: mirror rebuild, reconciliation, and rollback to chain-only reads.

- **GOV-G3: Go decision (pilot path treated as ready)**
  - [ ] Parallel-run window completed with evidence that records are anchored and can be independently verified.

**No-go conditions (do not cut over)**

- Any consumer requires a mirror for correctness (mirror is an availability dependency).
- Mismatch handling is undefined or would silently accept divergent governance/audit records.

**Rollback triggers (cut over happened; revert now)**

- Missing or malformed on-chain records for in-scope event types.
- Mirror/index divergence that cannot be reconciled without risking incorrect governance/audit state exposure.

Rollback expectation: move to chain-only reads (or the prior baseline), disable mirrors if needed, and backfill/rebuild the mirror from the canonical record history.

## Gate 2: Cutover readiness (Phase 5 "clean break")

This gate is satisfied when Supabase and Neon can be removed from correctness-critical paths without loss of verifiability or operational control.

### Evidence requirements

- [ ] **Full dependency inventory complete**: all Supabase/Neon usage is mapped by service and dataset.
- [ ] **Target-state decisions complete (or explicitly open)**: for each major dependency, the target-state is either decided or an open question is explicitly recorded in [SAB_DATASTORE_DECISION_LOG.md](SAB_DATASTORE_DECISION_LOG.md).
- [ ] **Data migration strategy per dataset**: each dataset has a plan (rebuild from L1, snapshot import, dual-write, or deprecate).
- [ ] **Cutover criteria**: explicit "go/no-go" criteria with evidence pointers.
- [ ] **Rollback criteria**: explicit "rollback now" criteria with evidence pointers.
- [ ] **Operational runbooks**: failure mode expectations for the new baseline (backup/restore, rebuild, incident response).

### Cutover criteria (first pass)

All of the following must be true:

- [ ] No production correctness-path read depends on Supabase or Neon.
- [ ] Sovereign egress datasets are produced from sovereign baselines and are checkpoint-verifiable.
- [ ] Governance/audit records are anchored on-chain; any mirrors are non-authoritative.
- [ ] Production can maintain correctness through a full checkpoint interval without Supabase/Neon availability, either by continuing from sovereign baselines or by entering a defined safe-halt/degraded mode with documented behavior.
