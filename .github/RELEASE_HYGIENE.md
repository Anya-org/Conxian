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
    - Submodule integrity via `scripts/verify_submodule_integrity.py`.
- Branch promotion policy (see [`branch-promotion-policy.yml`](./workflows/branch-promotion-policy.yml))
- Secret scan (see [`secret-scan.yml`](./workflows/secret-scan.yml))
- Dependency review (see [`dependency-review.yml`](./workflows/dependency-review.yml))

### Label-gated suites (opt-in, based on change scope)

Some suites only run when a label is applied. Most label-gated suites live in the Unified CI workflow (see [`conxian-unified-ci.yml`](./workflows/conxian-unified-ci.yml)). Apply the label early so CI starts immediately.

| When you touch… | Add label | Expected CI suite |
| --- | --- | --- |
| `conxian-gateway/` or infra deployment concerns | `infra` | Gateway suite |
| `conxian-nexus/` or `lib-conclave-sdk/` | `b2b` | B2B suite (Nexus & SDK) |
| `conxius-wallet/` | `b2c` | B2C wallet suite |
| transparency audit or documentation validation | `audit` | Transparency audit + docs |
| StacksOrbit testnet simulation scripts | `simulation` | Testnet simulation |

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
- Before merge:
  - Required checks are green.
  - Appropriate label-gated suites ran (when relevant).
  - Changelog is updated when user-facing behavior or security posture changes.

Merge preference:

- Prefer squash-merge so `main` stays readable and the merge commit message captures the PR intent.

## Changelog and release policy references

- Changelog file: `CHANGELOG.md`
- Changelog + release notes format: `docs/RELEASE_NOTES_AND_CHANGELOG.md`
- Templates:
  - `docs/templates/CHANGELOG_TEMPLATE.md`
  - `docs/templates/RELEASE_NOTES_TEMPLATE.md`
