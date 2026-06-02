# BOS Control-Plane Target Architecture

This document defines the target architecture for evolving `conxian-business` into the private BOS control plane for the Conxian ecosystem.

## Decision

`conxian-business` is the **private control plane** for governance, audit, release, policy, and environment-level coordination.

It is **not** the primary end-user application and it is **not** the runtime execution engine.

## Repo roles

### `conxian-business`
- Private BOS control plane
- Governance and OpenSpec source of truth
- Internal operator workflows
- Release governance and audit views
- Environment and policy coordination
- Shared workspace packages for schemas and internal client access

### `conxian-nexus`
- Trusted orchestration and runtime APIs
- State coordination
- Runtime execution and policy enforcement hooks
- Admin-facing APIs consumed by the control plane

### `conxian-gateway`
- External protocol and banking integrations
- ISO and middleware concerns
- Adapter and integration boundary

### `conxian_ui`
- Web experience for operators and public-facing workflows
- Product/UI concerns only

### `conxius-wallet`
- Mobile wallet experience
- Device and user journey concerns only

### `Conxian`
- Clarity smart contracts
- On-chain invariants and settlement logic

## Language strategy

### TypeScript
Use TypeScript for:
- web applications
- control-plane UI
- shared schemas and client SDKs
- application-level orchestration surfaces

### Rust
Use Rust for:
- trusted runtime services
- signing, attestation, gateway, and policy-heavy services
- long-running orchestrators and sensitive back-end components

### Clarity
Use Clarity only for:
- smart contracts
- on-chain business rules
- settlement and verification logic

### Python
Use Python only for:
- tooling
- scripts
- CI helpers
- migration and research tasks

## Control-plane modules

The initial module set for the BOS control plane is:
- release governance
- audit dashboard
- policy approvals
- environment registry

## Directory target inside `conxian-business`

```text
conxian-business/
  apps/
    control-plane/
  packages/
    schemas/
    client-sdk/
  docs/
  openspec/
  governance/
  audit/
  infrastructure/
  scripts/
```

## Integration model

The control plane should consume trusted services from `conxian-nexus` and related runtime components.

It should not directly re-implement runtime execution, banking middleware, or on-chain contract responsibilities.

## Initial execution backlog

- #710 Define BOS control-plane boundaries and repo ownership
- #711 Scaffold internal BOS control-plane application
- #712 Create shared domain schemas and internal client SDK packages
- #713 Design admin API contracts between the control plane and `conxian-nexus`
- #714 Plan first control-plane modules
- #715 Establish 12-month roadmap
