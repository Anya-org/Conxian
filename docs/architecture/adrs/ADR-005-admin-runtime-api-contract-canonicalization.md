# ADR-005: Admin/runtime API contract canonicalization

## Status
Accepted

## Context
The admin/runtime boundary was documented across multiple overlapping files, which introduced drift in endpoint paths, contract assumptions, and implementation guidance.

The overlapping files were:
- `docs/ADMIN_RUNTIME_API_BOUNDARY.md`
- `docs/architecture/CONTROL_PLANE_ADMIN_API_V1.md`
- `docs/architecture/NEXUS_ADMIN_SERVICE_BOUNDARY_V1.md`

## Decision
Adopt a single canonical contract path for control-plane ↔ runtime admin API behavior:

- Canonical contract: `docs/architecture/CONTROL_PLANE_ADMIN_RUNTIME_API_CONTRACT.md`

The following documents are superseded and retained only as pointer stubs:
- `docs/ADMIN_RUNTIME_API_BOUNDARY.md`
- `docs/architecture/CONTROL_PLANE_ADMIN_API_V1.md`
- `docs/architecture/NEXUS_ADMIN_SERVICE_BOUNDARY_V1.md`

All future contract changes for this boundary must be applied to the canonical contract document.

## Consequences
- Contract evolution has one source of truth, reducing drift and merge ambiguity.
- Existing links to superseded docs continue to resolve through pointer stubs.
- PRs that change admin/runtime endpoint behavior should update the canonical contract and, when decision-level intent changes, append or add a new ADR.
