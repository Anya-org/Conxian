# BOS business buildout (conxian-business)

This document defines the business purpose and operating model for the public `conxian-business` repository, including:

- business-unit classification and placement
- a public-safe vs internal-only documentation split (Zero Secret Egress / ZSE)
- required governance + ownership + approval requirements
- a prioritized build/repair list

## Business-unit classification (repo placement)

**Classification:** Supporting repository (per `docs/REPO_PORTFOLIO.md`).

If the repo’s flagship/supporting placement changes in `docs/REPO_PORTFOLIO.md`, update this document in the same pull request.

**Business purpose (external/public):** provide a versioned, auditable trust surface for Conxian governance, OpenSpec requirements, and how the Conxian ecosystem repositories are coordinated.

**Business purpose (internal/operational):** serve as the canonical BOS (Business Operations System) baseline: a programmatic operating model (service loop + state machine artifacts) plus references to the EXCO agent-suite business units.

### What “lives” here (canonical surfaces)

| Surface | Primary location | Classification | Notes |
| --- | --- | --- | --- |
| OpenSpec (technical ground truth) | `openspec/` | Public-safe | Requirement definitions and spec-first change sets. |
| Governance and repo operating model | `GOVERNANCE.md`, `CODEOWNERS`, `CONTRIBUTING.md`, `.github/` | Public-safe | How the repo is run and reviewed. |
| BOS operating model artifacts | `conxian-business/` | Mixed (default internal-only for automation/state-machine artifacts) | Service-loop narrative can be public-safe; automation/state-machine artifacts are internal-only unless explicitly reviewed for safe disclosure. |
| EXCO agent-suite business units | `Sovereign-Strategy-Nexus/`, `Fiscal-Vault-Oracle/`, `Nakamoto-Guardian/`, `Sovereign-Ops-Orchestrator/` | Mixed | Treat strategic/ops runbooks and any monetization/treasury specifics as internal-only by default. |
| Ecosystem repo map | `docs/REPO_PORTFOLIO.md` | Public-safe | Canonical “flagship vs supporting” placement. |
| Documentation classification index | `docs/DOCUMENTATION_ALIGNMENT_INDEX.md` | Public-safe | Canonical index of what exists + how it should be referenced/migrated. |

## Public/private split recommendation (ZSE)

This repository is public. The split below is a policy recommendation for what should be stored in Git vs stored in Linear.

### Public-safe (keep in Git)

- OpenSpec requirements and design/spec documents that are intended as external ground truth.
- Governance docs, repo policies, and contribution requirements.
- Public product documentation and external-facing architecture/PRD material that has been scrubbed of privileged implementation details, secret formats, and exploit-enabling diagrams.
- Non-sensitive audits and public trust messaging.

### Internal-only (store in Linear Virtual Office; reference from Git)

- **Strategic:** valuation framing, M\&A narratives, competitive positioning, partnership negotiation details, and time-bound roadmap milestones.
- **Legal:** contracts, entity structuring, jurisdiction-specific filings, and anything that increases legal exposure if copied out of context.
- **Operational:** incident response, deployment runbooks with privileged access steps, vendor account procedures, treasury execution specifics.
- **Administrative:** secret provisioning, identity access management, and any material that would meaningfully aid an attacker even without secret values.

### ZSE guardrails (repo rules)

1. Never commit secrets (values) or credential material.
2. If a document must be referenced but is internal-only, keep only:
   - a short public-safe summary, and
   - a pointer to the canonical Linear document.
3. Treat “internal-only” as the default for:
   - strategy and treasury narratives
   - monetization and fee/royalty specifics
   - operational runbooks that describe privileged workflows

## Required docs (business, governance, ownership)

### Minimum public-safe set (this repository)

| Document | Requirement | Owner/approver |
| --- | --- | --- |
| `README.md` | Role line + purpose + pointers to canonical docs. Avoid internal strategy and operational detail. | Repo code owners (`CODEOWNERS`). |
| `docs/REPO_PORTFOLIO.md` | Canonical placement of this repo in the org trust surface. | Repo code owners. |
| `docs/DOCUMENTATION_ALIGNMENT_INDEX.md` | Canonical map of what docs exist + what’s canonical + what should be migrated to Linear. | Repo code owners. |
| `GOVERNANCE.md` | Governance model, ownership, and approval rules (high-level; no sensitive ops). | Repo code owners. |
| `CODEOWNERS` | Review + ownership routing. | Repo code owners. |
| `CONTRIBUTING.md` | Contribution workflow and linking expectations (Linear ↔ GitHub). | Repo code owners. |
| `SECURITY.md` | Security policy and private reporting process. | Repo code owners. |
| `ARCHIVE_MIGRATION.md` | ZSE-safe pointer for legacy/removed material. | Repo code owners. |
| `CHANGELOG.md` | Public, versioned changes to BOS/OpenSpec policies and externally visible behavior. | Repo code owners. |

### Minimum internal-only set (Linear Virtual Office)

Maintain these as Linear documents (canonical for privileged detail), referenced from Git as needed:

- Detailed BOS operating model semantics (privileged service-loop + state-machine runbooks; Git keeps only public-safe summaries and pointers).
- Execution wiring: Linear ↔ state layer ↔ repo automation.
- ZSE / knowledge retention policy and migration manifests.
- Secret management spec (procedural, privileged access).
- Strategy/legal/ops/admin material that cannot be safely versioned in public Git.

## Governance, ownership, and approval workflow (repo expectations)

1. All changes land via pull request.
2. Every pull request must link to a Linear issue.
3. `CODEOWNERS` review is required for any change.
4. Any change that redefines BOS boundaries, OpenSpec requirements, or the doc-classification policy must:
   - update `docs/DOCUMENTATION_ALIGNMENT_INDEX.md` where relevant, and
   - include a `CHANGELOG.md` entry when it changes externally visible behavior or expectations.
5. Any internal-only material referenced from Git must point to Linear as the canonical source.

## Prioritized build/repair list

1. Keep `README.md` aligned with the “supporting repo” role line and remove internal strategy/ops detail from the public entrypoint.
2. Keep `GOVERNANCE.md` as an explicit ownership + approval model tied to `CODEOWNERS` (not just a stub).
3. Treat `docs/DOCUMENTATION_ALIGNMENT_INDEX.md` as the canonical “doc registry” and keep it updated whenever docs are added, moved, or reclassified.
4. Migrate internal-only documents that materially increase operational exposure to Linear, leaving behind only ZSE-safe summaries and links.
