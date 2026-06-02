# ADR-004: Control plane consumes runtime services instead of re-implementing them

## Status
Accepted

## Context
There is a risk that the internal control plane becomes a catch-all for runtime behavior, external integrations, or user-facing logic.

## Decision
The control plane should consume trusted runtime services, primarily through `conxian-nexus` and adjacent service repos, rather than embedding runtime execution logic directly in `conxian-business`.

## Consequences
- Runtime and control concerns remain separated.
- The control-plane app can move faster without absorbing operational complexity.
- Service contracts become more important and must be documented clearly.
