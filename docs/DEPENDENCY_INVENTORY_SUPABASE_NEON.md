# Supabase + Neon dependency inventory (current state) — CON-337

_Snapshot date:_ 2026-04-04

This document inventories **current, evidenced** touchpoints to **Supabase** and **Neon** across the Conxian service surfaces pinned in this repository.

Because this repo follows **Zero Secret Egress (ZSE)**, production connection strings, project refs, keys, internal hostnames, and internal endpoints/URLs are intentionally not present here. Wherever possible, each item is labeled with an **evidence level**.

**Redaction convention:** any internal endpoint/URL/hostname and any secret material (connection strings, project refs, keys) must be redacted so that no secret material remains. Use the placeholder `<redacted>` for all redacted portions. For URIs, keep only the scheme and replace everything after `://` with `<redacted>` (e.g., `mcp://<redacted>`). This applies to any referenced evidence artifacts pinned in this repo.

## Evidence levels

- **Code**: direct code/config usage in this repo or a pinned submodule
- **Spec/Doc**: described as current-state in docs/specs, but no direct integration code found
- **Dependency-only**: package/lockfile contains an optional or transitive dependency, with no direct imports found

## Inventory (Supabase)

| Owning surface / service | Supabase capability | Business function | Role classification | Downstream consumers | Evidence |
| --- | --- | --- | --- | --- | --- |
| `Fiscal-Vault-Oracle` (OpenClaw engine) | **DB + API bridge** via MCP with table-level permissions (`runway_metrics`, `audit_manifest`, `treasury_actions`, `dlc_state_updates`) | Treasury runway monitoring + governed treasury action logging (144-block cadence) | **Analytical + Governance + Transactional** (write path for off-chain action logs; not canonical truth) | OpenClaw runtime; `conxian-nexus` provides external triggers (`NEW_BITCOIN_BLOCK`); audit consumers via DWN | **Code**: `Fiscal-Vault-Oracle/TREASURY_MCP_CONFIG.json`, `Fiscal-Vault-Oracle/BOS_INTEGRATION_MAP.md` |
| `Fiscal-Vault-Oracle` (Treasury Oracle schema) | **DB schema + RLS** (`cxn_*` tables; RLS enabled; “read-only for authenticated clients”) | Treasury oracle read model (yield/runway/principal + timelock status) | **Analytical + Governance** (proof/visual-proof datasets) | “Conxius/Gateway” authenticated reads (per RLS note) | **Code**: `docs/CXN_TREASURY_ORACLE_SCHEMA.sql` |
| `Sovereign-Ops-Orchestrator` (Ops Engine) | **DB** (implied) used as state layer for Linear webhook wiring (`ats_violations`, `deployment_efficiency`, `exit_velocity`) | Operational integrity + performance/valuation telemetry | **Governance + Analytical** | Render-hosted internal dashboard (“Stitch Dashboard”); internal operator workflows | **Spec/Doc**: `Sovereign-Ops-Orchestrator/LINEAR_WIRING.md` |
| `Sovereign-Strategy-Nexus` (ZK Data Room) | **DB** (implied) as sources for proofs (`yield_events`, `ip_audit_logs`, `runway_metrics`, `deployment_efficiency`) | M&A readiness: verifiable proof surfaces without raw data disclosure | **Governance + Analytical** | External acquirers/auditors consuming proof artifacts; `conxian-nexus` as verifier in the flow | **Spec/Doc**: `Sovereign-Strategy-Nexus/docs/ZK_DATA_ROOM_SCHEMA.md` |
| `conxian-nexus` (Revenue Intelligence mapping) | **DB** (planned) “update ARR/MRR/Churn metrics in Supabase/Redis” | Revenue attribution + financial intelligence | **Analytical** | Likely Ops dashboards / reporting surfaces | **Code (stub only)**: `conxian-nexus/src/executor/mod.rs` (marked `[STUB]`) + `docs/MISSING_CHIPS_BRIEF.md` |
| BOS / Compliance posture | **Data governance constraint**: “Zero local PII storage in Supabase” | SARB exchange-control / compliance posture | **Governance** | Compliance/audit review surfaces | **Spec/Doc**: `conxian-business/SARB_COMPLIANCE_REPORT.stub.json` |

### Supabase scope notes (what we did **not** find in-repo)

- No evidence of **Supabase Auth** integration beyond Postgres `authenticated` role references in RLS policies.
- No evidence of **Supabase Storage** buckets.
- No evidence of **Supabase Edge Functions**.
- No direct `@supabase/*` client SDK usage in pinned code.

## Inventory (Neon)

| Owning surface / service | Neon capability | Business function | Role classification | Downstream consumers | Evidence |
| --- | --- | --- | --- | --- | --- |
| `conxian-nexus` (Rust) | **Postgres persistence** (current-state described as “currently Neon”) powering Nexus read model (state history, event logs, MMR persistence) | Derived read model (“Glass Node”) for high-concurrency state queries + verifiable history primitives | **Transactional + Routing** (derived query layer; canonical truth is Stacks L1) | Gateway endpoints; internal/external consumers of state/proof APIs | **Code + Spec/Doc**: Postgres usage in `conxian-nexus/src/**` + `openspec/specs/sab-datastore-mapping/spec.md` + `conxius-platform/GAPS.md` |
| `conxius-platform` (orchestration) | Neon described as “serverless Postgres for Nexus state history and high-concurrency event logs” | Platform-level persistence dependency for Nexus/Gateway stack | **Transactional** | Local dev uses `postgres:15` container; prod provider not captured in this repo | **Spec/Doc**: `conxius-platform/GAPS.md`; **Code**: `conxius-platform/.env.example`, `conxius-platform/docker-compose.yml` (provider unspecified) |
| `conxian-gateway` (docs) | Neon described as “institutional ledger storage” | Institutional API surface / ERP translation mapping | **Routing** | ERP/OData simulation paths | **Spec/Doc only**: `conxian-gateway/ENHANCEMENT_PLAN.md` (no DB integration code found) |
| `conxius-platform/services/elizaos-plugin-conxian` | Optional **Neon serverless driver** appears as an optional peer dependency via `drizzle-orm` (`@neondatabase/serverless`) | Potential DB connector capability, not proven used | **Unknown (dependency-only)** | N/A | **Dependency-only**: `conxius-platform/pnpm-lock.yaml`, `conxius-platform/services/elizaos-plugin-conxian/package-lock.json` |

### Neon scope notes (what we did **not** find in-repo)

- No Neon project identifiers, branch names, or connection pooling/TLS settings.
- No direct `@neondatabase/serverless` imports in application code.

## Downstream consumer summary (cross-cutting)

- **Core services**: `conxian-nexus` (derived state) → `conxian-gateway` (institutional API) → UI surfaces.
- **UI surfaces**: `conxian-ui`, `conxius-platform/services/admin-dashboard`, `showcase-dapp` appear to consume APIs rather than connect directly to Supabase/Neon.
- **Internal dashboards**: “Stitch Dashboard” (Render-hosted) visualizes Supabase state (docs-only evidence).
- **External consumers**: ZK Data Room / institutional egress consumers rely on derived datasets and checkpoint verification (OpenSpec).

## Migration constraints (captured from OpenSpec)

These are the constraints that impact any migration away from Supabase/Neon:

- **Correctness isolation**: Supabase and Neon **must not** be required for protocol correctness, final auditability, or institutional accounting truth.
- **Supabase phase-out (analytics)**:
  - deterministic snapshot export required (schema + ordering + serialization)
  - on-chain checkpointing required (e.g., `SAB-CHECKPOINT-V1`)
- **Neon phase-out (transactional SQL for Nexus)**:
  - Nexus persistence must have a sovereign/self-hostable Postgres baseline
  - Nexus must not rely on Neon-specific features (branching, proprietary pooling, hosted-only extensions)
  - local dev parity required (Postgres + Redis under developer control)

Sources: `openspec/changes/sovereign-data-migration-institutional-egress/specs/sovereign-data-migration-institutional-egress/spec.md`, `openspec/specs/sab-datastore-mapping/spec.md`.

## Major unknowns / missing evidence (to close)

1. **Supabase project metadata**: project ref, region, Postgres version/extensions, enabled features (Realtime, Storage, Functions), RLS policy ownership, migration tooling/owner.
2. **Supabase dataset list**: authoritative list of tables actually present today (`runway_metrics`, `yield_events`, `ip_audit_logs`, `exit_velocity`, etc.) vs aspirational schema/docs.
3. **Neon runtime truth**: which environments actually point `conxian-nexus` (and any other services) at Neon vs self-hosted Postgres.
4. **Neon operational constraints**: pooling strategy, TLS requirements, backup/restore semantics, and any required extensions.
5. **Direct consumers**: which services connect directly to Supabase/Neon vs going through Gateway/Nexus APIs.

---

If/when we can safely pull a **redacted** list of environment variables (keys only, no values) from the Linear Virtual Office, we can upgrade several “Spec/Doc” items to “Code” and attach concrete migration constraints per environment.

---

SAB. © 2026 Conxian-Labs.
