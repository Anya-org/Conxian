# ADR-003: Shared schemas and internal client SDK packages

## Status
Accepted

## Context
The control plane needs shared contracts with runtime services, but the repository does not yet have a lightweight package structure for this.

## Decision
Add:
- `packages/schemas` for domain contracts and shared types
- `packages/client-sdk` for internal API client helpers

## Consequences
- Shared contracts get a clear home.
- Future admin/runtime integrations can evolve without major repo restructuring.
- Type-level drift between UI and service contracts can be reduced.
