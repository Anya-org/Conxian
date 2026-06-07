# Admin Runtime API Boundary

## Purpose

Define the initial control-plane to runtime API boundary between `conxian-business` and `conxian-nexus`.

This document focuses on admin and operator workflows only. It does not redefine public protocol APIs, wallet signing, or custody behavior.

## Architectural intent

- `conxian-business` is the private control-plane and operator surface.
- `conxian-nexus` is the runtime state, proof, ordering, and trust-classification plane.
- `conxian-gateway` remains the policy, capability, transaction-preparation, and routing surface for external-facing integration flows.
- Signing remains outside all three services.

## Boundary rule

`conxian-business` may orchestrate trusted admin workflows, but it must not absorb runtime chain logic that belongs in `conxian-nexus` or public integration logic that belongs in `conxian-gateway`.

## Capability ownership

### Owned by `conxian-business`
- release governance approvals
- environment and deployment registry metadata
- audit review workflows and operator annotations
- policy approval queues
- change-control requests
- operator-facing dashboards and work queues

### Owned by `conxian-nexus`
- chain ingestion and reorg handling
- canonical off-chain state and state attestations
- proof generation and trust classification
- runtime sequencing and execution ordering
- drift and safety state
- runtime metrics and health state

### Owned by `conxian-gateway`
- capability discovery for supported chain families
- prepared transaction construction
- proof-verification surfaces for integration consumers
- routing and controlled submission flows
- policy/compliance enforcement at integration boundaries

### Must not be implemented directly in `conxian-business`
- chain-family transaction builders
- state proof verification engines
- signer/key custody logic
- wallet operations
- public-facing multichain integration APIs
- hidden runtime backdoors that bypass Nexus or Gateway control surfaces

## Admin-facing API surface from `conxian-nexus`

These are the initial admin/runtime contracts that `conxian-business` should consume.

## 1. Runtime health and readiness

### `GET /admin/runtime/health`
Returns summarized runtime health.

Fields:
- service status
- database status
- cache status
- sync lag status
- degraded mode status
- last successful attestation timestamp

### `GET /admin/runtime/readiness`
Returns readiness gates for promotion decisions.

Fields:
- gate name
- status
- evidence link/reference
- blocking reason
- last updated

## 2. Chain and adapter status

### `GET /admin/chains`
Returns supported chains and current runtime status.

Fields:
- chain key
- adapter family
- environment
- sync height
- finality class
- trust tier default
- degraded/healthy flag

### `GET /admin/chains/{chain}/status`
Detailed runtime status for a specific chain.

Fields:
- current head
- finalized head
- lag metrics
- reorg window
- proof mode
- last error

## 3. State attestations and proofs

### `GET /admin/attestations`
List recent state attestations.

Filters:
- chain
- trust tier
- proof type
- date range

### `GET /admin/attestations/{id}`
Detailed attestation record.

Fields:
- normalized subject
- source chain
- observed block/height
- proof type
- trust tier
- freshness window
- drift status
- evidence hash/reference

## 4. Drift and safety

### `GET /admin/drift`
List active drift or divergence conditions.

### `GET /admin/safety-mode`
Current safety mode and trigger reason.

### `POST /admin/safety-mode/ack`
Operator acknowledgement for review workflows only.

Constraint:
- acknowledgement must not disable runtime protection on its own
- protection changes require separate policy-approved action

## 5. Promotion evidence

### `GET /admin/promotion-evidence/{release}`
Returns runtime evidence package for promotion decisions.

Fields:
- release identifier
- environment
- readiness gates
- sync status snapshot
- drift snapshot
- attestation/proof summary
- linked artifacts

## 6. Environment registry read surfaces

### `GET /admin/environments`
Returns registered environments and their declared purpose.

### `GET /admin/environments/{env}`
Returns environment metadata and runtime references.

Constraint:
- this surface returns metadata only
- no secret material should ever be returned

## Fail-closed expectations

- If trust tier is unknown, responses must default to non-promotable.
- If proof verification state is unavailable, the control-plane must treat the runtime condition as degraded.
- If attestation freshness is stale, promotion and sensitive admin workflows must block by default.
- If chain status is missing or inconsistent, the control-plane must display an explicit unknown/degraded state rather than inferring healthy operation.
- No admin API should return private keys, signing material, raw secrets, or privileged bypass tokens.

## Response classification

Every admin-facing runtime response should carry:
- `status`: healthy | degraded | blocked | unknown
- `trust_tier`
- `evidence_level`: doc_only | code_visible | test_visible | release_visible | environment_verified | externally_verified
- `last_updated`

## Backlog seed

### `conxian-business`
- build release-governance dashboard against `/admin/runtime/readiness`
- build audit review view against `/admin/attestations` and `/admin/drift`
- build environment registry UI against `/admin/environments`

### `conxian-nexus`
- implement `/admin/runtime/health`
- implement `/admin/runtime/readiness`
- implement `/admin/chains`
- implement `/admin/attestations`
- implement `/admin/drift`
- implement `/admin/promotion-evidence/{release}`

## Open questions

- should operator acknowledgements be persisted in Nexus or written back from the control-plane only?
- should `conxian-business` consume Nexus directly, or through a dedicated BFF in front of Nexus?
- which runtime evidence artifacts must be immutable before a release can be promoted?
