# Auth

This document is the canonical auth and authorization note for the BOS control plane in `conxian-business`.

## Research result

As of June 2, 2026, there was no pre-existing `auth.md` or equivalent auth-specific markdown document in `conxian-business`.

This file is introduced to give the control-plane work a stable reference point.

## Scope

This document applies to the internal BOS control-plane application under `apps/control-plane`.

## Authentication

Near-term assumptions:
- every non-public route requires an authenticated actor
- actor identity should come from a trusted identity provider or internal session layer
- bootstrap code currently uses a synthetic local actor and must be replaced before production use

Future target:
- SSO-backed authentication
- server-validated session context
- auditable actor identity for all mutating actions

## Authorization

The control plane uses role-based authorization as the initial model.

Roles:
- `viewer`
- `operator`
- `approver`
- `admin`

See `docs/architecture/CONTROL_PLANE_AUTHORIZATION_MODEL.md` for the detailed module-level permission matrix.

## Security rules

- the control plane never performs privileged runtime execution directly
- authorization must be checked in trusted runtime services as well as in the UI
- all mutating operations must produce audit events
- sensitive flows should support dual control
- missing runtime dependencies must fail closed

## Current implementation status

Current bootstrap implementation includes:
- role scaffolding in `apps/control-plane/lib/auth.ts`
- UI gating helpers for read, operate, and approve behaviors
- typed workflow request/response models in `packages/schemas`
- workflow client wrappers that will later call trusted runtime admin APIs

## Follow-up

- replace the synthetic actor with real session-backed identity
- add server-side auth integration
- align runtime authorization checks in `conxian-nexus`
- add tests around auth gating and workflow authorization
