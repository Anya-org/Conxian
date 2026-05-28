# Conxian-business parent-control alignment baseline (CON-694)

This document operationalizes initiative-level lifecycle/control expectations for `conxian-business` and establishes an auditable baseline that can be enforced in CI.

## Scope boundary (what conxian-business owns and does not own)

`conxian-business` is a supporting BOS governance/specification repository.

**In scope (owned here):**

- BOS governance and operating-policy documentation for this repository.
- Public-safe control mappings, evidence expectations, and readiness/risk guidance.
- Cross-repo coordination pointers (without overriding the canonical source in owning repos).

**Out of scope (not owned here):**

- **Protocol truth:** canonical protocol contract semantics/implementation authority belongs to protocol repos and their canonical docs (for example `Conxian/` contracts and protocol PRD/spec artifacts).
- **DAO authority:** this repository documents governance boundaries but does not execute or supersede DAO timelock/policy authority.
- **Public treasury ownership:** this repository does not hold or define treasury custody ownership; custody and signer control remain in the designated custody/control model and on-chain authorities.

## Control-domain mapping (required six domains)

### Confidentiality

- **Canonical docs/controls:** `GOVERNANCE.md` (ZSE policy), `docs/BOS_BUSINESS_BUILDOUT.md` (public-safe vs internal-only split), `admin/SECRETS.md` (public-safe pointer stub).
- **Control expectation:** no sensitive legal/operational/secret material in Git; internal-only details remain in sovereign coordination systems.

### Operating policy

- **Canonical docs/controls:** `GOVERNANCE.md`, `CONTRIBUTING.md`, `docs/BRANCHING_AND_PROMOTION_POLICY.md`, `CODEOWNERS`.
- **Control expectation:** policy and boundary changes land through reviewed PRs with linked issue context and ownership routing.

### Service management

- **Canonical docs/controls:** `conxian-business/SERVICE_LOOP.md`, `docs/BOS_BUSINESS_BUILDOUT.md`, `docs/PRIVATE_REPO_REPO_CHECK_WORKFLOW.md`.
- **Control expectation:** operating model and service-loop responsibilities stay documented and consistent with repo classification.

### Quality

- **Canonical docs/controls:** `.github/workflows/conxian-unified-ci.yml`, `scripts/verify_repo_governance_baseline.py`, `docs/PROMOTION_CHECKLISTS.md`.
- **Control expectation:** governance baseline checks pass and promotion evidence remains objective/repeatable.

### Risk

- **Canonical docs/controls:** `docs/REPO_READINESS_GATES_BY_CONTROL_DOMAIN.md`, `docs/TRUST_AND_PROOF_MESSAGING.md`, `SECURITY.md`.
- **Control expectation:** control-domain exposure is explicit, externally safe claims stay aligned, and security reporting path remains accurate.

### Rollback

- **Canonical docs/controls:** `docs/operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md`, `docs/operations/CON-681_PHASE6_ROLLBACK_DRILL_SIMULATION.md`, `CHANGELOG.md`.
- **Control expectation:** rollback triggers/actions are defined, exercised, and traceable to versioned change history.

## Evidence expectations

For alignment changes, the evidence package must include:

1. Linked planning artifact(s): `CON-694` and/or GitHub `#717` (or successor issue).
2. Diff evidence showing updates to this baseline and any impacted canonical control docs.
3. Verification evidence (at minimum): successful `python3 scripts/verify_repo_governance_baseline.py` output.
4. Ownership evidence: `CODEOWNERS` review on the PR.
5. Boundary evidence: explicit confirmation that changes do not reassign protocol truth, DAO authority, or treasury ownership to this repo.

## Rollback and accountability expectations

- If this baseline is violated (missing required domains, broken boundaries, or conflicting authority claims), revert to the last known good commit and reopen alignment work under issue tracking.
- `CODEOWNERS`-designated policy owners are accountable for approving boundary/policy changes and rejecting drift.
- The issue owner is accountable for attaching verification evidence and documenting follow-up actions.
- Any emergency rollback should be recorded in `CHANGELOG.md` (or linked incident artifact) with rationale and remediation owner.

## Definition of done (alignment review checklist)

- [ ] Scope boundary is explicit and unchanged: this repo does not become protocol truth, DAO authority, or treasury owner.
- [ ] All six control domains remain mapped to canonical docs/controls.
- [ ] Evidence package contains linked issue(s), baseline verification output, and reviewer accountability.
- [ ] Governance/discoverability references (`GOVERNANCE.md` and index docs) point to this baseline.
- [ ] Rollback and accountability expectations are still actionable.
- [ ] No confidential/internal-only material was introduced into Git.
