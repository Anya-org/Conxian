# Merge Readiness for PR #716

## Current status

PR #716 is mergeable and currently in a clean merge state.

## What the PR now contains

- target architecture and repo evolution docs
- 12-month roadmap
- ADR set
- auth and authorization notes
- versioned admin API v1 notes
- Nexus admin service boundary note
- control-plane app scaffold
- shared package skeletons
- typed workflow request/response contracts
- bootstrap workflow action forms for release governance and policy approvals

## Remaining follow-up after merge

- replace synthetic actor handling with real authentication
- implement runtime-backed admin clients
- add validation and tests
- continue module implementation in smaller follow-up slices

## Review focus

Reviewers should focus on:
- repo boundary correctness
- package boundary correctness
- auth and authorization model consistency
- whether the control plane remains separate from runtime execution
