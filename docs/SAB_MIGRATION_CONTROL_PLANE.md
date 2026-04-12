# SAB migration control plane (CON-329)

This is the coordinating "source of truth" artifact for the SAB infrastructure migration. It centralizes:

- the dependency inventory (current-state and target-state mapping)
- the domain-to-datastore decision log
- readiness gates + cutover criteria
- recommended migration waves

## Canonical tracker

- Linear: [CON-329][con-329]

[con-329]: https://linear.app/conxian-labs/issue/CON-329/create-sab-migration-control-plane-and-dependency-inventory

Related execution issues (parallelized):

- https://linear.app/conxian-labs/issue/CON-331/pilot-proof-carrying-analytics-for-treasury-and-oracle-workflows
- https://linear.app/conxian-labs/issue/CON-332/define-sab-migration-timeline-cutover-waves-and-rollback-plan
- https://linear.app/conxian-labs/issue/CON-333/define-governance-and-immutable-record-architecture-for-sab
- https://linear.app/conxian-labs/issue/CON-334/map-target-datastore-decisions-by-sab-data-domain
- https://linear.app/conxian-labs/issue/CON-335/define-pilot-readiness-gates-and-evidence-requirements
- https://linear.app/conxian-labs/issue/CON-336/sequence-sab-migration-waves-by-value-reversibility-and-risk
- https://linear.app/conxian-labs/issue/CON-337/inventory-current-supabase-and-neon-dependencies-by-service

## Status and review cadence

**Last reviewed:** 2026-04-05

**Canonical tracker / live status:** [CON-329][con-329]

**Review cadence:** at least monthly, and additionally within the same PR/commit whenever any program-level milestone changes (M0-M2) or readiness-gate evidence is updated.

Update convention: on every review (cadence- or milestone-driven), bump `Last reviewed` in the same PR/commit that updates the underlying evidence (or a dedicated PR if no other content changes are needed).

## Canonical artifacts

- Dependency inventory: [SAB_MIGRATION_DEPENDENCY_INVENTORY.md](SAB_MIGRATION_DEPENDENCY_INVENTORY.md)
- Supabase + Neon inventory (service-level): [DEPENDENCY_INVENTORY_SUPABASE_NEON.md](DEPENDENCY_INVENTORY_SUPABASE_NEON.md)
- Domain-to-datastore decision log: [SAB_DATASTORE_DECISION_LOG.md](SAB_DATASTORE_DECISION_LOG.md)
- Immutable governance and record architecture: [SAB_IMMUTABLE_GOVERNANCE_RECORD_ARCHITECTURE.md](SAB_IMMUTABLE_GOVERNANCE_RECORD_ARCHITECTURE.md)
- Readiness gates & cutover criteria: [SAB_MIGRATION_READINESS_GATES.md](SAB_MIGRATION_READINESS_GATES.md)
- Migration waves: [SAB_MIGRATION_WAVES.md](SAB_MIGRATION_WAVES.md)

Baseline specs that constrain decisions:

- SAB datastore mapping: [openspec/specs/sab-datastore-mapping/spec.md](../openspec/specs/sab-datastore-mapping/spec.md)
- Sovereign data migration & institutional egress synthesis: [openspec/changes/sovereign-data-migration-institutional-egress/specs.md](../openspec/changes/sovereign-data-migration-institutional-egress/specs.md)

## Working rules (program-level)

1. **Canonical truth remains Stacks L1.** All off-chain stores are derived/query layers and must be rebuildable.
2. **Correctness isolation:** Supabase and Neon must not be required for protocol correctness, final auditability, or institutional accounting truth.
3. **Zero Secret Egress (ZSE):** no enclave-only secrets or signing keys in any non-enclave datastore.
4. **Evidence over assertion:** readiness gates are only "met" when linked evidence exists (commit-pinned docs, checklists, or reproducible scripts).

## Milestones (for dashboard updates)

| Milestone | What it means | Evidence pointer |
| :--- | :--- | :--- |
| **M0: Architecture baseline** | Inventory exists, target-state candidates are mapped, and open questions are explicit. | [SAB_MIGRATION_DEPENDENCY_INVENTORY.md](SAB_MIGRATION_DEPENDENCY_INVENTORY.md), [SAB_DATASTORE_DECISION_LOG.md](SAB_DATASTORE_DECISION_LOG.md) |
| **M1: Pilot-ready** | A sovereign baseline exists for at least one correctness-relevant dependency with a controlled cutover plan and rollback. | [SAB_MIGRATION_READINESS_GATES.md](SAB_MIGRATION_READINESS_GATES.md) (Pilot gate) |
| **M2: Cutover-ready** | Phase 5 "clean break" criteria are evidenced; Supabase/Neon can be removed from correctness-critical paths. | [SAB_MIGRATION_READINESS_GATES.md](SAB_MIGRATION_READINESS_GATES.md) (Cutover gate) |
