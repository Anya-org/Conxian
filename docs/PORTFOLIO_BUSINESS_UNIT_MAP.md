# Portfolio business-unit map and separation of concerns

> Verification: expected to be enforced by P0 portfolio hygiene automation (see the prioritized build/repair list). Until then, keep the repo’s submodule gitlinks, `.gitmodules`, and the portfolio docs (`docs/PORTFOLIO_BUSINESS_UNIT_MAP.md`, `docs/REPO_PORTFOLIO.md`) consistent on the pinned submodule set and their flagship/supporting classifications in every PR (see “Source-of-truth rule” below).

This document is the portfolio-level map that assigns every repo/subrepo (submodule) and BOS asset to a **business unit** or **operating function**, and defines the separation-of-concerns boundaries needed for business development and business unit management.

Today, this page is the canonical human-readable portfolio map; machine-readable BOS artifacts in `./conxian-business/` should be treated as derived outputs. When this mapping changes, ensure any intentional BOS runtime/audit updates remain consistent with it. Until a machine-readable portfolio manifest exists, artifacts in `./conxian-business/` are non-authoritative derived outputs and may be regenerated/replaced.

Contributors should not edit generated BOS state artifacts under `./conxian-business/` by hand (for example: `BOS_STATE_MACHINE.json`, `AUDIT_MANIFEST.json`); treat them as outputs that may be replaced at any time. Source code in that directory (for example: `transparency_custodian.py`) is maintained normally.

To regenerate BOS state artifacts (including `./conxian-business/AUDIT_MANIFEST.json` and `./conxian-business/BOS_STATE_MACHINE.json`), run:

```bash
python3 conxian-business/transparency_custodian.py
```

Until portfolio hygiene automation exists to regenerate and diff BOS state artifacts under `./conxian-business/` in CI (see the P0 backlog), contributor policy is:

- If your change affects portfolio wiring or BOS state inputs (for example: pinned submodule gitlinks, `.gitmodules`, the asset lists in this document, or the generator source under `./conxian-business/`), re-run the generator command above (do **not** edit any files under `./conxian-business/` by hand) and **commit** any updated derived artifacts (for example: `./conxian-business/AUDIT_MANIFEST.json`, `./conxian-business/BOS_STATE_MACHINE.json`) in the same PR.
- Reviewers should treat changes that affect BOS state but do not update derived artifacts as incomplete and request that the regeneration step be run.

If you are unsure whether a change affects BOS state inputs, err on the side of re-running the generator; it is intended to be cheap and idempotent.

Once a machine-readable portfolio manifest exists (see the P0 backlog), that manifest becomes the single source of truth that generates both this document and BOS runtime artifacts.

Naming note: this repo is `conxian-business`, but it also contains a nested directory `./conxian-business/` for BOS state artifacts. In this document, `./` refers to the repo root, and `./conxian-business/` refers to the nested state directory.

Control note: this map must be updated whenever the set of pinned submodule paths or BOS-native top-level assets (as enumerated in the tables below) change. Portfolio hygiene automation (under `scripts/`) should treat mismatches as a portfolio integrity failure (both missing mappings and stale mappings).

This complements (and should remain consistent with):

- `docs/REPO_PORTFOLIO.md` (flagship vs supporting trust surface)
- `openspec/changes/remediate-enterprise-sovereignty/specs/enterprise-sovereignty/spec.md` (4-unit consolidation requirement)

## Target business-unit structure

OpenSpec anchors the ecosystem into four standalone businesses:

| Business unit | Market surface | Core obligation |
| --- | --- | --- |
| **Conxius** | B2C | Sovereign wallet and key custody (mobile-first) |
| **CSF (Conxian Finance Protocol)** | Protocol | On-chain contracts, assets, and fee logic |
| **Fusion** | B2B/B2G integration | Cross-layer gateway + compliance pipelines |
| **Nexus** | State + telemetry | Authoritative state node/services for the stack |

Alongside the four units, BOS requires separate operating functions that should not be mixed into product repos (examples: governance/specs, treasury, compliance, ops, strategy, UI/public web, platform/DevEx, DevOps tooling, and showcase surfaces).

## Portfolio-level map (repos, subrepos, and BOS assets)

### Ecosystem repos (submodules pinned by this BOS repo)

This table should be kept consistent with the repo’s submodule gitlinks (what is actually pinned), `.gitmodules` (expected submodule config metadata), and `docs/REPO_PORTFOLIO.md` (flagship vs supporting classification).

Maintainer note: until the P0 portfolio manifest exists, changes to the asset list here should be reflected in the “Unique value + scope definition” section below as well.

Source-of-truth rule:

- The repo’s committed git tree (submodule gitlinks) is authoritative for which submodules are pinned (and to what commits).
- `.gitmodules` is authoritative for expected submodule configuration metadata (`path`, `url`, and optional `branch`).
- This document is authoritative for business-unit/operating-function classification.
- `docs/REPO_PORTFOLIO.md` is an explanatory trust-surface view; it may list additional supporting repos for context, but every pinned submodule in the ecosystem mapping table should appear there with a flagship/supporting classification.

Portfolio hygiene automation should validate:

- Every pinned gitlink has a `.gitmodules` entry and a corresponding row in the ecosystem submodule mapping table.
- Every `.gitmodules` entry has a corresponding pinned gitlink and row in the ecosystem submodule mapping table.
- Every row in the ecosystem submodule mapping table corresponds to a pinned gitlink and `.gitmodules` entry (no extra rows).
- Every pinned gitlink with a row in the ecosystem submodule mapping table appears in `docs/REPO_PORTFOLIO.md` with a flagship/supporting classification.
- Every BOS-native asset path enumerated in the BOS-native assets table exists in this repo (one-way check; new BOS-native assets must be added to the table during review).
- If a submodule sets `branch` in `.gitmodules`, that branch exists upstream.

Until portfolio hygiene automation is live, reviewers should treat these invariants as manual review criteria and reject PRs that violate them.

Note: `.gitmodules` `branch` affects `git submodule update --remote` only; it does not change what commit is pinned.

| Asset | Type | Primary BU / function | Primary concern(s) | Notes |
| --- | --- | --- | --- | --- |
| `Conxian/` | Submodule | **CSF** (Protocol) | Protocol + contracts | Canonical on-chain source; should not contain off-chain service logic. |
| `conxius-wallet/` | Submodule | **Conxius** (Wallet) | Wallet + custody | Mobile client; no shared backend logic beyond boundary APIs. |
| `conxian-gateway/` | Submodule | **Fusion** (Gateway) | Gateway + compliance | Integration surface; consumes Nexus state; should not be a UI host. |
| `conxian-nexus/` | Submodule | **Nexus** (State node) | State + telemetry | Must remain the authoritative node/service surface. |
| `conxian-ui/` | Submodule | Operating function (UI) | UI | Web UI for interacting with the ecosystem; should avoid embedding protocol logic beyond calls. |
| `conxian-labs-site/` | Submodule | Operating function (Public web) | Public documentation + marketing | Public site; should not include internal-only strategy material. |
| `conxius-platform/` | Submodule | Operating function (Platform/DevEx) | Local stack orchestration | Dev stack only; should not become a home for core product logic. |
| `stacksorbit/` | Submodule | Operating function (DevOps tooling) | Deployment tooling | Primarily supports CSF protocol deployment. |
| `lib-conclave-sdk/` | Submodule | Operating function (Shared SDK) | Shared libraries | Supports services across Fusion/Nexus; should stay dependency-light. |
| `lib-conxian-core/` | Submodule | Operating function (Shared core) | Shared models + conventions | Shared primitives only; must not contain BU-specific business logic or depend directly on product repos. Layering: sits beneath product repos and shared SDKs; may not depend on them. |

### BOS-native assets (tracked in this repo)

| Asset | Primary BU / function | Primary concern(s) | Notes |
| --- | --- | --- | --- |
| `openspec/` | Governance (OpenSpec) | Ground-truth technical requirements | Public, versioned specs; should not contain sensitive operational strategy. |
| `docs/` | Governance (Public docs) | Public documentation | Public trust surface docs and portfolio conventions. |
| `./conxian-business/` | Operating function (Governance/BOS runtime) | Machine-readable BOS state | Nested directory containing state-machine artifacts (`BOS_STATE_MACHINE.json`, audit manifests). |
| `.github/` | Governance (Repo operations) | CI/CD, templates | Cross-unit repo hygiene enforcement entrypoint. |
| `scripts/` | Governance (Portfolio hygiene) | Audits, link checking | BOS utility scripts; avoid embedding product logic. |
| `audit/` | Governance (Assurance) | Audits and alignment reports | Outputs should be cross-unit and non-sensitive. |
| `infrastructure/terraform/` | Operating function (Infra) | Infrastructure as code | Shared infra definitions; avoid coupling to a single business unit. |
| `admin/` | Operating function (Admin) | Internal runbooks/ops | Must respect Zero Secret Egress; secrets must remain out of git. |
| `showcase-dapp/` | Operating function (Showcase) | Demonstration UI | Public demo surface; should stay clearly separate from flagship product repos. |
| `Fiscal-Vault-Oracle/` | Operating function (Treasury) | Treasury automation | Financial engine module (BOS EXCO suite). |
| `Nakamoto-Guardian/` | Operating function (Compliance) | Enforcement/compliance | Architecture + regulatory enforcement module (BOS EXCO suite). |
| `Sovereign-Ops-Orchestrator/` | Operating function (Ops) | Execution orchestration | Work/ops engine; connects BOS state machine to execution platforms. |
| `Sovereign-Strategy-Nexus/` | Operating function (Strategy) | Strategy and M&A | Strategic intelligence layer; keep internal strategy material in Linear Virtual Office. |
| `cxn-grid-oracle/` | Operating function (Grid oracle) | External oracle integration | Energy/grid orchestration module; separate from protocol and wallet. |

## Separation-of-concerns model (portfolio rules)

The goal is to keep each repo’s business unit legible to partners/auditors and to keep internal operations safe (ZSE) while still enabling end-to-end delivery.

### 1) Business unit boundaries (what must not mix)

1. **CSF / Protocol** (`Conxian/`) must not contain wallet UX, gateway service code, or BOS automation.
2. **Conxius / Wallet** (`conxius-wallet/`) must not contain server-side Fusion/Nexus logic; it consumes boundary APIs.
3. **Fusion / Gateway** (`conxian-gateway/`) must not become the authoritative chain state source; it consumes Nexus.
4. **Nexus / State node** (`conxian-nexus/`) must not become a UI repo; it provides state and telemetry.
5. **BOS / Governance** (this repo: `conxian-business`) must not become a dumping ground for product code; it defines specs, governance, and portfolio wiring.
6. **Operating functions** (strategy/treasury/compliance/ops/admin) must not leak sensitive information into git; internal-only strategy belongs in Linear.

### 2) Allowed dependency directions (high level)

This keeps “truth drift” low and preserves independent unit ownership.

```
OpenSpec + BOS docs  -> constrain all units (no runtime dependency)
Protocol (CSF)       -> exposes on-chain interfaces
Nexus                -> exposes state + telemetry interfaces
Fusion Gateway       -> integrates external systems; consumes Nexus + Protocol
Wallet/UI            -> consumes Gateway/Nexus/Protocol boundary interfaces
```

Nexus is the canonical read surface for state. Gateway and Wallet/UI may interact with Protocol directly for narrowly-scoped verification/settlement flows, but portfolio operations must not treat Protocol reads as an alternative state source.

Operating functions (EXCO modules, infra/admin, and BOS runtime) should depend only on BOS state and published boundary interfaces (Protocol/Nexus/Fusion), not on internal implementation details of product repos.

Published boundary interfaces include:

- On-chain interfaces and traits in `Conxian/`.
- Nexus APIs/schemas in `conxian-nexus/`.
- Gateway integration APIs/event schemas in `conxian-gateway/`.
- Shared SDK surfaces intended for cross-unit use (for example, `lib-conclave-sdk/` and `lib-conxian-core/`).

### 3) Example cross-unit workflows

1. **Protocol feature lifecycle (CSF)**
   - Spec/interface change: update OpenSpec as needed.
   - Implementation: update `Conxian/`.
   - Exposure: update `conxian-nexus/` to expose required state/telemetry.
   - Integration: update `conxian-gateway/` for any cross-system routing/compliance concerns.
   - Consumption: update `conxius-wallet/` and/or `conxian-ui/`.
   - Portfolio wiring: bump pinned submodules in this BOS repo and keep this map consistent.
2. **Treasury policy change (EXCO)**
   - Internal decision context stays in Linear Virtual Office.
   - Update `Fiscal-Vault-Oracle/` policy/specs, with `Nakamoto-Guardian/` enforcing compliance gates.
   - Reflect required telemetry via `conxian-nexus/`; surface any public-facing comms via `conxian-labs-site/`.
3. **Compliance incident / enforcement workflow**
   - Detection in `conxian-nexus/` and/or `conxian-gateway/`.
   - Enforcement in `Nakamoto-Guardian/` with execution/orchestration via `Sovereign-Ops-Orchestrator/`.
   - If the incident changes required controls, update OpenSpec/BOS docs (public) and keep sensitive details in Linear.

## Cross-unit governance + documentation requirements (target state)

These are the minimum cross-unit artifacts needed to operate the portfolio as four businesses plus operating functions. Some may be partially implemented or not yet present.

1. **Business unit charters** (one page each): Conxius, CSF, Fusion, Nexus.
   - Scope, non-scope, primary KPIs, and “what this unit owns.”
   - Target location: `docs/business-units/` in this repo (one file per unit).
2. **Portfolio ownership rules**:
   - Explicit maintainer/approver for each repo, plus escalation rules (CODEOWNERS is necessary but not sufficient).
   - Target location: `docs/OWNERSHIP_AND_APPROVAL.md`.
3. **Boundary interface registry**:
   - Versioned list of APIs/schemas/contracts each unit exports, with compatibility expectations.
   - Target location: `docs/interfaces/`.
4. **Cross-unit change control**:
   - A lightweight rule for when a change requires a BOS/OpenSpec update vs. when it can stay within a single unit repo.
   - Target location: `docs/CROSS_UNIT_CHANGE_CONTROL.md`.
5. **Documentation classification** (ZSE):
   - Public docs in git (`docs/`, `openspec/`), sensitive strategy/ops in Linear Virtual Office.
   - Target location: `docs/DOCUMENTATION_CLASSIFICATION.md`.

## Unique value + scope definition (by repo)

Use this as the “business-end” positioning layer for partners and internal coordination.

This section intentionally repeats the asset list with additional positioning detail; when updating the portfolio map tables above, keep this section consistent. The long-term intent is to drive both sections from a single machine-readable manifest (see the P0 backlog).

### Pinned ecosystem repos (submodules)

| Repo / asset | Unique value | In scope | Out of scope |
| --- | --- | --- | --- |
| `Conxian/` | Canonical protocol and on-chain assets | Contracts, traits, fee logic, registries | Wallet UX, off-chain integration services |
| `conxius-wallet/` | Sovereign custody and signing surface | Key management, offline-first wallet UX | Running the state node, ERP integrations |
| `conxian-gateway/` | Fusion integration and compliance | Webhooks, compliance pipelines, aggregation | Being the authoritative state source |
| `conxian-nexus/` | Authoritative state + telemetry | Block height authority, state services, metrics | UI, treasury automation |
| `conxian-ui/` | Web interaction surface | Web app UX consuming boundary APIs | Defining protocol logic |
| `conxius-platform/` | End-to-end local stack | Dev orchestration, local ops | Shipping product features |
| `stacksorbit/` | Protocol deployment tooling | Contract deployment and ops | Wallet features |
| `conxian-labs-site/` | Public web presence | Marketing, docs surfacing | Internal strategy |
| `lib-conclave-sdk/` | Enclave/crypto SDK | Attested flows, SDK primitives | Protocol decisions |
| `lib-conxian-core/` | Shared conventions | Models, shared primitives | Business logic or product UX |

### EXCO suite modules (directories tracked in this repo)

| Asset | Unique value | In scope | Out of scope |
| --- | --- | --- | --- |
| `Fiscal-Vault-Oracle/` | Treasury automation | Treasury, yield, bond issuance specs | Wallet UX |
| `Nakamoto-Guardian/` | Enforcement and compliance | Compliance gating, anti-fragility loops | Product UX |
| `Sovereign-Ops-Orchestrator/` | Execution orchestration | Work execution + Linear wiring | Protocol code |
| `Sovereign-Strategy-Nexus/` | Strategic intelligence | M&A velocity, IP sovereignty | Public product marketing copy |
| `cxn-grid-oracle/` | External oracle integration | Grid/demand-response routing | Protocol custody |

### BOS-native assets

| Asset | Unique value | In scope | Out of scope |
| --- | --- | --- | --- |
| `./` (repo root) | BOS governance + wiring | Governance, OpenSpec, portfolio wiring | Shipping product features |
| `openspec/` | Ground-truth technical requirements | Specs, standards, baseline requirements | Product delivery work, private strategy |
| `docs/` | Portfolio-level public documentation | Public documentation and conventions | Sensitive strategy/ops |
| `./conxian-business/` (nested state) | Machine-readable BOS state | State machine + audit manifests | Product features |
| `.github/` | Portfolio operational guardrails | CI, templates, security/automation scaffolding | Business logic |
| `scripts/` | Portfolio hygiene automation | Link checks, audits, helper utilities | Product code |
| `audit/` | Cross-unit assurance surface | Audits and alignment reports | Secrets or sensitive financial detail |
| `infrastructure/terraform/` | Shared infrastructure definitions | IaC for shared systems | Coupling infra to a single BU without explicit decision |
| `admin/` | Operator runbooks and operational hygiene | Non-sensitive ops docs, standards | Secrets, private keys, internal-only strategy |
| `showcase-dapp/` | Public demo surface | Demonstrations, examples | Canonical product UX |

## Prioritized build/repair list (business operating maturity)

P0 (portfolio integrity and “who owns what”):

1. Add explicit **business unit charters** and a lightweight portfolio **ownership model** (approvers, escalation).
2. Fix submodule hygiene so the pinned portfolio is mechanically reliable (including CI/automation that fails when `.gitmodules` and this map diverge in either direction, or when any gitlink is missing a `.gitmodules` entry).
3. Add a boundary **interface registry** (APIs/schemas/contracts) so units can move independently without silent drift.
4. Add cross-unit **change control** rules so BOS/OpenSpec updates happen at the right times.
5. Standardize **documentation classification** rules (git vs Linear) to prevent ZSE drift.
6. Introduce a machine-readable portfolio manifest that can be validated against `.gitmodules` and used to prevent drift between this document and BOS runtime artifacts (including resolving the `./conxian-business/` naming collision by renaming the nested state directory to something unambiguous).

P1 (separation enforcement and partner legibility):

1. Extend `make unbundle` (root `Makefile`) into a portfolio-wide boundary check (disallowing known cross-contamination patterns).
2. Ensure every flagship repo README follows the role-line and linkage rules defined in `docs/REPO_PORTFOLIO.md` and links back to this map.

P2 (operating controls):

1. Standardize cross-unit release signaling (what “ready” means for Protocol vs Wallet vs Gateway vs Nexus).
2. Add a stable “portfolio dashboard” document (target: `docs/PORTFOLIO_DASHBOARD.md`) that tracks maturity status per unit (docs-only; no sensitive details).
