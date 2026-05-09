# Repo Boundary Decision Record

## Status

Approved working decision

## Purpose

This decision record converts the repo boundary audit into explicit portfolio ownership rules for the Conxian builder-platform strategy.

It is intended to guide:

- repo cleanup
- roadmap planning
- README updates
- dependency direction
- future implementation work for Bitcoin mainnet and Bitcoin-connected layers

## Strategy basis

Conxian is aligning around the following thesis:

- Conxian helps builders support Bitcoin mainnet and Bitcoin-connected layers natively
- Conxian provides shared capability infrastructure, secure signer abstractions, integration tooling, and reference implementations
- Conxian is not primarily a direct financial service operator
- Conxian should not rebuild all upstream SDK functionality when composition is sufficient

## Canonical repo classes

### Primary strategic repos

These are core to the long-term builder-platform identity.

- `lib-conxian-core`
- `conxian-gateway`
- `conxius-enclave-sdk`
- `conxius-platform`

### Supporting repos

These support the strategic portfolio but are not the portfolio center.

- `conxian-nexus`
- `conxius-orbit`
- `conxian-labs-site`

### Reference repos

These demonstrate and validate capabilities but should not define the portfolio identity.

- `conxius-wallet`
- `conxian_ui` if retained

### Role-sensitive repos

These must be narrowed or explicitly classified.

- `Conxian`
- `conxian-nexus`

### Internal coordination and governance repos

- `conxian-business`
- `.github-private`
- `.github`

## Repo ownership decisions

## 1. `lib-conxian-core`

### Decision

`lib-conxian-core` is the canonical home of shared capability interfaces and safety primitives.

### Owns

- canonical capability verbs and interfaces
- shared transaction intent models
- verification primitives
- signer policy abstractions
- shared cross-layer safety rules
- shared data structures required by more than one layer adapter

### Does not own

- network adapters
- provider-specific logic
- wallet UX
- consumer workflows
- runtime orchestration

### Consequence

Any gateway, provider, or network-specific implementation currently living here should be moved or isolated behind interfaces.

## 2. `conxian-gateway`

### Decision

`conxian-gateway` is the canonical integration and adapter layer.

### Owns

- Bitcoin mainnet adapter surfaces
- Lightning adapter surfaces
- Stacks adapter surfaces
- future Rootstock and Liquid adapter surfaces
- provider connectivity
- observation and broadcast service boundaries
- bridge and interoperability logic

### Does not own

- canonical shared-core ownership
- wallet UX
- portfolio-wide planning or taxonomy documents

### Consequence

Gateway-related logic in other repos should migrate here or be deprecated.

## 3. `conxius-enclave-sdk`

### Decision

`conxius-enclave-sdk` is the secure signer and device trust layer.

### Owns

- enclave-backed signing
- hardware and secure execution abstractions
- attestation or device trust support where needed
- policy-constrained signer behavior

### Does not own

- adapter logic
- application orchestration
- consumer workflow logic

### Consequence

All first-class layer support should be able to consume signer capabilities from this layer.

## 4. `conxius-platform`

### Decision

`conxius-platform` is the composition, runtime, and integration harness repo.

### Owns

- local ecosystem composition
- development and test harnesses
- observability and runtime wiring
- integration validation environments
- orchestrated developer workflows across strategic repos

### Does not own

- canonical business logic
- duplicated shared-core logic
- adapter implementations that belong in gateway
- strategic ownership of product identity

### Consequence

`conxius-platform` should compose the portfolio, not silently replace it.

## 5. `conxius-wallet`

### Decision

`conxius-wallet` is a reference client.

### Owns

- example user-facing flows
- signer UX validation
- capability demonstration for supported layers
- integration examples

### Does not own

- strategic portfolio center
- duplicated integration logic
- hidden shared-core behavior
- canonical adapter implementations

### Consequence

The wallet should validate the platform strategy, not define it.

## 6. `Conxian`

### Decision

`Conxian` must be treated as a protocol-first repo unless explicitly reclassified.

### Owns

- protocol identity
- canonical protocol specs and reference artifacts
- contracts and protocol-adjacent materials if that is its active purpose

### Does not own

- overlapping gateway runtime logic
- mixed product and adapter concerns that weaken protocol clarity

### Consequence

If `Conxian` is kept as protocol-first, gateway and application concerns should be removed from it over time.

## 7. `conxian-nexus`

### Decision

`conxian-nexus` remains a supporting repo pending role clarification.

### Temporary allowed role

- public API facade
- interoperability service layer
- external-facing service boundary distinct from raw gateway adapters

### Does not own

- duplicated adapter logic already handled by `conxian-gateway`
- generic overlap without a clear public purpose

### Consequence

A dedicated follow-up decision is required:

- keep and narrow
- merge into gateway
- or demote

## 8. `conxius-orbit`

### Decision

`conxius-orbit` is a supporting developer tooling repo.

### Owns

- deployment support
- contract deployment workflows
- builder tooling around deployment and environment setup

### Does not own

- general integration logic
- shared-core ownership
- portfolio orchestration identity

## Documentation placement decisions

### Decision

Portfolio-wide strategy, taxonomy, audit, and governance planning documents should live in intentional planning homes, primarily `conxian-business`.

### Keep in code repos

- developer-facing setup docs
- API and contract documentation
- usage examples
- architecture notes tied directly to implementation

### Move out of code repos over time

- portfolio taxonomy
- broad strategic narrative drafts
- repo governance alignment memos
- planning artifacts that are not required for code use or contribution

## Dependency direction

Target dependency direction:

- `conxius-wallet` -> `lib-conxian-core`, `conxian-gateway`, `conxius-enclave-sdk`
- `conxius-platform` -> consumes and composes strategic repos
- `conxian-gateway` -> depends on `lib-conxian-core`
- `conxian-nexus` -> only if distinct, should depend on gateway/core rather than duplicate them
- `lib-conxian-core` -> minimal upward dependencies
- `Conxian` -> depends on chosen protocol-first role; should not be a hidden integration owner

## First-class layer scope

### Phase 1

- Bitcoin mainnet
- Lightning
- Stacks

### Phase 2

- Rootstock
- Liquid

### Boundary implication

For phase 1 and phase 2 layers:

- shared interfaces live in `lib-conxian-core`
- adapters live in `conxian-gateway`
- secure signing lives in `conxius-enclave-sdk`
- integration harnesses live in `conxius-platform`
- reference interaction flows live in `conxius-wallet`

## Required follow-up actions

### Action 1

Update strategic repo READMEs to include:

- one-sentence ownership statement
- explicit non-goals

### Action 2

Run code-placement audits in:

- `lib-conxian-core`
- `conxian-gateway`
- `conxius-wallet`
- `Conxian`
- `conxius-platform`
- `conxian-nexus`

### Action 3

Open a decision record for the future role of `conxian-nexus`.

### Action 4

Update public narrative to reflect:

- builder platform
- native Bitcoin-layer support
- reference-client positioning for the wallet

## Summary

This record formalizes the portfolio around a builder-platform model.

The key outcome is clear separation:

- core defines interfaces and safety
- gateway owns adapters
- enclave SDK owns secure signing
- platform composes systems
- wallet demonstrates capabilities
- protocol repo stays protocol-first

These decisions should now be treated as the default boundary rules for follow-up work.