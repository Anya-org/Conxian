# Wallet Overlap Reduction Plan

## Purpose

This document defines the cleanup plan for issue #648: reducing embedded lower-layer overlap inside `conxius-wallet` so the repo can operate as a reference client rather than a hidden integration monorepo.

## Why this cleanup is needed

Direct inspection confirms that `conxius-wallet` includes:

- embedded references to `conxian-gateway`
- embedded references to `lib-conxian-core`
- `.gitmodules`
- explicit submodule documentation
- architecture and operations documents that suggest broader scope than a narrow reference client

This conflicts with the approved portfolio role where `conxius-wallet` is a reference client.

## Reference-client definition

`conxius-wallet` should own:

- reference interaction flows
- signer UX validation
- demonstration of supported layer capabilities
- example client behavior

`conxius-wallet` should not own:

- canonical adapter implementations
- embedded strategic infrastructure repos
- hidden shared-core ownership
- broad operational or infrastructure authority beyond what is needed to run the reference client

## Confirmed overlap signals

### Embedded repo references

Observed signals include:

- `.gitmodules`
- submodule documentation in `openspec/specs/submodules.md`
- visible embedded references to `conxian-gateway`
- visible embedded references to `lib-conxian-core`

### Broader-than-reference documentation

Observed signals include:

- `docs/architecture/GCP_INFRASTRUCTURE.md`
- `docs/operations/SYSTEM_ALIGNMENT_ENHANCEMENT_PLAN.md`
- `docs/operations/VERIFICATION_PATHWAY.md`

These may be useful, but they suggest the repo is carrying infrastructure or system-alignment weight that should be reviewed carefully.

## Cleanup goal

After cleanup:

- the wallet consumes lower-layer capabilities through cleaner boundaries
- embedded strategic repos are reduced or removed
- wallet docs are narrowed to reference-client concerns
- strategic infrastructure ownership is visibly elsewhere

## Placement decisions

## Reduce or remove from `conxius-wallet`

### Embedded strategic repo content

Reduce or remove:

- embedded `conxian-gateway` material
- embedded `lib-conxian-core` material
- submodule arrangements that make the wallet a hidden integration workspace

### Over-broad operations or architecture ownership

Review and narrow:

- infrastructure docs that are broader than the wallet’s reference-client role
- system-alignment and operations docs that should live in:
  - `conxian-business`
  - `conxius-platform`
  - or the relevant strategic repo

## Keep in `conxius-wallet`

- user-facing reference flows
- signer and device interaction examples
- wallet-specific UX
- example capability integrations
- only the minimum architecture/docs needed to build, run, and understand the reference client

## Reduction sequence

### Phase 1 — submodule and embedded dependency inventory

- inventory all embedded references to `conxian-gateway` and `lib-conxian-core`
- classify each as:
  - required for current build
  - candidate for package/API replacement
  - candidate for removal

### Phase 2 — dependency boundary redesign

For each embedded dependency, choose the cleaner target:

- package or crate dependency
- API/service consumption path
- shared interface imported from `lib-conxian-core`
- gateway capability consumed through `conxian-gateway`

### Phase 3 — documentation narrowing

Review wallet docs and move or narrow any documents that belong more naturally in:

- `conxius-platform`
- `conxian-business`
- `conxian-gateway`
- or `lib-conxian-core`

### Phase 4 — role reinforcement

Update wallet docs so contributors understand:

- this is the primary reference client
- lower-layer concerns live elsewhere
- examples should not become hidden sources of canonical logic

## Suggested PR breakdown

### PR 1

- inventory submodules and embedded references
- add migration note

### PR 2

- replace or isolate lower-layer embedded dependencies where low-risk

### PR 3

- move or narrow broader operations and architecture docs

### PR 4

- clean remaining references and reinforce reference-client framing

## Risk controls

- do not break current wallet build or demos while removing submodule usage
- prefer staged replacement over large one-shot removal
- preserve strong reference-client documentation while narrowing non-wallet ownership
- keep contributor experience clear during migration

## Definition of done

This cleanup is complete when:

- the wallet no longer embeds adjacent strategic repos as hidden ownership centers
- lower-layer consumption paths are explicit and cleaner
- wallet docs match a reference-client role
- infrastructure and integration authority is clearly located elsewhere

## Summary

The cleanup rule is simple:

- if it is wallet UX or reference-client behavior, keep it in `conxius-wallet`
- if it is shared core, canonical gateway, or broad platform ownership, move it out or reduce the overlap

This will make the wallet visibly and sustainably a reference client rather than a blended monorepo surface.