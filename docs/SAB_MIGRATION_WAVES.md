# SAB migration waves (CON-336)

This document sequences the SAB migration program into ordered waves, prioritized by **strategic value**, **reversibility**, and **operational risk**.

Primary tracker: https://linear.app/conxian-labs/issue/CON-336/sequence-sab-migration-waves-by-value-reversibility-and-risk

Related:

- https://linear.app/conxian-labs/issue/CON-329/create-sab-migration-control-plane-and-dependency-inventory
- https://linear.app/conxian-labs/issue/CON-335/define-pilot-readiness-gates-and-evidence-requirements
- https://linear.app/conxian-labs/issue/CON-337/inventory-current-supabase-and-neon-dependencies-by-service

## Scoring rubric (why this ordering is explainable)

- **Strategic value:** reduces correctness dependence on Supabase/Neon, increases rebuildability from Stacks L1, improves institutional/audit readiness.
- **Reversibility:** rollback by flipping reads, rebuilding derived state, or re-pointing clients without data loss.
- **Operational risk:** likelihood of downtime, data divergence, or irrecoverable hidden coupling (especially on write paths).

## Waves

| Wave | Scope | Primary dependencies | Value | Reversibility | Risk | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **W0: Inventory + invariants** | Freeze the dependency list and define correctness isolation constraints + evidence gates. | Supabase, Neon, Tableland | High | High | Low | Prevent hidden coupling before any cutovers; make open questions explicit. |
| **W1: Transactional SQL pilot (Nexus "Glass Node")** | Establish a sovereign PostgreSQL baseline for Nexus derived read models, with dual-run + rollback. | Neon (phase-out path) | High | Medium | High | Treat Neon as a hosted deployment, not a product dependency; remove Neon-specific assumptions. "Glass Node" = derived-only Nexus read model that is checkpoint-verifiable and read-switchable for rollback. |
| **W2: Supabase correctness isolation (treasury/oracle state)** | Contain Supabase write-path risk: move correctness paths to derived-only, checkpointed state with explicit ownership. | Supabase (phase-out path) | High | Medium | High | Requires per-service dependency truth and a decision on whether Model Context Protocol (MCP) remains the stable abstraction boundary. |
| **W3: Analytics phase-out (proof/visual-proof datasets)** | Replace Supabase-backed analytics with a verifiable, rebuildable derived dataset layer. | Supabase analytics (phase-out path) | High | Medium | High | Depends on checkpoint discipline + a target-state decision for analytics (see `SAB-DS-002`). |
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
- Any “institutional egress” outputs sourced from the Nexus read model only proceed if datasets remain verifiable via checkpoints and can be regenerated from L1.

## Blockers + sequencing dependencies

1. Per-service dependency truth must be finished for cutover readiness (especially Supabase write paths): https://linear.app/conxian-labs/issue/CON-337/inventory-current-supabase-and-neon-dependencies-by-service
2. Pilot readiness evidence needs an explicit cut list and rollback trigger: https://linear.app/conxian-labs/issue/CON-335/define-pilot-readiness-gates-and-evidence-requirements
3. Analytics target-state is still open (`SAB-DS-002` in `docs/SAB_DATASTORE_DECISION_LOG.md`), so it must not contaminate Wave 1 sequencing.
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
