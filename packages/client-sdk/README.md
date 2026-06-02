# `@conxian/client-sdk`

Internal client helpers for the BOS control plane.

This package is the future home for admin-facing clients that talk to trusted runtime services such as `conxian-nexus`.

## Current structure
- root exports for bootstrap reads and writes
- `src/release-governance.ts` for release workflow helpers
- `src/governance.ts` for governance workflow helpers

## Current behavior
The workflow clients currently return accepted bootstrap responses and are intended to be replaced with real admin/runtime calls that implement the v1 contracts documented in `docs/architecture/CONTROL_PLANE_ADMIN_API_V1.md`.