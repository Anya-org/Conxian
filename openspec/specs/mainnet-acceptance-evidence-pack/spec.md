# mainnet-acceptance-evidence-pack Specification

## Purpose

Define the canonical evidence pack required for any promotion from `staged` to `main`.

The evidence pack is an auditable, reviewable artifact that proves:

- mainnet-only production scope
- no stub, mock, placeholder, or testnet residue in production paths
- successful production validation
- release-readiness sign-off
- clear owner accountability for the promoted code

## Requirements

### Requirement: Evidence pack is mandatory for `staged` -> `main`

For any repository in the Conxian portfolio:

- Any pull request targeting `main` with head branch `staged` MUST include a Mainnet Acceptance Evidence Pack.
- The promotion MUST NOT be merged unless the evidence pack is complete.

#### Scenario: Promoting from staged to main

- **WHEN** a pull request targets `main`
- **AND** its source branch is `staged`
- **THEN** the pull request MUST include a Mainnet Acceptance Evidence Pack
- **AND** the evidence MUST be sufficient to prove production safety for mainnet

### Requirement: Evidence pack format

The evidence pack MUST be captured in one of these forms:

1. In the promotion PR description, under a heading `### Mainnet acceptance evidence pack`, or
2. As a versioned file in-repo (recommended), e.g. `audit/mainnet-acceptance/<YYYY-MM-DD>_<PR-NUMBER>_<SHORT-SHA>.md`, linked from the PR description.

The evidence pack MUST be readable without privileged access.

- Allowed: links to public CI runs, public commit SHAs, public artifacts, public runbooks.
- Not allowed: secrets, private keys, internal-only incident procedures, or operational steps that increase attack surface.

### Requirement: Evidence pack content

The evidence pack MUST include the sections below.

#### 1) Promotion metadata (owner accountability baseline)

The evidence pack MUST include:

- Repository name
- Promotion PR link
- Pre-merge tip-of-`main` SHA
- Merge-base of `main` and `staged` SHA
- `staged` head commit SHA
- SHA capture timestamp (ISO 8601 UTC)
- Canonical remote name (used for all SHA/URL capture, e.g. `origin` or `upstream`)
- Canonical remote fetch URL(s) (verbatim output; preserve line order; may be multi-line) (e.g. `git remote get-url --all <canonical-remote>`; MUST be credential-free; if embedded credentials are present, fix the git remote configuration and re-run until output is credential-free)
- Canonical remote push URL(s) (record output verbatim; preserve line order; may be multi-line. If all push URL(s) are identical to fetch URL(s), you may record `Same as fetch URL(s) above` instead of duplicating the list) (e.g. `git remote get-url --push --all <canonical-remote>`; MUST be credential-free; if embedded credentials are present, fix the git remote configuration and re-run until output is credential-free)
- Change owner (single accountable human)
- Required approvers (CODEOWNERS) who signed off
- Business unit(s) impacted

Together, these SHAs and the capture timestamp identify the exact change window being promoted (from the merge-base to the `staged` head), the pre-merge state of `main`, and when that snapshot was taken.

Capture these SHAs **immediately before merging** the promotion PR (after all required checks/approvals are green).

You MUST run `git fetch --prune <canonical-remote> main staged` first so that the `<canonical-remote>/*` refs are current (`--prune` removes stale `<canonical-remote>/*` refs that no longer exist on the remote). `<canonical-remote>` MUST point at the canonical `<org>/<repo>` remote, not a fork (on forks this is typically `upstream`).

Record:

- Canonical remote name: `<canonical-remote>`
- Pre-merge tip-of-`main`: `git rev-parse <canonical-remote>/main`
- Merge-base: `git merge-base <canonical-remote>/main <canonical-remote>/staged`
- `staged` head: `git rev-parse <canonical-remote>/staged`
- SHA capture timestamp: `date -u +%Y-%m-%dT%H:%M:%SZ`
- Canonical remote fetch URL(s): `git remote get-url --all <canonical-remote>` (record output verbatim; preserve line order; MUST be credential-free; if embedded credentials are present, fix the git remote configuration and re-run until output is credential-free)
  - Fallback (older Git): `git config --get-all remote.<canonical-remote>.url` (or `git remote -v` and take the `(fetch)` lines)
- Canonical remote push URL(s): `git remote get-url --push --all <canonical-remote>` (record output verbatim; preserve line order; MUST be credential-free; if embedded credentials are present, fix the git remote configuration and re-run until output is credential-free. If all push URL(s) are identical to fetch URL(s), you may record `Same as fetch URL(s) above` instead of duplicating the list)
  - Fallback (older Git): `git config --get-all remote.<canonical-remote>.pushurl` (or `git remote -v` and take the `(push)` lines)

The configured canonical remote URL(s) can be multi-line (multi-URL remotes). Preserve the output verbatim (including line order).

The configured canonical remote URL(s) MUST be credential-free (no embedded tokens, `user:pass@`, etc.). If embedded credentials are present, do not record the output; fix the git remote configuration and re-run until output is credential-free. If embedded credentials were captured in any drafts, redact them immediately.

If the merge is delayed or `<canonical-remote>/main` or `<canonical-remote>/staged` advances after capture, re-capture and update the evidence pack before merging.

After the merge (or any other updates to `<canonical-remote>/main` or `<canonical-remote>/staged`), re-running `git fetch --prune <canonical-remote> main staged` and then the commands above will yield different values. Reviewers and auditors SHOULD rely on the SHAs recorded in the evidence pack as the source of truth for the pre-merge window.

#### 2) Mainnet-only production scope

The evidence pack MUST clearly state what is being promoted, including:

- A concise summary of the production intent (“what is different on mainnet after this merge”).
- The scope boundary (what is explicitly _not_ part of this promotion).
- Any configuration or dependency pins that affect mainnet behavior (submodules, lockfiles, container tags, etc.).

#### 3) Contamination and residue proof (no stubs/mocks/testnet in production paths)

The evidence pack MUST include evidence that production paths are clean of:

- stubs/mocks/placeholders
- testnet-only principals, endpoints, or default network selections
- references to generated local-only artifacts

“Production paths” means any code/config that can execute in CI, in a deployed runtime, or as a maintainer operational script.
Docs and specs may reference testnet for explanation, but production paths MUST NOT depend on testnet defaults.

Minimum required proof MUST include at least one of:

- A passing “production boundary” check provided by the repo (preferred), or
- Explicit scans (commands + results) over the repo’s production paths.

Recommended scan set (adapt globs per repo):

```bash
# Fail fast on common residue markers in non-doc code.
rg -n --glob '!docs/**' --glob '!openspec/**' --glob '!**/*.md' --glob '!**/*.test.*' --glob '!**/*.spec.*' \
  '(MOCK_|\\bstub\\b|\\bmock\\b|\\bplaceholder\\b|\\bFIXME\\b|\\bTODO\\b)'

# Detect testnet principals embedded as string literals (Stacks testnet prefixes).
rg -n --glob '!docs/**' --glob '!openspec/**' --glob '!**/*.md' \
  "['\"](?:ST|SN)[0-9A-Z]{20,}(?:\\.[a-zA-Z0-9-]{1,128})?['\"]"

# Detect hard-coded testnet defaults in operational scripts.
rg -n --glob 'scripts/**' "networkFromName\\(\\s*['\"]testnet['\"]\\s*\\)"
```

#### 4) Successful production validation

The evidence pack MUST include:

- A link to a passing CI run for the promotion commit (or the promotion PR) showing required checks green.
- Evidence that any label-gated suites relevant to the change scope ran (when applicable).
- Any repo-specific production validations (smoke tests, migrations, contract checks) that are required for mainnet safety.

#### 5) Release-readiness sign-off

The evidence pack MUST include a release-readiness decision.

- The accountable owner MUST explicitly record `GO` or `NO-GO` for promoting `staged` into `main`.
- If the decision is `GO`, the evidence pack MUST link to any canonical readiness gates that apply to the business unit(s) (for example, a mainnet readiness gate doc) and record that the gate is satisfied or not applicable.

#### 6) Clear owner accountability

The evidence pack MUST name a single accountable owner (human) who accepts responsibility for the promotion.

- This owner MUST be a required reviewer (or equivalent approver) on the promotion PR.
- The owner MUST confirm the evidence pack was reviewed for completeness.

## Template

Copy/paste and fill out for any `staged` -> `main` promotion PR.

```md
### Mainnet acceptance evidence pack

#### Promotion metadata

- Repo: `<org>/<repo>`
- Promotion PR: <link>
- Pre-merge tip-of-`main` SHA: `<sha>`
- Merge-base of `main` and `staged` SHA: `<sha>`
- `staged` head commit SHA: `<sha>`
- SHA capture timestamp: `Captured at (UTC): <YYYY-MM-DDTHH:MM:SSZ>` (after `git fetch --prune <canonical-remote> main staged`; before merge)
- Canonical remote name: `<canonical-remote>` (MUST point at the canonical `<org>/<repo>` remote; on forks this is typically `upstream`)
- Canonical remote fetch URL(s) (e.g. from `git remote get-url --all <canonical-remote>`; fallback: `git config --get-all remote.<canonical-remote>.url`; preserve line order; MUST be credential-free; if embedded credentials are present, fix the git remote configuration and re-run until output is credential-free):
  - `<url>` (one line per command output line; preserve order)
- Canonical remote push URL(s) (e.g. from `git remote get-url --push --all <canonical-remote>`; fallback: `git config --get-all remote.<canonical-remote>.pushurl`; preserve line order; MUST be credential-free; if embedded credentials are present, fix the git remote configuration and re-run until output is credential-free):
  - `Same as fetch URL(s) above` (use only if all push URL(s) are identical to the fetch URL(s); otherwise delete this line)
  - `<url>` (one line per command output line; preserve order; if you list URLs here, remove the `Same as fetch URL(s) above` line above)
- Accountable owner: `<name>` (GitHub: `@<handle>`; optional: `<public Linear profile URL if available>`)
- Approvers (CODEOWNERS): `@<handle>`, `@<handle>` (optional: names)
- Business unit(s): `<bu>`

#### Mainnet-only production scope

- Summary:
  - `<what changes on mainnet>`
- Out of scope:
  - `<what this promotion explicitly does not include>`
- Mainnet-relevant pins/config:
  - `<submodules, versions, tags, env var defaults>`

#### Contamination and residue proof

- Production boundary check:
  - `<link to CI step or command output>`
- Residue scans:
  - `rg ...` result: `<clean | link>`
  - `rg ...` result: `<clean | link>`

#### Successful production validation

- CI run: <link>
- Required checks: `<green>`
- Label-gated suites (if applicable): `<ran | not applicable>`
- Repo-specific validations:
  - `<what ran, with links>`

#### Release-readiness sign-off

- Decision: `GO` / `NO-GO`
- Readiness gates:
  - `<link to gate + status>`

#### Owner accountability

- I (accountable owner) confirm this evidence pack is complete and accurate.
  - Name/date: `<name>, <YYYY-MM-DD>`
```
