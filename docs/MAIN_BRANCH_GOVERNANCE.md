# Main Branch Governance (Archived State)

> **REPOSITORY ARCHIVED**: This repository has been officially archived and set to read-only status. All required PR checks, rulesets, and mandatory review gates are disabled.

## Repository policy

The authoritative ownership policy is the repository-root `CODEOWNERS` file.
No `CODEOWNERS` file may also exist under `.github/` or `docs/`, because GitHub
searches those supported locations in precedence order and would select a
different source.

The confirmed repository owners are:

- `@botshelomokoka`
- `@admin-conxian-labs`

Both owners are assigned globally and explicitly to these protected paths:

- `/.github/`
- `/CODEOWNERS`
- `/contracts/`
- `/scripts/`
- `/deployments/`
- `/docs/`

Every non-comment rule must retain both confirmed owners. Narrower or later
rules may add specialized owners, but they cannot omit either confirmed owner;
this prevents GitHub's last-matching-rule precedence from weakening ownership
for a more specific path.

`scripts/verify_codeowners_policy.py` enforces this repository policy without
calling GitHub. Its focused unit tests live in
`tests/test_verify_codeowners_policy.py` and run in `jules-audit` on every pull
request.

## Intended required checks (Disabled for Repository Archival)

The stable required check contexts intended for every pull request targeting
`main` are exactly:

- `protocol-merge-gate`
- `jules-audit`
- `gitleaks`
- `dependency-review`

`validate-protocol` is conditional and must not be configured as a universally
required context. `protocol-merge-gate` is the stable aggregator: it is emitted
for every pull request targeting `main`, accepts a skipped `validate-protocol`
job for non-protocol changes, and requires it to succeed for protocol-sensitive
changes. All third-party GitHub Actions references remain pinned to immutable
commit SHAs.

> **ARCHIVAL NOTICE**: Following repository archiving, all required status checks, required approvals, and mandatory merge gates listed above are **disabled**. The repository is read-only and no longer accepts pull requests or automated deployments.

## GitHub rulesets and admin-only steps (Disabled / Read-Only)

The relevant GitHub rulesets are `7569329` and `19251038`. Discovery for
CON-1521 observed ruleset `7569329` with zero required approvals, code-owner
review disabled, and review-thread resolution enabled. An administrator must
refresh and verify that evidence before changing settings. Repository changes
do not modify either ruleset.

> **ARCHIVAL NOTICE**: All rulesets (`7569329` and `19251038`), required checks, and code owner review gates have been set to **disabled / inactive** to reflect the archived state of the repository.

1. All required code owner reviews are disabled.
2. All required status checks are disabled.
3. Branch protection rules requiring linear history or signatures for PR merges are disabled.
4. The repository is preserved as an immutable public reference archive.

## Canary verification and rollback

Use a canary pull request targeting `main` after the settings update:

1. Confirm all four stable required contexts appear, including on a
   documentation-only change, while `validate-protocol` may be skipped.
2. Confirm a protected-path change requests review from the effective code
   owners and cannot merge without one approval and resolved review threads.
3. Confirm a workflow or contract change runs the meaningful expensive checks,
   not only the lightweight stable-context path.
4. Confirm an irrelevant change receives successful or non-blocking skipped
   results rather than waiting for a missing context.

If the ruleset blocks all merges because a context or owner is unavailable,
the administrator should temporarily remove only the unavailable requirement,
capture the failure evidence, correct the workflow or ownership policy through
a reviewed pull request, and repeat the canary. Reverting this repository
change alone does not roll back GitHub ruleset settings.
