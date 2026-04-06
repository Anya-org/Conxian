# git-management Specification

## Purpose

Define the minimum git and submodule management capabilities needed to operate the Conxian workspace (status visibility, clean working trees, and safe synchronization).

This spec also defines the canonical branch and promotion model used across the Conxian portfolio.

## Requirements

### Requirement: Canonical environment branches

The workspace MUST use the following branch roles consistently across all business units.

- `main`: mainnet-only production code.
- `staged`: mainnet candidate validation.
- `dev`: testnet-only and non-production validation.

#### Scenario: Selecting a base branch for a change

- **WHEN** a contributor opens a pull request
- **THEN** the base branch MUST reflect the change’s intended deployment target:
  - `dev` for testnet/non-production work
  - `staged` for mainnet-candidate validation
  - `main` only for mainnet production releases

### Requirement: Promotion constraints

The workspace MUST enforce an ordered promotion path.

- Promotion to `main` MUST happen only from `staged`.
- Promotion to `staged` MUST happen only from `dev` (or `hotfix/*`).
- Promotion to `staged` or `main` MUST originate from a branch in this repository (not a fork).
- Direct promotion from `dev` to `main` MUST NOT be permitted.

#### Scenario: Promoting a release to mainnet

- **WHEN** a mainnet release is ready to ship
- **THEN** it is promoted by merging `staged` into `main`
- **AND** the merge is blocked unless required CI checks and required approvals are satisfied

See [Requirement: Mainnet acceptance evidence for `staged` -> `main`](#mainnet-acceptance-evidence-staged-to-main) below.

#### Scenario: Attempting to promote directly into main from a non-staged branch

- **WHEN** a pull request targets `main`
- **AND** its source branch is not `staged`
- **THEN** the promotion MUST be rejected

#### Scenario: Attempting to promote directly into staged from a non-dev, non-hotfix branch

- **WHEN** a pull request targets `staged`
- **AND** its source branch is not `dev`
- **AND** its source branch does not match `hotfix/*`
- **THEN** the promotion MUST be rejected

<a id="mainnet-acceptance-evidence-staged-to-main" name="mainnet-acceptance-evidence-staged-to-main">&#8203;</a> <!-- Explicit anchor for cross-spec links; zero-width space helps preservation across renderers -->

### Requirement: Mainnet acceptance evidence for `staged` -> `main`

Any `staged` -> `main` promotion MUST include a Mainnet Acceptance Evidence Pack that satisfies all requirements defined in the canonical spec at [openspec/specs/mainnet-acceptance-evidence-pack/spec.md](../mainnet-acceptance-evidence-pack/spec.md).

### Requirement: Ownership and business-unit boundaries

The workspace MUST keep business-unit boundaries explicit and enforceable.

- Business-unit (and operating-function) ownership MUST be expressed via `CODEOWNERS`.
- Governance and release-policy changes MUST require approval from the repo owners defined in `CODEOWNERS`.

#### Scenario: Changing a business-unit scoped directory

- **WHEN** a pull request modifies a directory that maps to a business unit or operating function
- **THEN** GitHub MUST request review from the matching `CODEOWNERS` entries

#### Scenario: Changing governance or release policy

- **WHEN** a pull request modifies `openspec/`, `.github/`, `docs/`, or `scripts/`
- **THEN** GitHub MUST request review from the repo owners defined in `CODEOWNERS`

### Requirement: Git status review for all repositories

The system MUST be able to query and aggregate the git status of the root repository and all associated submodules.

#### Scenario: Checking git status

- **WHEN** the git status command is executed across the workspace
- **THEN** it reports uncommitted changes, unmerged paths, and detached HEAD states for all submodules
- **THEN** it aggregates this information into a consolidated view

### Requirement: Git repository management

The system MUST provide a mechanism to resolve conflicts, commit changes, and synchronize all submodules.

#### Scenario: Managing repositories

- **WHEN** uncommitted changes or conflicts are detected
- **THEN** appropriate git commands are proposed or executed to resolve them
- **THEN** the workspace is brought to a clean and synchronized state

### Requirement: Safe synchronization preconditions

The system MUST refuse to update or synchronize submodules when the root repo or any submodule has uncommitted changes or unmerged paths.

#### Scenario: Preventing sync on dirty workspaces

- **WHEN** a workspace sync is requested
- **AND** any repo/submodule is not clean
- **THEN** the operation is aborted
- **AND** the system reports the specific repos/submodules blocking the sync

### Requirement: Submodule definition integrity

The system MUST detect and report missing or inconsistent submodule definitions (for example, gitlinks present in the index without a corresponding `.gitmodules` entry).

#### Scenario: Validating submodule definitions

- **WHEN** a workspace audit or sync is initiated
- **THEN** the system validates that all submodules in the index have valid `.gitmodules` entries
- **AND** it reports missing mappings as a blocking error
