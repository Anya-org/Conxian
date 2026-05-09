# lib-conxian-core Gateway Extraction Plan

## Purpose

This document defines the first concrete extraction plan for issue #646: separating gateway runtime and adapter implementation concerns from `lib-conxian-core` while preserving the shared abstractions that belong in core.

## Why this extraction is needed

Direct repo inspection confirmed that `lib-conxian-core` contains a substantial `gateway/` subtree with:

- runtime entrypoints
- API/server handler code
- engine/runtime modules
- MCP-specific implementation
- infrastructure/deployment artifacts

This conflicts with the approved boundary model where:

- `lib-conxian-core` owns shared capability interfaces and safety primitives
- `conxian-gateway` owns canonical adapter and integration runtime concerns

## Extraction goal

After cleanup:

- `lib-conxian-core` should expose only reusable interfaces, shared types, and safety/verification primitives
- `conxian-gateway` should own the gateway runtime, API/server surfaces, adapter implementations, and deployment/runtime concerns

## Confirmed gateway material in `lib-conxian-core`

The following material is currently present inside the `gateway/` subtree:

- `gateway/src/main.rs`
- `gateway/src/lib.rs`
- `gateway/src/mcp_server.rs`
- `gateway/src/api/mcp_handler.rs`
- `gateway/src/api/mod.rs`
- `gateway/src/api/tests.rs`
- `gateway/src/engine/mcp.rs`
- `gateway/src/engine/support.rs`
- `gateway/src/engine/remediation.rs`
- `gateway/src/engine/mod.rs`
- `gateway/Cargo.toml`
- `gateway/Cargo.lock`
- `gateway/infrastructure/gcp/deployment.yaml`

## Placement decisions

## Move to `conxian-gateway`

These concerns are runtime- or adapter-oriented and should move out of core:

- binary/runtime entrypoints
  - `gateway/src/main.rs`
- gateway server surface
  - `gateway/src/mcp_server.rs`
- API and request handler implementation
  - `gateway/src/api/mcp_handler.rs`
  - other `gateway/src/api/*` implementation files
- engine/runtime orchestration
  - `gateway/src/engine/mcp.rs`
  - `gateway/src/engine/support.rs`
  - `gateway/src/engine/remediation.rs`
  - other runtime engine modules
- gateway-specific package manifests
  - `gateway/Cargo.toml`
  - `gateway/Cargo.lock`
- deployment artifacts
  - `gateway/infrastructure/gcp/deployment.yaml`

## Split before moving

Some files may include a mix of reusable abstractions and runtime-specific implementation. These should be split so only shared primitives remain in core.

Candidates for split-first review:

- `gateway/src/lib.rs`
- `gateway/src/api/mod.rs`
- `gateway/src/engine/mod.rs`

### Keep in `lib-conxian-core` only if extracted cleanly

- shared traits or interfaces
- shared request/response types that are not runtime-specific
- shared verification and policy primitives
- types reused by more than one adapter or runtime surface

## Keep in `lib-conxian-core`

The following categories should remain in core, even if they are currently tangled with gateway code:

- shared capability interfaces
- shared transaction intent models
- signer policy abstractions
- verification primitives
- reusable safety logic
- common types required across more than one adapter or runtime

## Extraction sequence

### Phase 1 — Inventory and split points

- inspect each `gateway/` file in `lib-conxian-core`
- label each item as:
  - keep
  - move
  - split
- identify reusable shared abstractions that need a stable home in core

### Phase 2 — Introduce target modules in `conxian-gateway`

- create or align destination modules in `conxian-gateway`
- mirror the extracted runtime/API structure there where appropriate
- keep naming intentional so the gateway repo becomes the obvious canonical home

### Phase 3 — Move implementation

- move runtime entrypoints and API/server implementation first
- move engine/runtime modules next
- move deployment artifacts last

### Phase 4 — Stabilize interfaces

- verify that any retained core abstractions are:
  - implementation-agnostic
  - reusable
  - documented as shared primitives rather than gateway runtime code

### Phase 5 — Clean references and docs

- update READMEs and ownership docs if necessary
- remove misleading gateway references from core docs
- add links from core to gateway where the runtime now lives

## Risk controls

To avoid breaking downstream work:

- do not delete mixed files until replacements exist in `conxian-gateway`
- preserve stable shared types in core where they are broadly reused
- move in small reviewable PRs rather than one destructive rewrite
- keep a short migration note for contributors

## Suggested PR breakdown

### PR 1

- add migration note and target structure
- extract obvious runtime entrypoints

### PR 2

- move API/server implementation

### PR 3

- move engine/runtime modules

### PR 4

- move deployment artifacts and clean docs

### PR 5

- final simplification of remaining core gateway references

## Definition of done

This extraction is complete when:

- `lib-conxian-core` no longer contains gateway runtime ownership
- `conxian-gateway` clearly owns the extracted implementation
- core contains only reusable shared abstractions
- contributor-facing docs reflect the new ownership cleanly

## Summary

The extraction should be guided by one simple rule:

- if it is reusable interface or safety logic, keep it in core
- if it is gateway runtime or adapter implementation, move it to `conxian-gateway`

This is the highest-leverage cleanup for restoring architecture clarity between core and gateway.