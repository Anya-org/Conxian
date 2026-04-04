# workspace-audit Specification

## Purpose

Define the minimum workspace-level audit capabilities required for BOS operations (repo hygiene, documentation alignment, and verification of public/private boundaries).
## Requirements
### Requirement: Full workspace file audit

The system MUST provide a comprehensive list and state analysis of all files and directories across the entire workspace, including submodules.

#### Scenario: Running the workspace audit

- **WHEN** the audit process is executed
- **THEN** all files across all business units and modules are reviewed
- **THEN** the review assesses adherence to the Conxian Ethos and Core Principles

### Requirement: Business unit and module analysis

The audit MUST categorize files according to their respective business units and modules to ensure modular architecture compliance.

#### Scenario: Categorizing modules

- **WHEN** examining files
- **THEN** they are grouped by their respective submodule/module context
- **THEN** inter-module dependencies are identified and documented

### Requirement: Public/private boundary verification (ZSE)

The audit MUST verify that sensitive roots (for example, `internal/strategy/` and `archive/`) are not tracked in the active Git index, and that any ignored sensitive paths are covered by the knowledge-retention manifest.

#### Scenario: Verifying ZSE compliance

- **WHEN** the workspace audit is executed
- **THEN** it fails if any sensitive paths are tracked
- **AND** it fails if any ignored sensitive paths are not covered by `audit/migration_manifest.json`

### Requirement: Documentation alignment

The audit MUST detect broken intra-repo documentation links (including links into checked-out submodules) so documentation remains navigable in BOS-critical workflows.

#### Scenario: Detecting broken markdown links

- **WHEN** the documentation audit is executed
- **THEN** it reports missing local markdown targets as errors

