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
- Pre-merge tip-of-`main` SHA (e.g. `git rev-parse origin/main`)
- Merge-base of `main` and `staged` SHA (e.g. `git merge-base origin/main origin/staged`)
- `staged` head commit SHA
- Change owner (single accountable human)
- Required approvers (CODEOWNERS) who signed off
- Business unit(s) impacted

Together, these SHAs identify the exact change window being promoted (from the merge-base to the `staged` head) and the pre-merge state of `main`.

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
- Pre-merge tip-of-`main` SHA (e.g. `git rev-parse origin/main`): `<sha>`
- Merge-base of `main` and `staged` SHA (e.g. `git merge-base origin/main origin/staged`): `<sha>`
- Head (`staged`) SHA: `<sha>`
- Accountable owner: `<name>` (`<GitHub handle>`, optional: `<public Linear profile URL if available>`)
- Approvers (CODEOWNERS): `<name/handle>`, `<name/handle>`
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
