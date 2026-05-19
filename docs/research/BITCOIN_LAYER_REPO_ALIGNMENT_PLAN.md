# Bitcoin Layer Repo Alignment Plan

## Purpose

This document maps the current Conxian repository portfolio against the Bitcoin layer capability strategy and identifies what should be kept, split, demoted, or strengthened.

## Strategic thesis

Conxian should be positioned as:

- infrastructure for builders
- native support tooling for Bitcoin and Bitcoin-connected layers
- a capability and integration platform

Conxian should not be positioned as:

- a direct retail financial service
- a clone of all upstream SDKs
- a monolithic wallet or platform that owns every layer directly

## Current repository roles

### `lib-conxian-core`

**Target role**

- shared capability interfaces
- trust and verification primitives
- common models for transaction intent and signer policy
- layer-agnostic abstractions where justified

**Observed concern**

- appears to include gateway-related areas, which blurs the boundary between shared core and integration layer

**Action**

- keep as primary strategic repo
- remove or isolate gateway-specific logic
- make this the canonical home of the cross-layer capability model

### `conxian-gateway`

**Target role**

- integration and adapter layer
- provider and node connectivity
- bridge and external protocol boundaries
- mainnet-safe submission and observation services for builders

**Observed concern**

- generally aligned, but must remain clearly separate from wallet UX and shared-core logic

**Action**

- keep as primary strategic repo
- make this the home for Bitcoin, Lightning, Stacks, Rootstock, and Liquid adapters
- avoid embedding consumer product behavior here

### `conxius-enclave-sdk`

**Target role**

- secure signer abstraction
- enclave and hardware trust integration
- policy-constrained signing support
- attestation and device trust helpers where relevant

**Observed concern**

- directionally strong, but should stay tightly focused on signer and trust capabilities

**Action**

- keep as primary strategic repo
- use as the secure execution layer beneath all network adapters and clients

### `conxius-platform`

**Target role**

- local composition environment
- integration harness
- testing, observability, and developer runtime
- internal and partner validation surface

**Observed concern**

- currently risks becoming a catch-all or the de facto home of too much ecosystem logic

**Action**

- keep, but narrow its purpose
- treat it as the environment and orchestration repo, not the canonical business logic repo
- use it to stand up Bitcoin/LN/Stacks integration scenarios for builders

### `conxius-wallet`

**Target role**

- reference client
- capability demonstration surface
- test and validation harness for end-user interaction models

**Observed concern**

- contains adjacent module references and mixed concerns that suggest boundary overlap
- if left unbounded, it could pull the company toward a wallet-company identity rather than a builder-platform identity

**Action**

- demote from portfolio center
- keep as a reference client, not the core strategy
- remove embedded or overlapping integration logic over time

### `Conxian`

**Target role options**

Option A:
- canonical protocol repo

Option B:
- umbrella documentation and reference repo

**Observed concern**

- includes gateway-related areas, which makes its purpose ambiguous

**Action**

- decide its role explicitly
- if protocol repo: remove adjacent integration logic
- if umbrella repo: reduce executable overlap and keep reference/spec focus

### `conxian-nexus`

**Target role**

- API and interoperability surface
- optional service boundary for external builder integrations

**Observed concern**

- naming and role are less clear than gateway/core/platform

**Action**

- clarify whether it is:
  - public API facade,
  - interoperability service,
  - or internal bridge layer
- if it overlaps materially with gateway, merge or narrow

### `conxius-orbit`

**Target role**

- deployment and contract developer tooling
- reference deployment workflow support

**Observed concern**

- likely useful, but should stay tool-focused

**Action**

- keep as a supporting repo for developer operations
- avoid letting it become a general platform repo

### `conxian-labs-site`

**Target role**

- public communication and developer entrypoint

**Action**

- keep as public narrative and onboarding surface
- update messaging to reflect builder-platform strategy

### `conxian_ui`

**Target role**

- optional shared interface library or prototype surface

**Observed concern**

- role is not clearly tied to the builder-platform thesis

**Action**

- clarify whether it remains relevant
- merge, archive, or reposition if it duplicates wallet or site concerns

## Portfolio classification

### Primary strategic repos

- `lib-conxian-core`
- `conxian-gateway`
- `conxius-enclave-sdk`
- `conxius-platform`

### Secondary supporting repos

- `conxian-nexus`
- `conxius-orbit`
- `conxian-labs-site`

### Reference or demonstrator repos

- `conxius-wallet`
- potentially `conxian_ui`

### Private strategy and coordination repos

- `conxian-business`
- `.github-private`

### Governance baseline repos

- `.github`

## Boundary rules

### Rule 1: core must not own adapters

`lib-conxian-core` must not become the place where Bitcoin, Lightning, Stacks, or provider-specific integrations are actually implemented.

### Rule 2: gateway must not become the wallet

`conxian-gateway` should expose integration capability, not consumer product experience.

### Rule 3: platform must not become the truth source

`conxius-platform` should compose and verify, not silently become the canonical home of logic that belongs in core or gateway.

### Rule 4: wallet is a reference surface

`conxius-wallet` should demonstrate capabilities, not define the company strategy.

### Rule 5: every repo needs one sentence of purpose

Each public repo should have a precise and non-overlapping statement of:

- what it owns
- what it does not own

## Implementation priorities

### Priority 0: declare portfolio intent

- adopt the builder-platform thesis
- explicitly state Conxian is helping others support Bitcoin and its layers natively

### Priority 1: define dependency direction

Target dependency direction:

- wallet -> core/gateway/enclave-sdk
- platform -> composes core/gateway/enclave-sdk
- gateway -> core
- core -> minimal upward dependencies
- reference clients -> never become hidden sources of shared logic

### Priority 2: isolate overlap

- remove gateway logic from `Conxian` if it is not the gateway repo
- remove gateway-related areas from `lib-conxian-core`
- reduce embedded adjacent references from `conxius-wallet`

### Priority 3: make layer support explicit

For each first-class layer:

- Bitcoin mainnet
- Lightning
- Stacks

identify:

- adapter owner
- signer owner
- verification owner
- simulation owner
- reference example owner

### Priority 4: standardize release expectations

All primary strategic repos should publish releases and changelog discipline.

Minimum target:

- versioned tags
- release notes
- compatibility notes where needed

### Priority 5: align public narrative

Public messaging should say:

- Conxian helps builders support Bitcoin and Bitcoin-connected layers natively
- Conxian provides shared capability infrastructure, security abstractions, and integration tooling
- Conxian is not trying to become every downstream product

## First execution steps

### Step 1

Create a shared architecture note in a public technical repo that defines:

- canonical capability verbs
- repo ownership boundaries
- first-class layer scope

### Step 2

Open implementation tasks for:

- Bitcoin mainnet adapter completeness
- Lightning adapter completeness
- Stacks adapter completeness
- secure signer abstraction standardization

### Step 3

Audit code placement in:

- `lib-conxian-core`
- `conxian-gateway`
- `conxius-wallet`
- `Conxian`

and identify what must move or be deprecated.

### Step 4

Reframe `conxius-wallet` as a reference client in docs and planning.

### Step 5

Update top-level portfolio documentation to classify repos as:

- core
- adapter
- platform
- reference
- public narrative
- internal strategy

## Suggested near-term outputs

- architecture boundary doc
- layer support roadmap
- repo dependency map
- public portfolio narrative update
- release standard for strategic repos

## Summary

The current portfolio already contains the right ingredients.

What is needed now is:

- sharper repo boundaries
- clearer strategic classification
- explicit first-class support for Bitcoin mainnet, Lightning, and Stacks
- disciplined treatment of reference surfaces versus strategic infrastructure

Conxian should look like a builder enablement platform for Bitcoin layers, not a blended collection of overlapping products.