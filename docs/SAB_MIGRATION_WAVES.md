# SAB migration waves (first pass)

This is a first-pass sequencing proposal for the SAB migration, ordered by value, reversibility, and risk.

Canonical tracker:

- https://linear.app/conxian-labs/issue/CON-329/create-sab-migration-control-plane-and-dependency-inventory

## Waves

| Wave | Scope | Primary dependencies | Value | Reversibility | Risk | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **W0: Inventory + invariants** | Freeze the dependency list and define "correctness isolation" constraints and evidence gates. | Supabase, Neon, Tableland | High | High | Low | This wave is about preventing hidden coupling and making open questions explicit. |
| **W1: Transactional SQL pilot (Nexus)** | Establish a sovereign PostgreSQL baseline for Nexus derived read models, with schema ownership and rollback. | Neon (phase-out path) | High | Medium | High | Treat Neon as a hosted deployment, not a product dependency; remove Neon-specific assumptions. |
| **W2: Analytics phase-out (proof/visual-proof datasets)** | Replace Supabase-backed analytics with a verifiable, rebuildable derived dataset layer. | Supabase (phase-out path) | High | Medium | High | Requires on-chain checkpointing discipline and clear dataset IDs. |
| **W3: Governance/audit mirrors** | Reduce mirror dependencies and make on-chain audit registries the default discovery mechanism. | Tableland (optional mirror) | Medium | High | Medium | Mirrors remain optional; correctness comes from on-chain registries + proofs. |
| **W4: Ops-plane hosting** | Move dashboards and non-critical control-plane hosting onto sovereign baselines. | Render, Vercel, Firebase | Medium | High | Low/Medium | Keep these strictly out of correctness paths; treat as replaceable UX surfaces. |
| **W5: Sovereign compute baseline** | Reduce reliance on hosted runtime platforms for correctness-critical services (Gateway, oracle hosts). | GCP Cloud Run, AWS/GCP TEE options | High | Low/Medium | High | This is a separate risk class; do not couple with datastore cutovers unless required. |

## Wave exit criteria (program-level)

Each wave is "complete" when:

1. the dependency inventory is updated (what changed, what is now deprecated),
2. readiness gates are updated with evidence, and
3. rollback criteria for that wave have been exercised at least once in a controlled environment.
