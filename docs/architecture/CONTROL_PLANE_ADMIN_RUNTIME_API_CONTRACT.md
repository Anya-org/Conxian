# Control-Plane Admin/Runtime API Contract

This document defines the initial boundary between the BOS control plane in `conxian-business` and trusted runtime services, primarily in `conxian-nexus`.

## Boundary rule

The control plane orchestrates, reviews, approves, and observes.

The runtime validates, executes, signs, persists, and integrates.

## Design principles

- Fail closed for sensitive operations
- Keep privileged execution out of the control-plane app
- Use typed contracts for admin-facing operations
- Treat auditability as a first-class concern
- Keep public/runtime APIs distinct from internal admin APIs

## Admin-facing capability groups

### 1. Release governance
Used by the control plane to manage release readiness and approvals.

Candidate endpoints:
- `GET /admin/releases`
- `GET /admin/releases/:id`
- `POST /admin/releases/:id/request-approval`
- `POST /admin/releases/:id/approve`
- `POST /admin/releases/:id/reject`
- `POST /admin/releases/:id/promote`

### 2. Audit visibility
Used by the control plane to inspect operational evidence and historical actions.

Candidate endpoints:
- `GET /admin/audit-events`
- `GET /admin/audit-events/:id`
- `GET /admin/audit-events/stream`

### 3. Policy approvals
Used by the control plane to review and approve governance/policy actions before runtime execution.

Candidate endpoints:
- `GET /admin/governance-actions`
- `GET /admin/governance-actions/:id`
- `POST /admin/governance-actions/:id/approve`
- `POST /admin/governance-actions/:id/reject`
- `POST /admin/governance-actions/:id/request-changes`

### 4. Environment registry
Used by the control plane to view environment metadata and promotion state.

Candidate endpoints:
- `GET /admin/environments`
- `GET /admin/environments/:id`
- `POST /admin/environments/:id/verify`
- `GET /admin/promotions`

## Operations that must remain outside the control plane

The following must not be implemented as direct privileged logic in `conxian-business`:
- key custody
- transaction signing
- banking/ISO middleware execution
- oracle execution
- contract submission
- external protocol settlement
- direct secret material management

## Response shape guidance

Admin endpoints should return typed payloads aligned with `packages/schemas`.

Minimum common fields:
- `id`
- `status`
- `owner`
- `updatedAt`
- `auditRef` when applicable

## Security expectations

- All write operations require authenticated actor context
- High-risk operations must emit audit events
- Sensitive actions should support dual-control approval where needed
- Missing runtime dependencies should return explicit failure states, not simulated success

## Next implementation steps

- formalize TypeScript types in `packages/schemas`
- add client helpers in `packages/client-sdk`
- wire route modules in `apps/control-plane`
- map runtime ownership to `conxian-nexus` implementation tickets
