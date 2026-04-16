# Documentation alignment index (conxian-business)

This page is a practical index of the documentation already present in this repository, focused on helping active work reference existing material instead of recreating it.

## Classification rules

- **Canonical**: the current “source of truth” for a domain. If two docs disagree, update the non-canonical doc to match the canonical one.
- **Supporting**: helpful context, audits, reports, briefs, or deep dives that clarify (but don’t define) the system.
- **Public-safe**: ok to link in public contexts and external conversations.
- **Public-safe stub (canonical in Linear)**: safe to link publicly; this repo file is a short pointer stub (see [ZSE stub template](./templates/ZSE_STUB_TEMPLATE.md)). It must not contain any operational, security, financial, legal, and strategic details beyond the pointer. The full canonical content is maintained in Linear under ZSE.
- **Internal-only (canonical in Linear only)**: operational, security, financial, legal, and strategic material whose canonical document must live only in the Conxian Linear workspace. If a repo link target must be preserved, use a **Public-safe stub (canonical in Linear)** (see [ZSE stub template](./templates/ZSE_STUB_TEMPLATE.md)) so existing links continue to resolve.

Notes:

- Treat this repo as public for boundary purposes. (This GitHub repository is private as of April 8, 2026.) “Internal-only” material should not be stored here; when we preserve link targets we use public-safe ZSE stubs (see https://linear.app/conxian-labs/issue/CON-256).
- OpenSpec change sets typically have 4 layers: `proposal.md` (intent), `design.md` (architecture), `specs/*/spec.md` (requirements), `tasks.md` (execution).

## 1) Repo navigation (start here)

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `README.md` | Canonical | Public-safe | Repository entrypoint and overall orientation. |
| `SUMMARY.md` | Canonical | Public-safe | GitBook table of contents (used for docs navigation; Pages publishing is allowlisted). |
| `docs/README.md` | Supporting | Public-safe | “Docs hub” landing page. |
| `docs/BOS_BUSINESS_BUILDOUT.md` | Canonical | Public-safe | Repo business purpose, business-unit placement, governance + ownership model, and public/internal split. |
| `docs/PRIVATE_REPO_REPO_CHECK_WORKFLOW.md` | Canonical | Public-safe | Repo-check workflow for private repositories (boundary, secrets, hygiene, governance, release maturity). |
| `docs/BRANCH_AND_PROMOTION_STANDARD.md` | Canonical | Public-safe | Canonical `dev`/`staged`/`main` branch roles and promotion workflow. |
| `ARCHIVE_MIGRATION.md` | Canonical | Public-safe | ZSE placeholder + pointer to Linear Virtual Office for legacy material. |

## 2) BOS (Business Operations System)

These are the “operating-model” documents that explain how BOS components relate, how execution is intended to be wired into Linear, and what gets measured.

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `conxian-business/SERVICE_LOOP.md` | Canonical | Public-safe | BOS service loop (how client/supplier loops connect). |
| `conxian-business/BOS_STATE_MACHINE.stub.json` | Supporting | Public-safe stub (canonical in Linear) | Public-safe BOS state machine pointer stub (standardized ZSE stub). |
| `Sovereign-Ops-Orchestrator/LINEAR_WIRING.md` | Canonical | Public-safe stub (canonical in Linear) | Intended Linear ↔ state-layer wiring and webhook triggers (standardized ZSE stub). |
| `Sovereign-Ops-Orchestrator/DEPLOYMENT_EFFICIENCY.md` | Supporting | Public-safe stub (canonical in Linear) | Bottleneck and deployment efficiency metrics (standardized ZSE stub). |
| `Sovereign-Strategy-Nexus/REALTIME_M&A_VELOCITY.md` | Supporting | Public-safe stub (canonical in Linear) | Strategy velocity tracking and exit-readiness framing (standardized ZSE stub). |
| `Sovereign-Strategy-Nexus/docs/SOVEREIGN_MOI_ALIGNMENT.md` | Canonical | Public-safe stub (canonical in Linear) | “MOI” alignment source for Strategy Nexus narratives (standardized ZSE stub). |
| `Sovereign-Strategy-Nexus/docs/ZK_DATA_ROOM_SCHEMA.md` | Canonical | Public-safe stub (canonical in Linear) | ZK data room schema (standardized ZSE stub). |
| `Sovereign-Strategy-Nexus/docs/SOVEREIGN_PITCH_DECK_NARRATIVE.md` | Supporting | Public-safe stub (canonical in Linear) | Pitch narrative scaffolding (standardized ZSE stub). |
| `Fiscal-Vault-Oracle/SOVEREIGN_RUNWAY.md` | Canonical | Public-safe stub (canonical in Linear) | Treasury runway and yield execution constraints (standardized ZSE stub). |
| `Fiscal-Vault-Oracle/LSEG_MCP_AUDIT.md` | Supporting | Public-safe stub (canonical in Linear) | LSEG MCP audit context for treasury/oracle integrity (standardized ZSE stub). |
| `docs/architecture/BOS_TREASURY_AND_YIELD_INTEGRATION_ARCHITECTURE.md` | Canonical | Public-safe | Treasury/yield integration boundary: intent-based ops, oracle publishing, reconciliation, and failure handling (no dashboard-to-contract coupling). |
| `docs/protocols/BOS_SELF_EXECUTING_CONTRACT_TRIGGER_V1.md` | Canonical | Public-safe | Verified CLM webhook → queued pending on-chain action with 144-block timelock → multisig finalization, with replay protection, cancellation semantics, monitoring, and audit traceability. |
| `docs/architecture/THREE_LANE_RUNTIME_DEPLOYMENT_ARCHITECTURE.md` | Canonical | Public-safe | Canonical runtime deployment model across community sovereign-node, business-managed, and enterprise/private-cloud lanes (controls, upgrade paths, and trust assumptions). |
| `docs/architecture/BOS_PRESERVE_ENHANCE_REPLACE_GAP_MATRIX.md` | Canonical | Public-safe | Control matrix for preserve/enhance/replace/defer decisions across BOS components (prevents destructive refactors; locks sequencing). |
| `Nakamoto-Guardian/ANTI_FRAGILITY_LOOP.md` | Canonical | Public-safe stub (canonical in Linear) | ATS enforcement + collision audits framing (standardized ZSE stub). |
| `cxn-grid-oracle/README.md` | Supporting | Public-safe | Grid oracle overview (agnostic). |

## 3) OpenSpec (ground truth specs)

OpenSpec is the best place to point issue descriptions when work is “spec-first.”

### Canonical OpenSpec specs

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `openspec/specs/git-management/spec.md` | Canonical | Public-safe | Git hygiene, branching, and repo discipline expectations. |
| `openspec/specs/mainnet-acceptance-evidence-pack/spec.md` | Canonical | Public-safe | Canonical evidence pack required for promoting `staged` into `main`. |
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

### Independent Lab Development Kit (ILDK)

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `docs/ILDK_README.md` | Canonical | Public-safe | Technical framework for external labs to build specialized Industrial Management modules. |
| `docs/STRATEGIC_GROWTH_MODEL_2026.md` | Canonical | Public-safe | Strategic comparison of growth models and governance-minimized scaling. |

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
| `docs/LIB_CONCLAVE_SDK_BOS_BUILDOUT.md` | Supporting | Public-safe | BOS-level business role, governance controls, and internal-only vs public-safe separation guidance for the SDK. |
| `docs/CONXIUS_PLATFORM_BOS_BUILDOUT.md` | Supporting | Public-safe | BOS-level business role, governance controls, and documentation separation guidance for conxius-platform. |
| `docs/CONXIAN_PROTOCOL_BOS_BUILDOUT.md` | Supporting | Public-safe | BOS-level business role, governance controls, and documentation separation guidance for Conxian protocol. |
| `docs/CONXIAN_GATEWAY_BOS_BUILDOUT.md` | Supporting | Public-safe | BOS-level business role, governance controls, and documentation separation guidance for conxian-gateway. |
| `docs/CONXIAN_NEXUS_BOS_BUILDOUT.md` | Supporting | Public-safe | BOS-level business role, governance controls, and documentation separation guidance for conxian-nexus. |
| `docs/STACKSORBIT_BOS_BUILDOUT.md` | Supporting | Public-safe | BOS-level business role, governance controls, and documentation separation guidance for stacksorbit. |
| `docs/CONXIAN_UI_BOS_BUILDOUT.md` | Supporting | Public-safe | BOS-level business role, governance controls, and documentation separation guidance for Conxian_UI. |
| `docs/GITHUB_GOVERNANCE_BOS_BUILDOUT.md` | Supporting | Public-safe | BOS-level business role, governance controls, and documentation separation guidance for .github. |
| `docs/LIB_CONXIAN_CORE_BOS_BUILDOUT.md` | Supporting | Public-safe | BOS-level business role, governance controls, and documentation separation guidance for lib-conxian-core. |
| `docs/CONXIAN_LABS_SITE_BOS_BUILDOUT.md` | Supporting | Public-safe | BOS-level business role, governance controls, and documentation separation guidance for conxian-labs-site. |
| `docs/MAINNET_READINESS_CONXIAN_PROTOCOL.md` | Supporting | Public-safe | Mainnet readiness checklist for Conxian protocol. |
| `docs/MAINNET_READINESS_CONXIUS_WALLET.md` | Supporting | Public-safe | Mainnet readiness checklist for conxius-wallet. |
| `docs/MAINNET_READINESS_CONXIAN_GATEWAY.md` | Supporting | Public-safe | Mainnet readiness checklist for conxian-gateway. |
| `docs/MAINNET_READINESS_CONXIUS_PLATFORM.md` | Supporting | Public-safe | Mainnet readiness checklist for conxius-platform. |
| `docs/WALLET_SIGNER_CONTROL_VERIFICATION_REPORT.md` | Supporting | Public-safe | Wallet and signer control verification report for mainnet launch. |
| `docs/PUBLIC_VISIBILITY_AUDIT_REPORT.md` | Supporting | Public-safe | Public visibility boundary audit report. |
| `conxius-platform/services/lib-conxian-core/docs/PRD.md` | Supporting | Public-safe | Service-local copy; treat `lib-conxian-core/docs/PRD.md` as canonical. |
| `conxius-wallet/lib-conxian-core/docs/PRD.md` | Supporting | Public-safe | Wallet-local copy; treat `lib-conxian-core/docs/PRD.md` as canonical. |

### Conxius wallet (B2C)

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `docs/CONXIUS_WALLET_BOS_BUILDOUT.md` | Supporting | Public-safe | BOS-level business role, governance controls, and internal-only vs public-safe separation guidance for the wallet. |
| `conxius-wallet/docs/business/PRD.md` | Canonical | Public-safe | Wallet PRD. |
| `conxius-wallet/docs/operations/ROADMAP.md` | Canonical | Public-safe | Wallet strategic roadmap (v1.6.0). |
| `conxius-wallet/docs/protocols/IMPLEMENTATION_REGISTRY.md` | Canonical | Public-safe | Protocol implementation registry (what’s integrated). |
| `conxius-wallet/docs/legal/RISK_REGISTRY.md` | Canonical | Public-safe | Risk registry (wallet). |
| `conxius-wallet/docs/archive/*` | Supporting | Internal-only | Historical context; useful for archaeology but shouldn’t drive new decisions. |

## 5) Industrial engine (CJCS / ATS / ERP)

| Document | Role | Visibility | What it’s for |
| --- | --- | --- | --- |
| `docs/CJCS_v2.0_SPEC.md` | Canonical | Public-safe | Job Card schema (CJCS v2.0.1). |
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
| `docs/CSF_FIRST_OPERATING_SEQUENCE_AND_PROOF_GATES.md` | Canonical | Public-safe | Locks the CSF → economy → gateway operating order and the minimum proof gates that keep launch, economy design, and go-to-market claims aligned. |
| `docs/BOS_WALLET_CONTROL_MODEL.md` | Canonical | Public-safe | Canonical BOS wallet-control model (bootstrap → SAB custody → DAO-aligned governance). |
| `docs/bounties/MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md` | Canonical | Public-safe stub (canonical in Linear) | How maintainer payouts are enabled and validated (standardized ZSE stub). |
| `admin/SECRETS.md` | Canonical | Public-safe stub (canonical in Linear) | Secret registry + pointers to Linear docs (standardized ZSE stub). |

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
| https://linear.app/conxian-labs/issue/CON-152 | `conxian-business/SERVICE_LOOP.md`, `Sovereign-Ops-Orchestrator/LINEAR_WIRING.md`, `conxian-business/BOS_STATE_MACHINE.stub.json` | BOS operating model work should reference the service loop + wiring + state machine. |
| https://linear.app/conxian-labs/issue/CON-157 | `Conxian/PRD.md`, `conxian-gateway/PRD.md`, `conxian-nexus/docs/PRD.md` | “Business-unit model” extraction should start from PRDs (what exists and how it’s separated). |
| https://linear.app/conxian-labs/issue/CON-160 | `conxian-gateway/PRD.md`, `lib-conxian-core/docs/PRD.md`, `openspec/changes/remediate-enterprise-sovereignty/specs/enterprise-sovereignty/spec.md` | Settlement ingress touches gateway/core-lib conventions + sovereignty requirements. |
| https://linear.app/conxian-labs/issue/CON-131 | `docs/bounties/MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md`, `CONTRIBUTING.md` | Bounty workflow should reference the payout runbook + repo workflow norms. |
| https://linear.app/conxian-labs/issue/CON-325 | `admin/SECRETS.md`, `ARCHIVE_MIGRATION.md`, `docs/AGENTS.md` (ZSE section) | Secrets removal work should anchor to the ZSE “where is it now?” docs. |
| https://linear.app/conxian-labs/issue/CON-326 | `openspec/specs/git-management/spec.md`, `CONTRIBUTING.md` | Repo discipline/categorization should cite the OpenSpec git rules + contributing norms. |
| https://linear.app/conxian-labs/issue/CON-327 | `openspec/specs/git-management/spec.md`, `SECURITY.md`, `.github/*` templates | Governance standardization needs the existing governance/security baselines. |

## 9) Proposed Linear documents to create (durable workspace access)

These are the highest-value sources to copy into Linear so day-to-day work stays stable even if the repo has to remove or relocate sensitive material.

1. **BOS Operating Model (canonical)**
   - Source: `conxian-business/SERVICE_LOOP.md`, `conxian-business/BOS_STATE_MACHINE.stub.json` (public-safe pointer; canonical BOS state machine definition is maintained in Linear).
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
9. **CJCS v2.0.1 + ERP handshake (canonical)**
   - Source: `docs/CJCS_v2.0_SPEC.md`, `docs/ERP_MCP_HANDSHAKE_SPEC.md`.
10. **Maintainer payout enablement runbook (internal-only, but operationally critical)**
   - Source: `docs/bounties/MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md`.
