# Conxian Protocol-First Narrowing Plan

## Purpose

This document defines the narrowing plan for issue #647: restoring `Conxian` to a protocol-first role by removing or relocating gateway runtime overlap.

## Why narrowing is needed

Direct repo inspection confirmed that `Conxian` contains a gateway application subtree with runtime and service concerns, including:

- `gateway/README.md`
- `gateway/src/app.ts`
- `gateway/src/index.ts`
- `gateway/src/handlers/settlement.ts`
- `gateway/src/handlers/x402.ts`
- `gateway/src/handlers/erp.ts`
- `gateway/src/parsers/iso20022.ts`
- `gateway/src/middleware/auth.ts`
- `gateway/src/types/settlement.ts`
- `gateway/tests/gateway.test.ts`
- package/runtime files under `gateway/`

This conflicts with the approved portfolio model where `Conxian` is treated as protocol-first unless explicitly reclassified.

## Narrowing goal

After cleanup:

- `Conxian` should be recognized as the protocol-first repository
- runtime integration and gateway application concerns should live outside it
- protocol artifacts, contracts, and canonical protocol references should remain

## Protocol-first definition

`Conxian` should own:

- protocol identity
- canonical protocol specs and reference artifacts
- contracts and protocol-adjacent implementation where appropriate
- protocol-facing documentation that explains the system at the protocol layer

`Conxian` should not own:

- gateway runtime application logic
- service middleware
- integration handlers
- API application surfaces
- duplicate adapter implementation that belongs in `conxian-gateway`

## Confirmed gateway overlap

### Runtime entrypoints

- `gateway/src/app.ts`
- `gateway/src/index.ts`

### Application logic and handlers

- `gateway/src/handlers/settlement.ts`
- `gateway/src/handlers/x402.ts`
- `gateway/src/handlers/erp.ts`

### Service concerns

- `gateway/src/middleware/auth.ts`
- `gateway/src/parsers/iso20022.ts`
- `gateway/src/types/settlement.ts`

### Supporting runtime/package files

- runtime package and test configuration under `gateway/`
- gateway tests under `gateway/tests/`

## Placement decisions

## Move out of `Conxian`

These should be treated as gateway or integration service concerns and relocated over time:

- gateway runtime entrypoints
- handler and middleware logic
- service parsers and runtime types tied to integration behavior
- gateway package/runtime configuration
- gateway tests for service behavior

### Likely landing zone

- canonical landing zone: `conxian-gateway`

## Keep in `Conxian`

Keep protocol-first material such as:

- contracts
- canonical protocol docs and specs
- protocol reference artifacts
- protocol-facing changelog and release framing where relevant

## Move-vs-reference rule

If a file is primarily about:

- request handling
- service middleware
- external integration parsing
- runtime startup
- service deployment behavior

it should not stay in the protocol-first repo.

If a file is primarily about:

- protocol rules
- contracts
- protocol interfaces or invariants
- canonical system identity at the protocol layer

it may remain.

## Narrowing sequence

### Phase 1 — classify all `gateway/` contents

Label each item as:

- move
- keep
- split
- deprecate

### Phase 2 — move obvious runtime concerns

Move first:

- `gateway/src/app.ts`
- `gateway/src/index.ts`
- middleware
- handlers
- parsers
- service tests

### Phase 3 — preserve protocol references

Retain or rewrite protocol-relevant references so `Conxian` still explains:

- what the protocol is
- how it relates to the broader ecosystem
- where integration runtime now lives

### Phase 4 — clean docs and public framing

Update `Conxian` docs so contributors understand:

- this is the protocol-first repo
- integration runtime belongs elsewhere

## Suggested PR breakdown

### PR 1

- classify `gateway/` subtree and add migration note

### PR 2

- move runtime entrypoints and handler/service logic

### PR 3

- move tests and remaining runtime configuration

### PR 4

- clean protocol-facing docs and references

## Risk controls

- avoid breaking protocol docs while runtime concerns are moved
- keep clear references to the new integration home
- do not leave duplicate gateway behavior in both repos after migration
- preserve public understanding of the protocol repo’s purpose

## Definition of done

This narrowing is complete when:

- `Conxian` no longer presents as a mixed protocol-and-gateway repo
- gateway runtime logic has been relocated or removed
- protocol-facing material remains clear and intact
- contributor-facing docs explain the separation cleanly

## Summary

The narrowing rule is simple:

- if it is protocol identity or canonical protocol material, keep it in `Conxian`
- if it is gateway runtime or service behavior, move it out

This will make `Conxian` visibly and credibly protocol-first again.