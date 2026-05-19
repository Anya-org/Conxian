# Code Placement Audit Pack

## Purpose

This document turns the approved boundary decisions into a practical audit and cleanup guide for code placement across the portfolio.

It is intended to support repo-by-repo cleanup without losing strong existing work.

## Audit objective

For every strategic or supporting repo, determine:

- what code clearly belongs there
- what code should move elsewhere
- what code should be split behind interfaces
- what code should be deprecated or demoted
- what documentation belongs in-repo versus in planning docs

## Audit sequence

### 1. `lib-conxian-core`

Check for:
- provider-specific logic
- network adapter logic
- runtime concerns
- gateway-like modules or directories

Allowed to remain:
- shared capability interfaces
- shared safety and verification primitives
- signer policy abstractions
- shared data models

### 2. `conxian-gateway`

Check for:
- adapter surfaces for Bitcoin mainnet, Lightning, Stacks, and future layers
- provider connectivity
- observation and broadcast logic

Remove or avoid:
- wallet UX logic
- duplicated shared-core definitions
- protocol-spec ownership

### 3. `conxius-enclave-sdk`

Check for:
- secure signing abstractions
- device trust integrations
- policy-constrained signer behavior

Remove or avoid:
- gateway adapter logic
- general application workflow logic

### 4. `conxius-platform`

Check for:
- composition and orchestration code
- test harnesses and runtime wiring
- observability and integration tooling

Move out if found:
- canonical business logic
- duplicate adapter logic
- hidden shared-core behavior

### 5. `conxius-wallet`

Check for:
- demonstration and reference-client flows
- integration examples
- signer UX validation

Move out if found:
- canonical integration logic
- hidden gateway behavior
- shared logic that should live lower in the stack

### 6. `Conxian`

Check for:
- protocol specs and reference artifacts
- contracts and protocol identity material

Move out if found:
- gateway runtime logic
- mixed adapter concerns
- consumer or reference-client responsibilities

### 7. `conxian-nexus`

Check for:
- higher-level API facade behavior
- interoperability packaging above gateway adapters

Move out if found:
- raw adapter logic that belongs in `conxian-gateway`
- duplicate provider integration behavior

### 8. `conxian_ui`

Check for:
- narrow supporting UI or reference UI concerns

Move out or narrow if found:
- overlapping ownership with `conxius-wallet`
- strategic center-of-gravity behavior

## Placement decision categories

Use one of these labels for each audited finding:

- **keep**: correctly placed
- **move**: belongs in another repo
- **split**: should be separated into interface and implementation
- **demote**: should remain but only as example or reference material
- **archive**: low-value overlap or no longer needed

## Documentation placement guide

### Keep in code repos

- setup instructions
- API and contract docs
- implementation-facing architecture notes
- examples required to use the code

### Move to planning docs

- broad portfolio strategy
- repo taxonomy across the org
- market positioning memos
- internal planning and audit narratives not needed to build or contribute

## Cleanup order

### Wave 1

- `lib-conxian-core`
- `conxian-gateway`
- `conxius-wallet`
- `Conxian`

### Wave 2

- `conxius-platform`
- `conxian-nexus`
- `conxian_ui`

### Wave 3

- supporting and narrative repos for consistency cleanup

## Definition of complete cleanup

A repo is considered aligned when:

- its README and ownership doc match reality
- its code placement follows the boundary decision record
- major cross-repo overlap has been removed or documented
- examples are clearly examples, not hidden sources of canonical logic

## Summary

This pack should be used as the audit lens for the next implementation phase: aligning code placement with the approved builder-platform architecture.