# SAB migration waves (CON-336)

This document sequences the SAB migration program into ordered waves, prioritized by **strategic value**, **reversibility**, and **operational risk**.

Primary tracker: https://sovereign.conxian.com/issue/CON-336/sequence-sab-migration-waves-by-value-reversibility-and-risk

Related:

- https://sovereign.conxian.com/issue/CON-329/create-sab-migration-control-plane-and-dependency-inventory
- https://sovereign.conxian.com/issue/CON-335/define-pilot-readiness-gates-and-evidence-requirements
- https://sovereign.conxian.com/issue/CON-337/inventory-current-supabase-and-neon-dependencies-by-service

## Canonical status and legacy-wave reconciliation

This file (`docs/SAB_MIGRATION_WAVES.md`) is the **canonical migration-wave source**.

The legacy 4-wave framing in `docs/operations/SAB_MIGRATION_WAVES.md` is retained only as a historical pointer and is **non-canonical**.

### Mapping: legacy 4-wave framing → canonical wave model

| Legacy framing (non-canonical) | Canonical mapping in this document | Reconciliation notes |
| :--- | :--- | :--- |
| **Legacy Wave 1: Governance & Transparency** | **W0: Inventory + invariants** (plus governance checks that continue through W1–W6) | Governance artifacts are no longer treated as a standalone migration endpoint; they are a prerequisite and recurring control. |
| **Legacy Wave 2: Core Protocol & Mainnet Cutover** | Primarily **W1: Transactional SQL pilot**, with prerequisite ties to **W0** and follow-on containment in **W2** | What was called “cutover” is now split into a reversible pilot first, then correctness isolation. |
| **Legacy Wave 3: Institutional Ingress & TEE Enforcement** | Spans **W2: Supabase correctness isolation**, **W3: Analytics phase-out**, and selected **W6: Sovereign compute baseline** controls | Ingress/TEE readiness depends on datastore correctness and operational hosting posture, so it is distributed across waves instead of isolated in one wave. |
| **Legacy Wave 4: BitVM2 & sBTC Maturity** | Cross-cutting architecture track aligned to **W4–W6** promotion gates, with concrete target-state defined in `docs/architecture/BITVM2_SBTC_BRIDGE_TARGET_ARCHITECTURE.md` | BitVM2/sBTC readiness is controlled by explicit promotion/rollback gates and signer-boundary checks rather than a single terminal wave. |

### Translation rule for issue and runbook references

When older issues or runbooks still mention “Wave 1–4” (legacy framing), map them to canonical wave IDs (`W0`…`W6`) and gate evidence requirements before using them for execution decisions.

## Scoring rubric (why this ordering is explainable)

- **Strategic value:** reduces correctness dependence on Supabase/Neon, increases rebuildability from Stacks L1, improves sovereign/audit readiness.
- **Reversibility:** rollback by flipping reads, rebuilding derived state, or re-pointing clients without data loss.
- **Operational risk:** likelihood of downtime, data divergence, or irrecoverable hidden coupling (especially on write paths).

## Waves

| Wave | Scope | Primary dependencies | Value | Reversibility | Risk | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **W0: Inventory + invariants** | Freeze the dependency list and define correctness isolation constraints + evidence gates. | Supabase, Neon, Tableland | High | High | Low | Prevent hidden coupling before any cutovers; make open questions explicit. |
| **W1: Transactional SQL pilot (Nexus "Glass Node")** | Establish a sovereign PostgreSQL baseline for Nexus derived read models, with dual-run + rollback. | Neon (phase-out path) | High | Medium | High | Treat Neon as a hosted deployment, not a product dependency; remove Neon-specific assumptions. "Glass Node" = derived-only Nexus read model that is checkpoint-verifiable and read-switchable for rollback. |
| **W2: Supabase correctness isolation (treasury/oracle state)** | Contain Supabase write-path risk: move correctness paths to derived-only, checkpointed state with explicit ownership. | Supabase (phase-out path) | High | Medium | High | Requires per-service dependency truth and a decision on whether Model Context Protocol (MCP) remains the stable abstraction boundary (see [ERP_MCP_HANDSHAKE_SPEC.md](./ERP_MCP_HANDSHAKE_SPEC.md) and [SAB_MIGRATION_DEPENDENCY_INVENTORY.md](./SAB_MIGRATION_DEPENDENCY_INVENTORY.md)). |
| **W3: Analytics phase-out (proof/visual-proof datasets)** | Replace Supabase-backed analytics with a verifiable, rebuildable derived dataset layer. | Supabase analytics (phase-out path) | High | Medium | High | Depends on checkpoint discipline + a target-state decision for analytics (see [SAB-DS-002](./SAB_DATASTORE_DECISION_LOG.md#sab-ds-002)). |
| **W4: Governance/audit mirrors** | Reduce mirror dependencies; make on-chain audit registries the default discovery mechanism. | Tableland (optional mirror), Fluree/Kwil (candidates) | Medium | High | Medium | Mirrors remain optional; must never become correctness dependencies. |
| **W5: Ops-plane hosting** | Move dashboards and non-critical control-plane hosting onto sovereign baselines. | Render, Vercel, Firebase | Medium | High | Low/Medium | Keep strictly out of correctness paths; treat as replaceable UX surfaces. |
| **W6: Sovereign compute baseline** | Reduce reliance on hosted runtimes for correctness-critical services (Gateway, oracle hosts). | GCP Cloud Run, AWS/GCP TEE options | High | Low/Medium | High | Separate risk class; do not couple with datastore cutovers unless required. |

## Wave 1 scope (explicit + bounded)

**In scope (Wave 1)**

- Replace **Neon** as the backing Postgres for the **Nexus derived read model** with a **sovereign/self-hostable Postgres baseline**.
- Prove **rebuildability from Stacks L1** for the in-scope Nexus datasets (derived-only semantics).
- Add a **dual-run** cutover mechanism (old + new) and a **fast rollback** (flip reads back).
- Produce the evidence items required by the pilot readiness gate (cut list, runnable baseline, schema ownership, checkpoint mismatch behavior, rollback plan).

**Explicitly out of scope (defer from Wave 1)**

- Any Supabase phase-out work (including BOS state layer + Fiscal Vault Oracle tables).
- Any analytics engine selection or "proof/visual-proof dataset" migration (Space and Time / alternatives).
- Tableland / Fluree / Kwil mirror decisions or migrations.
- Runtime hosting moves (Cloud Run → dedicated hosts / enclave-adjacent).
- Ops dashboard hosting moves unless required strictly to observe Wave 1 safely.

**Cutover-sensitive paths (Wave 1)**

- Anything relying on Nexus query results (notably Gateway-facing endpoints) must be **read-switchable** and **rollback-first**.
- Any “sovereign egress” outputs sourced from the Nexus read model only proceed if datasets remain verifiable via checkpoints and can be regenerated from L1.

## Blockers + sequencing dependencies

1. Per-service dependency truth must be finished for cutover readiness (especially Supabase write paths): https://linear.app/conxian-labs/issue/CON-337/inventory-current-supabase-and-neon-dependencies-by-service
2. Pilot readiness evidence needs an explicit cut list and rollback trigger: https://linear.app/conxian-labs/issue/CON-335/define-pilot-readiness-gates-and-evidence-requirements
3. Analytics target-state is still open ([SAB-DS-002](./SAB_DATASTORE_DECISION_LOG.md#sab-ds-002)), so it must not contaminate Wave 1 sequencing.
4. Model Context Protocol (MCP) boundary decision is a real dependency for a clean Supabase bridge replacement (keep stable interface vs redesign); leaving it open blocks Wave 2 planning.

## Parallelizable work (while Wave 1 executes)

- Finalize dataset IDs + checkpoint scheme usage for any dataset used in decision workflows.
- Start the “Supabase write-path containment” design (dual-write vs rebuild vs deprecate) without touching production cutovers.
- Audit which mirrors are mistakenly treated as evidence sources (so Wave 4 stays low risk).
- Audit which UX surfaces/dashboards are mistakenly treated as evidence sources (so Wave 5 stays low risk).

## Recommendation: what to defer from Wave 1

Defer everything that changes **Supabase write paths**, **analytics engine selection**, or **compute hosting** to Waves 2+.

Wave 1 stays strictly a **Neon → sovereign Postgres pilot for the Nexus derived read model**, plus dual-run + rollback proof.

## Wave exit criteria (program-level)

Each wave is "complete" when:

1. the dependency inventory is updated (what changed, what is now deprecated),
2. readiness gates are updated with evidence, and
3. rollback criteria for that wave have been exercised at least once in a controlled environment.
