## ADDED Requirements

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
