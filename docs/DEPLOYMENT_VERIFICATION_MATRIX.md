# Deployment verification matrix (runtime lanes)

This document defines a **minimum** verification baseline for validating **packaging changes** (build/release/deploy surface) across the Conxian runtime lanes.

Goal: ensure changes that affect artifacts (lockfiles, build scripts, containers, deployment manifests, CI, submodules) can be promoted consistently **before pilot use**.

## Definitions

- **Packaging change**: any change that can alter a deployable artifact or its provenance. Common examples:
  - CI workflows (`.github/workflows/*`)
  - repo hygiene / verification scripts (`scripts/*`)
  - lockfiles (`Cargo.lock`, `pnpm-lock.yaml`, submodule pins)
  - container build or runtime packaging (`Dockerfile*`, compose/k8s manifests)
  - release/promotion policy or artifact-provenance documentation (e.g. `docs/BRANCH_*`, release hygiene docs, evidence-pack specs under `openspec/specs/*`)
- **Runtime lane**: the environment branch + deployment context used for validation and promotion:
  - `dev`: testnet-only and non-production validation
  - `staged`: mainnet candidate validation
  - `main`: mainnet-only production

Reference: `docs/BRANCH_AND_PROMOTION_STANDARD.md`.

## Matrix (summary)

The table below is intentionally compact; details are defined in the lane sections that follow.

| Lane | Build | Test | Security | Upgrade | Rollback | Verification outputs |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `dev` | Deterministic artifact build; dependency pins intentional | CI green + testnet smoke where applicable | Secret scan + dependency review clean | Upgrade path rehearsed (non-prod) | Rollback rehearsed (non-prod) | CI run link + artifact digests + smoke evidence |
| `staged` | Same as `dev`, plus mainnet-candidate build parity | CI green + candidate smoke + migration checks | Secret scan + dependency review clean; no testnet residue in production paths | Roll-forward rehearsed with prod-like config | Rollback exercised in controlled candidate env | Candidate validation notes + residue scans + pre-evidence pack |
| `main` | Reproducible production artifacts | Required checks green | Full mainnet acceptance evidence pack | Production upgrade is policy-guarded | Production rollback trigger + last-known-good proven | Evidence pack + commit SHA → artifact digest map |

## Lane criteria

### Lane: `dev` (testnet / non-production)

**Build**

- CI must build from a clean checkout (and, if the repo uses submodules, `actions/checkout` + `submodules: recursive`).
- Any dependency pin changes are explicit (lockfiles, submodule SHAs) and reviewable.
- If submodule SHAs change, record the old/new SHAs in the PR description (or other lane evidence notes) and include the relevant boundary/contamination check output.

**Test**

- All always-on PR checks are green.
- If the packaging change affects a runtime path, a lane-appropriate smoke test is executed against testnet/non-prod.

**Security**

- Secret scanning and dependency review checks (e.g., automated repo security checks such as GitHub secret scanning/dependency review, where enabled) are green.
- No new privileged control-plane assumptions are introduced (keep credentials scoped and capability-based).

**Upgrade**

- If the change requires an upgrade step (migrations, config changes), that step is documented public-safely (no secrets, no signer procedures).

**Rollback**

- A last-known-good artifact exists (tag, digest, or commit SHA) and can be redeployed in the same lane.

**Verification outputs (minimum evidence)**

- PR link + CI run link for the change.
- Artifact identity proof (at least one of): container image digest, binary checksum, or commit SHA → artifact mapping.

### Lane: `staged` (mainnet candidate validation)

This lane is where packaging changes become **pilot-ready** for mainnet-candidate environments.

**Build**

- Same requirements as `dev`.
- Build parity checks: artifacts must be built using the same build system and dependency pins intended for `main`.

**Test**

- All always-on PR checks are green.
- Any repo/business-unit suite relevant to the change scope must run (see `docs/RELEASE_HYGIENE_CONXIAN_NEXUS.md`).
- Candidate smoke test(s) run in a prod-like configuration where feasible (without leaking operational details into git).

**Security**

- Secret scanning and dependency review checks (e.g., automated repo security checks such as GitHub secret scanning/dependency review, where enabled) are green for the promotion candidate commit.
- No “testnet defaults” remain in production paths.
- No new stub, mock, placeholder, or debug-only behavior is introduced in any path that can reach `main`.

**Upgrade**

- Upgrade steps are compatible with mainnet-candidate rollout (idempotent, replay-safe, and observable).
- Any schema/migration step must have explicit ownership and a failure mode that fails closed.

**Rollback**

- Rollback steps are validated in a controlled candidate environment at least once.
- Rollback does not depend on private or personal wallets; it must use operational/system authorities.

**Verification outputs (minimum evidence)**

- CI run link + residue scan or boundary-check output (for example, checks under `scripts/` such as `python3 scripts/verify_contamination_guard.py` or other `python3 scripts/verify_*.py`, where applicable), recorded in the PR description (or linked evidence notes).
- Candidate smoke test evidence (CI job output link preferred), referenced in the PR description (or linked evidence notes) alongside the CI run link. If manual commands are needed, they MUST be sanitized/redacted (no endpoints, credentials, identifiers, or operational procedures) and stored outside git; link that documentation from the PR.
- Artifact digest / checksum and the exact commit SHA the artifact was built from.

### Lane: `main` (mainnet production)

This lane is only for production-ready promotions.

**Build / Test / Security**

- Required checks are green for the exact promotion candidate commit.
- Promotion follows the ordered path `dev` -> `staged` -> `main`.

**Upgrade / Rollback / Verification**

- A `staged` -> `main` promotion MUST include a Mainnet Acceptance Evidence Pack.
- The evidence pack is the canonical record for:
  - contamination/residue proof (no stubs/mocks/testnet residue)
  - upgrade notes (if any)
  - rollback trigger + last-known-good rebuild path

Reference (canonical): `openspec/specs/mainnet-acceptance-evidence-pack/spec.md`.

## Notes

- This matrix defines a **minimum** baseline; business-unit specific readiness gates still apply (e.g., SAB pilot readiness gates in `docs/SAB_MIGRATION_READINESS_GATES.md`).
- Keep ZSE constraints: no secrets, signer identities, private endpoints, or operational procedures in git.
