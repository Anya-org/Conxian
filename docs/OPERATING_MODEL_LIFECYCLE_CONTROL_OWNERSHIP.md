# Operating model: lifecycle, control ownership, and repository boundaries

**Status:** Canonical  
**Authority:** Approved in CON-685  
**Scope:** `lib-conxian-core`, `conxian-gateway`, `conxius-wallet`, `conxius-platform`  
**Maintainer:** `conxian-business` governance maintainers (`CODEOWNERS`)

## 1) Purpose and scope

This document is the canonical operating model for lifecycle execution, control ownership, and cross-repo handoff boundaries across the Conxian/Conxius delivery chain.

It standardizes:

- the SDK-first lifecycle phases (`Discover` -> `Design` -> `Build` -> `Verify` -> `Release` -> `Operate` -> `Improve`),
- ownership boundaries for the four core repositories in scope,
- control-domain accountability and required evidence,
- RACI expectations for lifecycle and control execution.

This standard applies to all change streams that touch cross-repo interfaces, runtime behavior, release promotion, or production operations.

Sensitive operational details remain in Linear under Zero Secret Egress (ZSE) policy.

## 2) Source alignment

This model aligns to the following standards and records.

### In-repo (canonical references)

- [`docs/REPO_READINESS_GATES_BY_CONTROL_DOMAIN.md`](./REPO_READINESS_GATES_BY_CONTROL_DOMAIN.md)
- [`docs/PORTFOLIO_BUSINESS_UNIT_MAP.md`](./PORTFOLIO_BUSINESS_UNIT_MAP.md)
- [`docs/architecture/REPO_BOUNDARY_DECISION_RECORD.md`](./architecture/REPO_BOUNDARY_DECISION_RECORD.md)
- [`docs/CROSS_UNIT_CHANGE_CONTROL.md`](./CROSS_UNIT_CHANGE_CONTROL.md)
- [`docs/BRANCH_AND_PROMOTION_STANDARD.md`](./BRANCH_AND_PROMOTION_STANDARD.md)

### Cross-repo references (authoritative in owning repo)

- **[Cross-repo]** `conxius-platform/REPO_OWNERSHIP.md`
- **[Cross-repo]** `conxius-platform/docs/REPO_BOUNDARY_CONTRACT_V1.md`
- **[Cross-repo]** `conxius-platform/docs/PRODUCTION_BOUNDARY.md`

## 3) Ownership boundary definitions

| Component | Owns | Does not own | Mandatory handoff triggers |
| --- | --- | --- | --- |
| `lib-conxian-core` | Shared capability interfaces, canonical models, verification primitives, signer policy abstractions | Adapter implementations, runtime orchestration, wallet UX | If change introduces provider/network integration logic -> hand off to `conxian-gateway`; if client flow/UI impact -> hand off to `conxius-wallet`; if environment/runtime wiring -> hand off to `conxius-platform`. |
| `conxian-gateway` | Integration adapters, partner-facing service boundaries, policy/compliance routing, observation/broadcast boundaries | Canonical shared-core ownership, wallet UX, local runtime orchestration ownership | If change becomes cross-repo type/model primitive -> hand off to `lib-conxian-core`; if change is signer/client UX -> hand off to `conxius-wallet`; if change is stack orchestration/run-environment behavior -> hand off to `conxius-platform`. |
| `conxius-wallet` | Client custody UX, signer UX validation, reference client workflows, client-side privacy controls | Canonical adapter ownership, shared-core source-of-truth ownership, platform orchestration | If change introduces shared interface/model semantics -> hand off to `lib-conxian-core`; if change introduces service integration or partner routing -> hand off to `conxian-gateway`; if change requires shared runtime harness updates -> hand off to `conxius-platform`. |
| `conxius-platform` | Composition runtime, integration/test harnesses, observability wiring, rollout rehearsal environments | Product/business logic ownership, canonical adapters, wallet product UX ownership | If change introduces shared domain model changes -> hand off to `lib-conxian-core`; if service/API ownership changes -> hand off to `conxian-gateway`; if signer/client flow behavior changes -> hand off to `conxius-wallet`. |

## 4) SDK-first lifecycle model

`A` = Accountable (single sign-off owner)  
`R` = Responsible (execution owner(s))

| Phase | Primary outcome | A | R | Required exit gates |
| --- | --- | --- | --- | --- |
| Discover | Problem and boundary impact are explicit and scoped | `conxian-gateway` | `conxian-gateway`, `conxius-wallet` | `DISC-1`: boundary impact captured against business-unit map.<br>`DISC-2`: initial control-domain classification recorded. |
| Design | Interface, ownership, and control intent are fixed before implementation | `lib-conxian-core` | `lib-conxian-core`, `conxian-gateway`, `conxius-wallet` (as applicable) | `DES-1`: interface/spec delta captured in canonical docs/specs.<br>`DES-2`: ownership boundary decision validated. |
| Build | Changes are implemented in the correct owning repository/repositories | Owning repository for changed boundary | Owning repository + dependent repository owners | `BLD-1`: implementation matches ownership boundary rules.<br>`BLD-2`: branch/promotion rules and component checks pass. |
| Verify | Cross-repo correctness, compatibility, and deployment safety are proven | `conxius-platform` | `conxius-platform` + impacted repository owners | `VER-1`: compatibility gate evidence attached (interfaces/boundaries).<br>`VER-2`: deployment verification evidence attached for runtime lane. |
| Release | Promotion is approved with traceable evidence and release signals | Owning repository for released change | Owning repository + `conxius-platform` | `REL-1`: promotion checklist completed for lane transition.<br>`REL-2`: changelog/release evidence linked to candidate commit. |
| Operate | Production behavior is governed by explicit owners, runbooks, and rollback paths | `conxius-platform` | `conxius-platform`, `conxian-gateway`, `conxius-wallet` | `OPS-1`: runbook ownership and escalation path confirmed.<br>`OPS-2`: rollback triggers and deterministic actions validated. |
| Improve | Measured outcomes drive prioritized boundary/control improvements | `lib-conxian-core` | All four repository owners | `IMP-1`: post-release review and corrective backlog captured.<br>`IMP-2`: control/boundary docs updated where policy changed. |

## 5) Control-domain ownership model

| Control domain | A | R | Baseline standard | Minimum evidence |
| --- | --- | --- | --- | --- |
| Security | `lib-conxian-core` | `conxian-gateway`, `conxius-wallet`, `conxius-platform` | Fail-closed boundary behavior, no secret material in git, security-critical changes traceable to named owners | Control gate classification (`L/RC/FT/OC/DC`) + security verification evidence tied to change commit. |
| Service management | `conxian-gateway` | `conxian-gateway`, `conxius-platform` | Named service owner, explicit promotion flow, incident/escalation readiness | Promotion checklist evidence + operating runbook owner assignment and gate approval logs. |
| Resilience | `conxius-platform` | `conxius-platform`, `conxian-gateway`, `conxius-wallet` | Deterministic rollback, staged progression, objective SLO/error budget checks | Rollout-gate evidence + rollback drill evidence + reconciliation outcome artifacts. |
| Quality | `lib-conxian-core` | All four repository owners | Compatibility-first quality gates, deterministic verification outputs, release-candidate traceability | Cross-repo compatibility gate evidence + build/test verification outputs mapped to exact commit SHA. |
| Privacy | `conxius-wallet` | `conxius-wallet`, `conxian-gateway` | Non-custodial posture, least-data handling, explicit custody/signer boundary controls | Wallet/custody control evidence + control-domain gate mapping for privacy-sensitive paths. |
| Partner governance | `conxian-gateway` | `conxian-gateway`, `conxius-platform`, `lib-conxian-core` | External interface changes follow cross-unit change control and boundary contracts | Cross-unit change-control record + boundary contract references + release communication evidence. |

## 6) Evidence artifact map

### 6.1 Lifecycle gate -> required artifacts

| Gate | Required artifacts/checklists/specs/tests | Primary source |
| --- | --- | --- |
| `DISC-1` | Boundary-impact statement and affected unit/repo mapping | [`docs/PORTFOLIO_BUSINESS_UNIT_MAP.md`](./PORTFOLIO_BUSINESS_UNIT_MAP.md) |
| `DISC-2` | Initial control-domain gate classification and release-blocking implications | [`docs/REPO_READINESS_GATES_BY_CONTROL_DOMAIN.md`](./REPO_READINESS_GATES_BY_CONTROL_DOMAIN.md) |
| `DES-1` | Interface/spec delta record (OpenSpec or architecture note) | `openspec/specs/*`, [`docs/architecture/REPO_BOUNDARY_DECISION_RECORD.md`](./architecture/REPO_BOUNDARY_DECISION_RECORD.md) |
| `DES-2` | Ownership/handoff validation against canonical boundary rules | [`docs/architecture/REPO_BOUNDARY_DECISION_RECORD.md`](./architecture/REPO_BOUNDARY_DECISION_RECORD.md), [`docs/CROSS_UNIT_CHANGE_CONTROL.md`](./CROSS_UNIT_CHANGE_CONTROL.md) |
| `BLD-1` | Implementation placement check against ownership boundary | [`docs/architecture/REPO_BOUNDARY_DECISION_RECORD.md`](./architecture/REPO_BOUNDARY_DECISION_RECORD.md) |
| `BLD-2` | Branch lane correctness and build/test checklist completion | [`docs/BRANCH_AND_PROMOTION_STANDARD.md`](./BRANCH_AND_PROMOTION_STANDARD.md), [`docs/PROMOTION_CHECKLISTS.md`](./PROMOTION_CHECKLISTS.md) |
| `VER-1` | Compatibility and acceptance-gate evidence (`G0`/`G1`/`G2`) | [`docs/COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md`](./COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md) |
| `VER-2` | Runtime-lane deployment verification outputs (build/test/security/rollback) | [`docs/DEPLOYMENT_VERIFICATION_MATRIX.md`](./DEPLOYMENT_VERIFICATION_MATRIX.md) |
| `REL-1` | Promotion checklist evidence for `dev` -> `staged` -> `main` (or approved hotfix path) | [`docs/PROMOTION_CHECKLISTS.md`](./PROMOTION_CHECKLISTS.md), [`docs/BRANCH_AND_PROMOTION_STANDARD.md`](./BRANCH_AND_PROMOTION_STANDARD.md) |
| `REL-2` | Changelog/release notes and mainnet acceptance evidence linkage | [`docs/RELEASE_NOTES_AND_CHANGELOG.md`](./RELEASE_NOTES_AND_CHANGELOG.md), `openspec/specs/mainnet-acceptance-evidence-pack/spec.md` |
| `OPS-1` | Runbook owner map, gate approvals, and escalation path | [`docs/operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md`](./operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md) |
| `OPS-2` | Rollback drill and deterministic fallback evidence | [`docs/operations/CON-681_PHASE6_ROLLBACK_DRILL_SIMULATION.md`](./operations/CON-681_PHASE6_ROLLBACK_DRILL_SIMULATION.md), [`docs/COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md`](./COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md) |
| `IMP-1` | Post-release review summary and corrective issue links | [`docs/PORTFOLIO_DASHBOARD.md`](./PORTFOLIO_DASHBOARD.md), issue tracker records |
| `IMP-2` | Boundary/control documentation updates merged and traceable | This document + referenced canonical docs in Section 2 |

### 6.2 Control domain -> baseline evidence map

| Control domain | Baseline evidence artifacts | Notes |
| --- | --- | --- |
| Security | [`docs/REPO_READINESS_GATES_BY_CONTROL_DOMAIN.md`](./REPO_READINESS_GATES_BY_CONTROL_DOMAIN.md), [`docs/DEPLOYMENT_VERIFICATION_MATRIX.md`](./DEPLOYMENT_VERIFICATION_MATRIX.md), [`docs/TEE_SECURITY_AUDIT.md`](./TEE_SECURITY_AUDIT.md) | Gate levels and security checks are release-blocking for in-scope repos. |
| Service management | [`docs/BRANCH_AND_PROMOTION_STANDARD.md`](./BRANCH_AND_PROMOTION_STANDARD.md), [`docs/PROMOTION_CHECKLISTS.md`](./PROMOTION_CHECKLISTS.md), [`docs/operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md`](./operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md) | Must include named owner and lane-appropriate evidence before promotion. |
| Resilience | [`docs/operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md`](./operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md), [`docs/operations/CON-681_PHASE6_ROLLBACK_DRILL_SIMULATION.md`](./operations/CON-681_PHASE6_ROLLBACK_DRILL_SIMULATION.md), [`docs/COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md`](./COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md) | Requires objective rollback and fallback proof. |
| Quality | [`docs/COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md`](./COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md), [`docs/DEPLOYMENT_VERIFICATION_MATRIX.md`](./DEPLOYMENT_VERIFICATION_MATRIX.md), CI/build logs mapped to commit SHA | Evidence must be objective and reproducible. |
| Privacy | [`docs/REPO_READINESS_GATES_BY_CONTROL_DOMAIN.md`](./REPO_READINESS_GATES_BY_CONTROL_DOMAIN.md), [`docs/BOS_WALLET_CONTROL_MODEL.md`](./BOS_WALLET_CONTROL_MODEL.md), [`docs/DOCUMENTATION_CLASSIFICATION.md`](./DOCUMENTATION_CLASSIFICATION.md) | Must preserve non-custodial and ZSE policy boundaries. |
| Partner governance | [`docs/CROSS_UNIT_CHANGE_CONTROL.md`](./CROSS_UNIT_CHANGE_CONTROL.md), [`docs/PORTFOLIO_BUSINESS_UNIT_MAP.md`](./PORTFOLIO_BUSINESS_UNIT_MAP.md), [`docs/architecture/REPO_BOUNDARY_DECISION_RECORD.md`](./architecture/REPO_BOUNDARY_DECISION_RECORD.md), **[Cross-repo]** `conxius-platform/docs/REPO_BOUNDARY_CONTRACT_V1.md`, **[Cross-repo]** `conxius-platform/docs/PRODUCTION_BOUNDARY.md` | Cross-repo boundary contracts are consumed as external authority. |

## 7) Implementation rollout

1. **Adopt this document as canonical policy reference** in lifecycle, release, and governance reviews.
2. **Create one follow-up work item per in-scope repo** using the backlog below.
3. **Link follow-up outcomes back to this document** by adding evidence links in the lifecycle/control tables where needed.
4. **Review quarterly** (or earlier on major boundary changes) and update this document in the same PR as boundary/control changes.

### Required per-repo follow-up work items

| Repo | Follow-up work item to create | Done when |
| --- | --- | --- |
| `lib-conxian-core` | Publish/refresh repo ownership statement and add a compatibility evidence checklist for downstream consumers. | Ownership statement and quality/security evidence links are committed and referenced in release PR templates/checklists. |
| `conxian-gateway` | Add explicit service-management and partner-governance evidence checklist to release workflow. | Promotion PRs require service owner approval, cross-unit change-control reference, and partner-impact evidence links. |
| `conxius-wallet` | Implement and maintain wallet lifecycle control checklist: [`docs/WALLET_LIFECYCLE_CONTROL_CHECKLIST.md`](./WALLET_LIFECYCLE_CONTROL_CHECKLIST.md), mapped to lifecycle `Verify`, `Release`, and `Operate` gates. | Wallet release candidates include completed `VER-*`/`REL-*`/`OPS-*` evidence in the checklist, including custody boundary checks, privacy controls, and rollback owner assignment. |
| `conxius-platform` | Align platform ownership + production-boundary docs with this lifecycle/control model and expose a reusable verify/operate evidence pack template. | **[Cross-repo]** `REPO_OWNERSHIP.md`, `docs/REPO_BOUNDARY_CONTRACT_V1.md`, and `docs/PRODUCTION_BOUNDARY.md` are updated and linked from release/rollout evidence. |

## Appendix A: RACI by lifecycle phase

| Phase | `lib-conxian-core` | `conxian-gateway` | `conxius-wallet` | `conxius-platform` | Governance (`conxian-business`) |
| --- | --- | --- | --- | --- | --- |
| Discover | C | A/R | R | C | I |
| Design | A/R | C | C | C | I |
| Build* | R* | R* | R* | C | I |
| Verify | C | R | R | A/R | C |
| Release* | C | R* | R* | A/R | C |
| Operate | I | R | R | A/R | C |
| Improve | A/R | C | C | C | C |

`*` Build and Release accountability is held by the owning repository for the changed boundary. Only one repository owner is `A` per work item.

## Appendix B: RACI by control domain

| Control domain | `lib-conxian-core` | `conxian-gateway` | `conxius-wallet` | `conxius-platform` | Governance (`conxian-business`) |
| --- | --- | --- | --- | --- | --- |
| Security | A/R | R | R | C | C |
| Service management | C | A/R | C | R | C |
| Resilience | C | R | C | A/R | C |
| Quality | A/R | R | R | R | C |
| Privacy | C | R | A/R | C | C |
| Partner governance | C | A/R | C | R | C |
