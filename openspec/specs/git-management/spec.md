# git-management Specification

## Purpose

Define the minimum git and submodule management capabilities needed to operate the Conxian workspace (status visibility, clean working trees, and safe synchronization).
## Requirements
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

