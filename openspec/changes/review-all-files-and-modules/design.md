## Context

The workspace contains multiple submodules and projects forming the overall `conxian-business` ecosystem. The current state requires a thorough review and clean-up of untracked files, uncommitted changes, and potential misalignments with the core Conxian architecture. We need a structured way to execute this audit using OpenSpec to track the status.

## Goals / Non-Goals

**Goals:**

- Systematically review all repositories within the `conxian-business` workspace.
- Identify and resolve `git status` issues (e.g., untracked files, unmerged paths).
- Document findings and implement any required cleanups.

**Non-Goals:**

- Implement new business logic or features in any of the submodules.
- Alter the core architecture without separate dedicated design proposals.

## Decisions

1. **Use OpenSpec for Tracking**: We will use OpenSpec changes to track the execution of this workspace audit. This provides an auditable trail of the review process.
2. **Sequential Audit**: The audit will proceed by traversing each submodule iteratively using `git submodule foreach`, verifying file contents against the Conxian Ethos, and managing git states.
3. **Resolve Conflicts Immediately**: Any git conflicts or unmerged paths found during the status check must be resolved as part of the management task.

## Risks / Trade-offs

- **Risk**: Touching many repositories might accidentally stage or commit unintended changes.
  - **Mitigation**: Rely strictly on structured `git status` checks and manual reviews before executing bulk commits.
- **Risk**: The audit takes too long due to the size of the monorepo/submodules.
  - **Mitigation**: Focus strictly on the requirements listed in the specs (file states and git status) rather than deep code analysis of every single line unless a violation of core principles is flagged.
