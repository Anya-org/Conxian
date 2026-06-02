# ADR-001: `conxian-business` is the BOS control plane

## Status
Accepted

## Context
`conxian-business` currently combines governance, specifications, orchestration, and repo coordination concerns. Productizing the ecosystem requires a stable home for internal operator workflows without collapsing all runtime and user-facing concerns into one repository.

## Decision
`conxian-business` is the private BOS control plane.

## Consequences
- Internal governance and operational workflows belong here.
- Public-facing product experiences should remain in dedicated application repos.
- Runtime execution concerns stay in trusted service repos.
