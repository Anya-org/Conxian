# Release and merge hygiene

This repository uses GitHub Actions workflows in `.github/workflows/` as the source of truth for what CI *can* run. The repository’s branch protection rules define which checks are *required* to merge to `main`.

The goals:

- Keep `main` always mergeable and safe to deploy.
- Ensure every merge has clear provenance (Linear issue + PR).
- Make releases and changelogs easy to audit.

## Branch and promotion standard

This repository uses a three-branch model:

- `dev` = testnet-only and non-production validation
- `staged` = mainnet candidate validation
- `main` = mainnet-only production code

Promotion rules:

- No direct promotion from `dev` to `main`.
- Promotion to `main` happens only from `staged`.

Reference: `docs/BRANCH_AND_PROMOTION_STANDARD.md` and `openspec/specs/git-management/spec.md`.

## Required checks guidance

### Always-on checks for PRs targeting `dev`, `staged`, or `main`

These workflows run on every pull request targeting `dev`, `staged`, or `main`. Branch protection rules determine which checks are *required* to merge into protected branches (typically `staged`/`main`), and promotion PRs are expected to have all checks green before merge.

*Note:* check names shown in the PR UI may drift over time; rely on the PR UI’s required checks list when in doubt.

- Unified CI (see [`conxian-unified-ci.yml`](./workflows/conxian-unified-ci.yml))
  - Repo hygiene:
    - ZSE knowledge retention via `scripts/verify_knowledge_retention.py`.
    - Tracked artifact scanning via `scripts/verify_tracked_artifacts.py`.
      - False positives can be allowlisted via `.github/artifact-scan-allowlist.txt` (case-sensitive; paths are normalized to forward slashes with no leading `./`):
        - Plain (non-glob) patterns (no glob metacharacters such as `*`, `?`, or bracket expressions like `[a-z]`):
          - If the pattern contains `/`, it is matched against the full normalized path.
          - Plain patterns can also match a directory prefix at a path boundary (e.g., `audit/reports` matches `audit/reports/<...>` but not `audit/reports-old/<...>`).
          - If the pattern does not contain `/`, it also matches basenames anywhere in the repo and exact normalized paths.
        - Glob patterns (contain glob metacharacters such as `*`, `?`, or bracket expressions like `[a-z]`):
          - If the pattern contains `/`, it is matched against the full normalized path.
          - If the pattern does not contain `/`, it is matched against basenames only (it does not match full normalized paths; add `/` when you need full-path matching).
        - Examples:
          - `junit.xml` matches any tracked file with basename `junit.xml` anywhere in the repo.
          - `audit/reports` matches any tracked file under `audit/reports/` (path-boundary directory-prefix match; does not match `audit/reports-old/`).
          - `*.log` matches any tracked `.log` file by basename, so use with care.
    - Submodule integrity via `scripts/verify_submodule_integrity.py`.
    - Release hygiene via `scripts/verify_release_hygiene.py`.
      - Fails when root `CHANGELOG.md` is missing `## [Unreleased]`.
      - Fails when the root `README.md` BOS version marker (`(BOS vX.Y.Z)`) does not match the latest root `CHANGELOG.md` release.
      - Checks release tags for this repository origin and critical user-facing submodules when `VERIFY_RELEASE_HYGIENE_CHECK_ORIGIN_TAGS=true` (enabled in Unified CI).
    - Docs public-safe preflight via `scripts/build_pages_artifact_public_safe.sh` (fail-fast allowlist validation used by both Unified CI and docs deploy).
    - Governance baseline via `scripts/verify_repo_governance_baseline.py`.
- Branch promotion policy (see [`branch-promotion-policy.yml`](./workflows/branch-promotion-policy.yml))
- Secret scan (see [`secret-scan.yml`](./workflows/secret-scan.yml))
- Dependency review (see [`dependency-review.yml`](./workflows/dependency-review.yml))

## CI failure taxonomy and summary interpretation

CI summaries use this failure taxonomy:

- `repo-content`: failure is attributable to this PR's repository changes. This is merge-blocking.
- `external-platform`: failure is likely caused by platform/API/entitlement/baseline conditions outside this PR's content. This is non-blocking in summary-gate classification and should be retried or escalated.

How maintainers should interpret summary checks:

1. **`Conxian Unified CI / CI Summary Gate`**
   - Reports PR scope as `docs-only` vs `code-impacting`.
   - For `docs-only` PRs, repo-hygiene + governance/security baseline checks still run; heavyweight implementation suites are intentionally skipped.
   - The summary gate fails only when required `repo-content` checks fail.
2. **`Dependency Review / Dependency Review Gate`**
   - Always posts a check result (never disappears due path-ignore behavior).
   - If no dependency manifests/lockfiles changed, it passes with explicit `not applicable` evidence.
   - If dependency risk findings are detected, classification is `repo-content` (merge-blocking).
   - If execution fails without dependency findings, classification is `external-platform` (non-blocking) with retry guidance.

## GitHub settings required outside this repository

Some promotion controls are configured in **GitHub repository settings** (not in Git-tracked files).

Minimum required setup:

1. Ensure `staged` exists as a long-lived branch (typically created from `dev`).
2. Add branch protection (or an active branch ruleset) for `staged` and `main`.
3. Require these status checks on `staged` and `main`:
   - `Conxian Unified CI`
   - `Branch Promotion Policy / Enforce branch promotion rules`
   - `Secret Scan`
   - `Dependency Review`
4. Require at least one approving review on `staged` and `main`.
5. Disable force-pushes and branch deletion on `staged` and `main`.

`scripts/verify_promotion_controls.py` validates the in-repo workflow policy plus `dev`/`staged`/`main` branch topology and protection/ruleset presence.

### Label-gated suites (opt-in, based on change scope)

Some suites only run when a label is applied. Most label-gated suites live in the Unified CI workflow (see [`conxian-unified-ci.yml`](./workflows/conxian-unified-ci.yml)). Apply the label early so CI starts immediately.

| When you touch… | Add label | Expected CI suite |
| --- | --- | --- |
| `conxian-gateway/` or infra deployment concerns | `infra` | Gateway suite |
| `conxian-nexus/` or `lib-conclave-sdk/` | `b2b` | B2B suite (Nexus & SDK) |
| `conxius-wallet/` | `b2c` | B2C wallet suite |
| transparency audit or documentation validation | `audit` | Transparency audit + docs |
| Conxius Orbit testnet simulation scripts | `simulation` | Testnet simulation |

Notes:

- The label-gated jobs only run for PRs opened from branches in this repository (not forks).
- For PRs opened from forks, a maintainer is responsible for ensuring the relevant suites run before merge.
- `showcase-dapp/` PRs can also trigger the Showcase DApp preview deployment workflow when `infra` is applied (see [`showcase-dapp-deploy.yml`](./workflows/showcase-dapp-deploy.yml)).

## PR and merge expectations

- No direct commits to `main`. Use a PR.
- Use the correct base branch (`dev`, `staged`, or `main`) based on the branch and promotion standard.
- One PR = one focused change (keep it reviewable).
- PRs should map to a Linear issue (include it in the PR description).
- Follow `CODEOWNERS` for review routing.
- Validate locally before requesting review (CI is the gate, not the first signal).
- Before merge:
  - Required checks are green.
  - Appropriate label-gated suites ran (when relevant).
  - Changelog is updated when user-facing behavior or security posture changes.

## Tagged releases (governed strategic/public repos)

The governed strategic/public repository set is:

- `Conxian`
- `conxian-gateway`
- `conxian-nexus`
- `conxius-wallet`

For these repositories, we expect releases to be cut as **SemVer tags** (`vX.Y.Z`) with:

- a matching `CHANGELOG.md` entry, and
- GitHub Release notes copied from the matching changelog section.

`Conxian Unified CI` runs `scripts/verify_release_hygiene.py` with staged enforcement:

- **Merge-blocking:** root `CHANGELOG.md` in this repo must include `## [Unreleased]`.
- **Advisory (current default):** governed strategic/public repo tag expectations run in `warn` mode (`VERIFY_RELEASE_HYGIENE_TAG_EXPECTATION_MODE=warn`).
- **Advisory scope extension:** set `VERIFY_RELEASE_HYGIENE_CHECK_ORIGIN_TAGS=true` to include this repository origin in tag checks.

Available tag expectation modes:

- `warn` (default): emit warnings only.
- `require`: fail CI when governed strategic/public tag expectations are not met.
- `off`: skip tag expectation checks.

Merge preference:

- Prefer squash-merge so `main` stays readable and the merge commit message captures the PR intent.

## Changelog and release policy references

- Changelog file: `CHANGELOG.md`
- Changelog + release notes format: `docs/RELEASE_NOTES_AND_CHANGELOG.md`
- Templates:
  - `docs/templates/CHANGELOG_TEMPLATE.md`
  - `docs/templates/RELEASE_NOTES_TEMPLATE.md`
