# Control-Plane ↔ Conxian-Nexus Admin Runtime API Contract

> **Canonical contract (CON-772):** This file is the single source of truth for the control-plane (`conxian-business`) ↔ runtime (`conxian-nexus`) admin API contract.
>
> Superseded drafts preserved as pointers:
> - `docs/ADMIN_RUNTIME_API_BOUNDARY.md`
> - `docs/architecture/CONTROL_PLANE_ADMIN_API_V1.md`
> - `docs/architecture/NEXUS_ADMIN_SERVICE_BOUNDARY_V1.md`

## Scope

This contract defines authenticated admin/operator API interactions between `conxian-business` and `conxian-nexus`.

In scope:
- release governance workflows
- policy/governance decisions
- audit and evidence visibility
- runtime readiness and safety signals
- environment registry metadata used for control-plane decisions

Out of scope:
- public integration APIs (owned by `conxian-gateway`)
- signer/key custody and secret material handling
- transaction building/submission execution logic

## Boundary and ownership

`conxian-business` owns orchestration UX, operator intent capture, and workflow presentation.

`conxian-nexus` owns validation, policy enforcement, runtime execution state, and durable audit/event evidence.

Implementation rules:
- the control plane must never bypass runtime authorization/policy checks
- runtime validation and authorization must always execute server-side in `conxian-nexus`
- sensitive runtime decisions must be represented as explicit API outcomes, never inferred by the control plane

## v1 endpoint surface (canonical)

All new admin/runtime routes are versioned under `/admin/v1`.

### Release governance
- `GET /admin/v1/releases`
- `POST /admin/v1/releases/request-approval`
- `POST /admin/v1/releases/decision`

### Policy approvals
- `GET /admin/v1/governance-actions`
- `POST /admin/v1/governance/decision`

### Audit visibility
- `GET /admin/v1/audit-events`

### Environment registry
- `GET /admin/v1/environments`

### Runtime readiness and evidence
- `GET /admin/v1/runtime/health`
- `GET /admin/v1/runtime/readiness`
- `GET /admin/v1/chains`
- `GET /admin/v1/chains/{chain}/status`
- `GET /admin/v1/attestations`
- `GET /admin/v1/attestations/{id}`
- `GET /admin/v1/drift`
- `GET /admin/v1/safety-mode`
- `POST /admin/v1/safety-mode/ack`
- `GET /admin/v1/promotion-evidence/{release}`

Compatibility note:
- legacy unversioned `/admin/...` drafts are non-canonical and must not be extended
- if temporary aliases are required during migration, they must be explicitly marked deprecated and route to the same v1 handlers

## Authentication and authorization baseline

- every endpoint requires authenticated actor context
- mutating operations require role/policy checks enforced in `conxian-nexus`
- write operations must emit durable audit events
- high-risk actions should enforce dual-control approval when policy requires it
- control-plane clients must treat authorization failures as terminal outcomes and surface them directly

## Fail-closed baseline

The contract defaults to safe denial/blocked states when evidence is incomplete:

- unknown trust tier => non-promotable (`blocked`)
- unavailable proof verification state => `degraded`
- stale attestation freshness => promotion/critical admin workflows blocked
- missing or inconsistent chain/runtime status => explicit `unknown`/`degraded` (never inferred healthy)
- safety-mode acknowledgements (`POST /admin/v1/safety-mode/ack`) must not disable protections by themselves
- no endpoint may return keys, signing material, or privileged bypass tokens

## Schema alignment

`packages/schemas` is the source package for shared TypeScript contracts.

Alignment rules:
- request/response interfaces for v1 admin routes must be defined/exported from `@conxian/schemas`
- naming stays camelCase in TypeScript and JSON payloads
- timestamps use ISO-8601 strings
- workflow mutations should align with `WorkflowMutationResponse` + route-specific IDs (`requestId`, `decisionId`)
- list/read responses should include stable identifiers and state fields (`id`, `status`, `owner`, `updatedAt`) where applicable
- runtime evidence responses should include explicit classification fields (`status`, `trustTier`, `evidenceLevel`, `lastUpdated`)

## Rollout guidance

1. **Canonicalize docs first**: keep this file canonical and keep superseded docs as pointer stubs only.
2. **Schema-first updates**: add/adjust v1 request/response interfaces in `packages/schemas` before route expansion.
3. **Runtime implementation**: implement canonical `/admin/v1/...` handlers in `conxian-nexus` with server-side validation, policy enforcement, and durable audit emission.
4. **Control-plane integration**: wire `packages/client-sdk` helpers and `apps/control-plane` routes to canonical v1 endpoints only.
5. **Fail-closed verification**: add tests that assert degraded/blocked behavior for missing evidence, stale attestations, and unknown trust posture.
6. **Alias retirement**: remove temporary non-v1 aliases once all consumers are migrated.
