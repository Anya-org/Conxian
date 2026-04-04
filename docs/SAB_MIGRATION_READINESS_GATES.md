# SAB migration readiness gates

This document defines first-pass readiness gates and cutover criteria for the SAB migration program.

Canonical tracker:

- https://linear.app/conxian-labs/issue/CON-329/create-sab-migration-control-plane-and-dependency-inventory

This gate is intentionally framed around evidence and invariants, not "progress updates".

## Gate status and review cadence

**Last reviewed:** 2026-04-04

**Canonical live status:** https://linear.app/conxian-labs/issue/CON-329/create-sab-migration-control-plane-and-dependency-inventory

Update convention: update this section (including `Last reviewed`) whenever either gate changes (unmet→met or met→unmet), ideally in the same PR/commit that updates the underlying evidence.

## Program-level success metrics

1. **Correctness isolation:** Supabase and Neon are not required for protocol correctness, final auditability, or institutional accounting truth.
2. **Rebuildability:** all derived datasets can be deterministically rebuilt from Stacks L1 events/state plus the on-chain checkpoint history.
3. **Verifiability:** each derived dataset that is used for decisions has a published dataset ID and an on-chain checkpoint scheme.
4. **Operational control:** sovereign deployments have an owner-operated baseline (ability to run without vendor-specific features).
5. **Local dev parity:** local development can run without Supabase/Neon dependencies for correctness-path testing.

## Gate 1: Pilot readiness (sovereign baseline pilot)

This gate is satisfied when at least one correctness-relevant dependency (typically the Nexus derived read model) has a sovereign baseline that can be exercised end-to-end.

### Evidence requirements

- [ ] **Dependency cut list**: which hosted dependency is being piloted (e.g., Neon) and which dataset(s)/services are in-scope.
- [ ] **Target-state spec link**: commit-pinned spec section(s) defining "what correct means" for the pilot.
- [ ] **Sovereign baseline runnable**: a documented way to run the baseline (container compose, k8s manifests, or bare-metal runbook).
- [ ] **Schema/migration ownership**: documented owner and process for evolving schemas.
- [ ] **Checkpoint validation behavior**: defined behavior when checkpoints mismatch (rebuild rules + service degradation rules).
- [ ] **Rollback plan**: explicit rollback trigger and rollback steps.

### Exit criteria

- [ ] Pilot produces identical query results (or an explicitly documented superset) for the in-scope datasets when compared to the hosted baseline.
- [ ] Pilot can be rebuilt from L1 without manual patching.
- [ ] Pilot roll-forward and rollback are exercised at least once in a controlled environment.

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
- [ ] Institutional egress datasets are produced from sovereign baselines and are checkpoint-verifiable.
- [ ] Governance/audit records are anchored on-chain; any mirrors are non-authoritative.
- [ ] Production can maintain correctness through a full checkpoint interval without Supabase/Neon availability, either by continuing from sovereign baselines or by entering a defined safe-halt/degraded mode with documented behavior.
