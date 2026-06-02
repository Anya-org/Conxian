# Control-Plane Repo Evolution Plan

This plan describes how `conxian-business` should evolve from a governance/orchestration monorepo into a private BOS control-plane repository.

## Current state

The repository already contains:
- governance and OpenSpec material
- release and security documentation
- Docker and workspace orchestration
- submodule wiring into adjacent repos
- audit and operational artifacts

## Target state

The repository should become the canonical home for:
- BOS control-plane UI
- internal control workflows
- shared domain schemas
- internal client SDKs
- repo-wide architecture decisions

## What should stay out

The following should not become the default responsibility of this repository:
- consumer-facing product UI
- public website concerns
- mobile app implementation
- runtime execution engines
- banking middleware implementation
- smart contract implementation

## Evolution phases

### Phase 0
- Establish boundaries and ownership
- Add ADRs and target architecture documents
- Create workspace placeholders for the control plane and shared packages

### Phase 1
- Scaffold `apps/control-plane`
- Add `packages/schemas` and `packages/client-sdk`
- Document admin API contracts to runtime services

### Phase 2
- Implement release governance and audit modules
- Introduce policy approval flows and environment registry
- Align shared schemas with runtime contracts

### Phase 3
- Harden access control, auditability, and operational visibility
- Connect additional runtime capabilities through clean service contracts
- Prepare for partner and auditor-ready workflows

## Success criteria

- Contributors can easily tell where a change belongs
- Internal BOS workflows have a clear home
- Runtime and UI concerns remain separated
- Shared contracts can evolve without repeatedly restructuring the repo
