# Control-Plane Admin API v1

This document defines the first versioned request/response contract layer for BOS control-plane workflows.

## Versioning rule

All admin workflow contracts should be versioned explicitly at the schema and endpoint level.

Current version: `v1`

## Workflow groups

### Release governance

#### `POST /admin/v1/releases/request-approval`
Request body:
- `artifactId`
- `requestedBy`
- `notes`

Response body:
- `accepted`
- `requestId`
- `auditEventId`
- `message`

#### `POST /admin/v1/releases/decision`
Request body:
- `artifactId`
- `decision`
- `actorId`
- `notes`

Response body:
- `accepted`
- `decisionId`
- `auditEventId`
- `message`

### Policy approvals

#### `POST /admin/v1/governance/decision`
Request body:
- `actionId`
- `decision`
- `actorId`
- `notes`

Response body:
- `accepted`
- `decisionId`
- `auditEventId`
- `message`

## Read models

### `GET /admin/v1/releases`
Returns a list of release artifacts.

### `GET /admin/v1/governance-actions`
Returns a list of governance actions.

### `GET /admin/v1/audit-events`
Returns a list of audit events.

### `GET /admin/v1/environments`
Returns a list of environment records.

## Security requirements

- authenticated actor required
- mutating endpoints must emit audit events
- decision endpoints must support policy enforcement in the runtime layer
- the control plane must not fabricate successful runtime execution outcomes
