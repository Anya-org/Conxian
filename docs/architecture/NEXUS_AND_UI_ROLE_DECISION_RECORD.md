# Nexus and UI Role Decision Record

## Status

Approved working decision

## Purpose

This decision record resolves the remaining portfolio ambiguity around:

- `conxian-nexus`
- `conxian_ui`

These repos need explicit roles so the builder-platform strategy can be applied consistently across the full portfolio.

## Strategy basis

Conxian is aligning around:

- builder enablement
- native Bitcoin mainnet and Bitcoin-connected layer support
- shared capability infrastructure
- secure signing and trust abstractions
- reference clients and supporting surfaces rather than consumer-service primacy

Repos that do not fit that center of gravity need explicit supporting or reference roles.

## 1. `conxian-nexus`

## Current signal

The current public framing is generic: an API bridge.

That is not strong enough as a portfolio role because it can overlap too easily with `conxian-gateway`.

## Decision

`conxian-nexus` is treated as a **supporting repo** whose role is an external API facade or interoperability service above the canonical adapter layer.

## `conxian-nexus` owns

- external-facing API facade behavior when distinct from raw adapter logic
- interoperability service boundaries that package lower-level gateway capabilities
- developer-facing or partner-facing API composition when it is intentionally higher-level than direct gateway adapters

## `conxian-nexus` does not own

- canonical network adapters
- provider-specific integration logic that belongs in `conxian-gateway`
- shared-core ownership
- protocol identity
- reference-client UI behavior

## Boundary rule

If the concern is about direct Bitcoin, Lightning, Stacks, Rootstock, or Liquid adapter behavior, it belongs in `conxian-gateway`.

If the concern is about a higher-level API or interoperability surface that packages those capabilities for external consumers, it may belong in `conxian-nexus`.

## Consequence

`conxian-nexus` should be kept only if it remains clearly above and distinct from the gateway layer.

If it becomes a second adapter repo, it should be narrowed or merged.

## Recommended follow-up

- add a repo ownership document to `conxian-nexus`
- update its README to explicitly state its facade/interoperability role
- audit for duplicated adapter logic relative to `conxian-gateway`

## 2. `conxian_ui`

## Current signal

The current public framing suggests a UI surface or product-facing interface layer.

That makes it potentially useful, but not part of the strategic center of gravity for the builder-platform model.

## Decision

`conxian_ui` is treated as a **reference or supporting UI surface**, not a primary strategic repo.

## `conxian_ui` owns

- shared interface experiments or assets if intentionally reused
- supporting UI work that demonstrates capabilities
- optional visual or interaction surfaces that support the ecosystem

## `conxian_ui` does not own

- strategic portfolio identity
- canonical integration logic
- shared-core ownership
- protocol identity
- the primary reference-client role if `conxius-wallet` remains the main reference client

## Boundary rule

If the repo is kept, it should have a narrow and explicit purpose:

- shared UI layer
- prototype surface
- support interface for ecosystem tooling

It should not become a shadow product center or overlap heavily with `conxius-wallet` or `conxian-labs-site`.

## Consequence

`conxian_ui` should be retained only if its purpose can be clearly stated in a way that does not overlap substantially with:

- `conxius-wallet`
- `conxian-labs-site`

If overlap remains high, it should be narrowed, merged, archived, or demoted further.

## CON-702 checkpoint resolution (`conxian_ui` parent control alignment)

Issue link: [CON-702 — Align Conxian_UI to parent control model](https://linear.app/conxian-labs/issue/CON-702/align-conxian-ui-to-parent-control-model)

This checkpoint resolves the role contradiction and sets an implementation baseline:

- `Conxian_UI` is confirmed as a supporting/reference UI surface, not a flagship or primary control plane.
- Parent control authority remains in private control/governance sources and core runtime systems.
- `Conxian_UI` is constrained to consume approved/public outputs.
- `Conxian_UI` must not own secrets, signing keys, or privileged transaction/broadcast authority.

See `docs/architecture/CONXIAN_UI_PARENT_CONTROL_ALIGNMENT_PLAN.md` for the control ownership map, execution checklist, and evidence placeholders.

## Portfolio classification update

### Primary strategic repos

- `lib-conxian-core`
- `conxian-gateway`
- `conxius-enclave-sdk`
- `conxius-platform`

### Supporting repos

- `conxian-nexus`
- `conxius-orbit`
- `conxian-labs-site`
- `conxian_ui` as a supporting/reference UI surface with a consumer-only boundary

### Reference repos

- `conxius-wallet`

### Protocol-first repo

- `Conxian`

### Internal coordination and governance

- `conxian-business`
- `.github-private`
- `.github`

## Follow-up actions

### Action 1

Add a repo ownership document to `conxian-nexus`.

### Action 2

Update `conxian-nexus` README to say it is an API facade or interoperability layer above gateway adapters.

### Action 3

Execute the CON-702 checkpoint for `conxian_ui`:

1. keep `Conxian_UI` explicitly classified as a supporting/reference surface
2. enforce the consumer-only boundary (approved/public outputs only)
3. document and evidence that `Conxian_UI` does not own secrets, signing keys, or privileged broadcast authority

### Action 4

Ensure public portfolio docs reflect:

- `conxian-nexus` as supporting, not primary
- `conxian_ui` as supporting or reference, not strategic center

## Summary

This decision removes the remaining ambiguity in the portfolio.

- `conxian-nexus` is allowed to exist as a higher-level API/interoperability facade, not as a second gateway
- `conxian_ui` is allowed to exist only as a narrow supporting or reference UI surface, not as a strategic center

These decisions should now be used when updating repo docs, public narrative, and future cleanup plans.