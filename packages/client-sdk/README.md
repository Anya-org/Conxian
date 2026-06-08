# `@conxian/client-sdk`

Internal client helpers for the BOS control plane.

This package provides typed admin/runtime client helpers that target the canonical v1 contract in:
`docs/architecture/CONTROL_PLANE_ADMIN_RUNTIME_API_CONTRACT.md`.

## Runtime-backed behavior

All workflow mutations and runtime reads now call canonical `/admin/v1/...` endpoints and return `Promise` results.

No synthetic bootstrap success responses are returned.

If runtime configuration is missing, calls fail closed by throwing `AdminRuntimeConfigError`.

## Configuration

You must provide a runtime base URL through either:

- `configureAdminRuntimeClient({ runtimeBaseUrl: "https://runtime.example" })`, or
- environment variable `CONXIAN_ADMIN_RUNTIME_BASE_URL` (fallback: `ADMIN_RUNTIME_BASE_URL`).

Optional:

- `fetchImpl` for custom fetch implementations in non-standard runtimes/tests
- `defaultHeaders` for auth/context headers shared across requests

## Endpoint coverage

### Workflow mutations

- `requestReleaseApprovalV1` → `POST /admin/v1/releases/request-approval`
- `submitReleaseDecisionV1` → `POST /admin/v1/releases/decision`
- `submitGovernanceDecisionV1` → `POST /admin/v1/governance/decision`
- `acknowledgeSafetyModeV1` → `POST /admin/v1/safety-mode/ack`

### Runtime reads

- `getControlPlaneHealth` / `getRuntimeHealthV1` → `GET /admin/v1/runtime/health`
- `getRuntimeReadinessV1` → `GET /admin/v1/runtime/readiness`
- `listReleaseArtifacts` → `GET /admin/v1/releases`
- `listGovernanceActions` → `GET /admin/v1/governance-actions`
- `listAuditEvents` / `listAuditEventsV1` → `GET /admin/v1/audit-events`
- `listEnvironments` / `listEnvironmentsV1` → `GET /admin/v1/environments`
- `listRuntimeChainsV1` → `GET /admin/v1/chains`
- `getRuntimeChainStatusV1` → `GET /admin/v1/chains/{chain}/status`
- `listAttestationsV1` → `GET /admin/v1/attestations`
- `getAttestationV1` → `GET /admin/v1/attestations/{id}`
- `getRuntimeDriftV1` → `GET /admin/v1/drift`
- `getSafetyModeV1` → `GET /admin/v1/safety-mode`
- `getPromotionEvidenceV1` → `GET /admin/v1/promotion-evidence/{release}`

## Minimal usage

```ts
import {
  configureAdminRuntimeClient,
  requestReleaseApprovalV1,
  getRuntimeReadinessV1,
} from "@conxian/client-sdk";

configureAdminRuntimeClient({ runtimeBaseUrl: "https://nexus-admin.internal" });

const approval = await requestReleaseApprovalV1({
  artifactId: "rel_123",
  requestedBy: "operator_7",
  notes: "Meets release gate criteria",
});

const readiness = await getRuntimeReadinessV1();
```
