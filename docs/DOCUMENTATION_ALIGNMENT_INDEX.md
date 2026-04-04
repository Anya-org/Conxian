# Documentation alignment index (conxian-business)

This page is a practical index of the documentation already present in this repository, focused on helping active work reference existing material instead of recreating it.

## Classification rules

- **Canonical**: the current “source of truth” for a domain. If two docs disagree, update the non-canonical doc to match the canonical one.
- **Supporting**: helpful context, audits, reports, briefs, or deep dives that clarify (but don’t define) the system.
- **Public-safe**: ok to link in public contexts and external conversations.
- **Internal-only**: strategic / operational / security-adjacent content that must live in the Conxian Linear workspace (the repo may contain a stub placeholder so existing links resolve).

Notes:

- This repo is public. “Internal-only” material should not be stored here beyond a stub; see https://linear.app/conxian-labs/issue/CON-256.
- OpenSpec change sets typically have 4 layers: `proposal.md` (intent), `design.md` (architecture), `specs/*/spec.md` (requirements), `tasks.md` (execution).

## 1) Repo navigation (start here)

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `README.md` | Canonical | Public-safe | Repository entrypoint and overall orientation. |
| `SUMMARY.md` | Canonical | Public-safe | GitBook table of contents (used for docs navigation; Pages publishing is allowlisted). |
| `docs/README.md` | Supporting | Public-safe | “Docs hub” landing page. |
| `docs/BOS_BUSINESS_BUILDOUT.md` | Canonical | Public-safe | Repo business purpose, business-unit placement, governance + ownership model, and public/internal split. |
| `ARCHIVE_MIGRATION.md` | Canonical | Public-safe | ZSE placeholder + pointer to Linear Virtual Office for legacy material. |

## 2) BOS (Business Operations System)

These are the “operating-model” documents that explain how BOS components relate, how execution is intended to be wired into Linear, and what gets measured.

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `conxian-business/SERVICE_LOOP.md` | Canonical | Public-safe | BOS service loop (how client/supplier loops connect). |
| `conxian-business/BOS_STATE_MACHINE.json` | Supporting | Internal-only | BOS state machine definition (automation substrate). |
| `Sovereign-Ops-Orchestrator/LINEAR_WIRING.md` | Canonical | Internal-only | Intended Linear ↔ state-layer wiring and webhook triggers. |
| `Sovereign-Ops-Orchestrator/DEPLOYMENT_EFFICIENCY.md` | Supporting | Internal-only | Bottleneck and deployment efficiency metrics. |
| `Sovereign-Strategy-Nexus/REALTIME_M&A_VELOCITY.md` | Supporting | Internal-only | Strategy velocity tracking and exit-readiness framing. |
| `Sovereign-Strategy-Nexus/docs/SOVEREIGN_MOI_ALIGNMENT.md` | Canonical | Internal-only | “MOI” alignment source for Strategy Nexus narratives. |
| `Sovereign-Strategy-Nexus/docs/ZK_DATA_ROOM_SCHEMA.md` | Canonical | Internal-only | ZK data room schema (what proofs/data exist). |
| `Sovereign-Strategy-Nexus/docs/SOVEREIGN_PITCH_DECK_NARRATIVE.md` | Supporting | Internal-only | Pitch narrative scaffolding. |
| `Fiscal-Vault-Oracle/SOVEREIGN_RUNWAY.md` | Canonical | Internal-only | Treasury runway and yield execution constraints. |
| `Fiscal-Vault-Oracle/LSEG_MCP_AUDIT.md` | Supporting | Internal-only | LSEG MCP audit context for treasury/oracle integrity. |
| `Nakamoto-Guardian/ANTI_FRAGILITY_LOOP.md` | Canonical | Internal-only | ATS enforcement + collision audits framing. |
| `cxn-grid-oracle/README.md` | Supporting | Public-safe | Grid oracle overview (agnostic). |

## 3) OpenSpec (ground truth specs)

OpenSpec is the best place to point issue descriptions when work is “spec-first.”

### Canonical OpenSpec specs

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `openspec/specs/git-management/spec.md` | Canonical | Public-safe | Git hygiene, branching, and repo discipline expectations. |
| `openspec/specs/workspace-audit/spec.md` | Canonical | Public-safe | Workspace audit / cleanliness requirements. |
| `openspec/specs/sab-datastore-mapping/spec.md` | Canonical | Public-safe | SAB datastore mapping requirements (persistence + mapping rules). |

### OpenSpec change sets (proposal/design/spec/tasks bundles)

| Change set | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `openspec/changes/remediate-enterprise-sovereignty/*` | Canonical | Public-safe | Baseline enterprise sovereignty requirements. |
| `openspec/changes/sovereign-data-migration-institutional-egress/*` | Canonical | Public-safe | Clean-break data migration + institutional egress requirements. |
| `openspec/changes/csf-autonomous-launch/*` | Supporting | Public-safe | Launch mechanics and autonomous launch framing. |

### Audit docs that complement OpenSpec

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `audit/strategos-alignment.md` | Supporting | Internal-only | Audit of repo alignment to Strategos mandate + next steps. |
| `audit/nomenclature-alignment.md` | Supporting | Public-safe | Corporate vs product nomenclature separation rules. |

## 4) Architecture, PRDs, whitepapers, roadmaps

These are the documents most likely to answer “what are we building?” and “how is it structured?”

### Platform / protocol

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `Conxian/PRD.md` | Canonical | Public-safe | Conxian protocol PRD (modules, status, and benchmarks). |
| `Conxian/docs/ARCHITECTURE.md` | Canonical | Public-safe | Protocol architecture description. |
| `Conxian/docs/WHITEPAPER.md` | Canonical | Public-safe | Protocol whitepaper narrative and model. |
| `Conxian/docs/ROADMAP.md` | Canonical | Public-safe | Protocol roadmap and phases. |
| `Conxian/GOVERNANCE_RECOVERY_REPORT.md` | Supporting | Public-safe | Governance + recovery status report (March 2026). |
| `Conxian/docs/DOCUMENTATION_STATE.md` | Supporting | Public-safe | Snapshot of protocol doc state. |

### Gateway / Nexus / SDK

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `conxian-gateway/PRD.md` | Canonical | Public-safe | Gateway PRD (institutional compliance pipe). |
| `conxian-nexus/docs/PRD.md` | Canonical | Public-safe | Nexus PRD (Glass Node). |
| `lib-conxian-core/docs/PRD.md` | Canonical | Public-safe | Core library PRD (shared models + gateway alignment). |
| `conxius-platform/services/lib-conxian-core/docs/PRD.md` | Supporting | Public-safe | Service-local copy; treat `lib-conxian-core/docs/PRD.md` as canonical. |
| `conxius-wallet/lib-conxian-core/docs/PRD.md` | Supporting | Public-safe | Wallet-local copy; treat `lib-conxian-core/docs/PRD.md` as canonical. |

### Conxius wallet (B2C)

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `conxius-wallet/docs/business/PRD.md` | Canonical | Public-safe | Wallet PRD. |
| `conxius-wallet/docs/operations/ROADMAP.md` | Canonical | Public-safe | Wallet strategic roadmap (v1.6.0). |
| `conxius-wallet/docs/protocols/IMPLEMENTATION_REGISTRY.md` | Canonical | Public-safe | Protocol implementation registry (what’s integrated). |
| `conxius-wallet/docs/legal/RISK_REGISTRY.md` | Canonical | Public-safe | Risk registry (wallet). |
| `conxius-wallet/docs/archive/*` | Supporting | Internal-only | Historical context; useful for archaeology but shouldn’t drive new decisions. |

## 5) Industrial engine (CJCS / ATS / ERP)

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `docs/CJCS_v2.0_SPEC.md` | Canonical | Public-safe | Job Card schema (CJCS v2.0). |
| `docs/ERP_MCP_HANDSHAKE_SPEC.md` | Canonical | Public-safe | ERP handshake spec (SAP/Oracle mapping). |
| `docs/AGENTS.md` | Canonical | Public-safe | Agent operating rules (including knowledge retention rules). |
| `docs/ATS_v11.0_MASTER_BASELINE.md` | Supporting | Internal-only | Baseline snapshot and executive alignment language. |
| `docs/TEE_SECURITY_AUDIT.md` | Supporting | Public-safe | TEE security audit notes. |
| `docs/DASHBOARD_SPEC.md` | Supporting | Public-safe | Audit dashboard spec. |
| `docs/SOVEREIGN_SHARD_SPEC.md` | Canonical | Public-safe | Sharding spec (Sovereign Shard). |
| `docs/BUSINESS_COMPLIANCE_ALIGNMENT_2026.md` | Supporting | Internal-only | Strategy/compliance narrative for 2026 regulatory framing. |

## 6) Governance / repo operating model / runbooks

See `docs/BOS_BUSINESS_BUILDOUT.md` for repo business purpose, business-unit placement, governance + ownership model, and public/internal split.

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `CONTRIBUTING.md` | Canonical | Public-safe | Contribution expectations and workflow. |
| `SECURITY.md` | Canonical | Public-safe | Security policy and reporting. |
| `.github/PULL_REQUEST_TEMPLATE.md` | Supporting | Public-safe | PR checklist and norms. |
| `docs/bounties/MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md` | Canonical | Internal-only | How maintainer payouts are enabled and validated. |
| `admin/SECRETS.md` | Canonical | Internal-only | Secret registry + pointers to Linear docs (ZSE-compliant). |

## 7) Known doc gaps / broken references (should not be re-created blindly)

These are referenced by current docs but are not present in the active Git index. Before recreating them from scratch, first check whether they were intentionally migrated to the Linear Virtual Office under ZSE.

- `docs/STRATEGOS_MANDATE.md` (referenced by `audit/strategos-alignment.md`, `Fiscal-Vault-Oracle/SOVEREIGN_RUNWAY.md`).
- `system_ip_audit.md` (referenced by `Sovereign-Strategy-Nexus/REALTIME_M&A_VELOCITY.md`).
- `RENDER_BOS_PAYLOAD.md` (referenced by `audit/nomenclature-alignment.md`).
- `Sovereign-Strategy-Nexus/SARB_MANDATE.md` (referenced by `audit/strategos-alignment.md`).

## 8) Issue-linking recommendations (current CON issues)

If an issue is in a planning or execution state, the description should link to the doc(s) below so the “why/spec” stays stable even as implementation details change.

| Issue | Add links to | Why |
| --- | --- | --- |
| https://linear.app/conxian-labs/issue/CON-343 | `openspec/changes/sovereign-data-migration-institutional-egress/specs.md`, `openspec/changes/sovereign-data-migration-institutional-egress/specs/sovereign-data-migration-institutional-egress/spec.md`, `ARCHIVE_MIGRATION.md` | This issue is spec-first and directly tied to ZSE + migration. |
| https://linear.app/conxian-labs/issue/CON-158 | `docs/DOCUMENTATION_ALIGNMENT_INDEX.md`, `SUMMARY.md`, `openspec/changes/remediate-enterprise-sovereignty/specs.md` | This is the “alignment” umbrella; it should anchor to the index + baseline OpenSpec. |
| https://linear.app/conxian-labs/issue/CON-152 | `conxian-business/SERVICE_LOOP.md`, `Sovereign-Ops-Orchestrator/LINEAR_WIRING.md`, `conxian-business/BOS_STATE_MACHINE.json` | BOS operating model work should reference the service loop + wiring + state machine. |
| https://linear.app/conxian-labs/issue/CON-157 | `Conxian/PRD.md`, `conxian-gateway/PRD.md`, `conxian-nexus/docs/PRD.md` | “Business-unit model” extraction should start from PRDs (what exists and how it’s separated). |
| https://linear.app/conxian-labs/issue/CON-160 | `conxian-gateway/PRD.md`, `lib-conxian-core/docs/PRD.md`, `openspec/changes/remediate-enterprise-sovereignty/specs/enterprise-sovereignty/spec.md` | Settlement ingress touches gateway/core-lib conventions + sovereignty requirements. |
| https://linear.app/conxian-labs/issue/CON-131 | `docs/bounties/MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md`, `CONTRIBUTING.md` | Bounty workflow should reference the payout runbook + repo workflow norms. |
| https://linear.app/conxian-labs/issue/CON-325 | `admin/SECRETS.md`, `ARCHIVE_MIGRATION.md`, `docs/AGENTS.md` (ZSE section) | Secrets removal work should anchor to the ZSE “where is it now?” docs. |
| https://linear.app/conxian-labs/issue/CON-326 | `openspec/specs/git-management/spec.md`, `CONTRIBUTING.md` | Repo discipline/categorization should cite the OpenSpec git rules + contributing norms. |
| https://linear.app/conxian-labs/issue/CON-327 | `openspec/specs/git-management/spec.md`, `SECURITY.md`, `.github/*` templates | Governance standardization needs the existing governance/security baselines. |

## 9) Proposed Linear documents to create (durable workspace access)

These are the highest-value sources to copy into Linear so day-to-day work stays stable even if the repo has to remove or relocate sensitive material.

1. **BOS Operating Model (canonical)**
   - Source: `conxian-business/SERVICE_LOOP.md`, `conxian-business/BOS_STATE_MACHINE.json`.
2. **Execution wiring: Linear ↔ BOS state layer (canonical)**
   - Source: `Sovereign-Ops-Orchestrator/LINEAR_WIRING.md`.
3. **Zero Secret Egress (ZSE) + knowledge retention (canonical)**
   - Source: `ARCHIVE_MIGRATION.md`, `docs/AGENTS.md` (Knowledge retention & hygiene section), `admin/SECRETS.md`.
4. **OpenSpec: Enterprise Sovereignty baseline (canonical)**
   - Source: `openspec/changes/remediate-enterprise-sovereignty/specs/enterprise-sovereignty/spec.md`.
5. **OpenSpec: Sovereign Data Migration & Institutional Egress (canonical)**
   - Source: `openspec/changes/sovereign-data-migration-institutional-egress/specs/sovereign-data-migration-institutional-egress/spec.md`.
6. **SAB datastore mapping rules (canonical)**
   - Source: `openspec/specs/sab-datastore-mapping/spec.md`.
7. **Conxian protocol PRD + roadmap (canonical)**
   - Source: `Conxian/PRD.md`, `Conxian/docs/ROADMAP.md`.
8. **Gateway / Nexus / Core-lib PRDs (canonical)**
   - Source: `conxian-gateway/PRD.md`, `conxian-nexus/docs/PRD.md`, `lib-conxian-core/docs/PRD.md`.
9. **CJCS v2.0 + ERP handshake (canonical)**
   - Source: `docs/CJCS_v2.0_SPEC.md`, `docs/ERP_MCP_HANDSHAKE_SPEC.md`.
10. **Maintainer payout enablement runbook (internal-only, but operationally critical)**
   - Source: `docs/bounties/MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md`.
