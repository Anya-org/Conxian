# High-Risk Code Placement Findings — Wave 1

## Purpose

This document records the first high-confidence code-placement findings from direct repo inspection. It focuses on the highest-risk overlap where cleanup will have the biggest architectural effect.

## Scope

Wave 1 focuses on:

- `lib-conxian-core`
- `Conxian`
- `conxius-wallet`

These were chosen because they showed the clearest direct overlap with the approved boundary model.

## Summary

Three high-risk overlaps are confirmed:

1. `lib-conxian-core` contains a substantial `gateway/` subtree
2. `Conxian` contains a separate `gateway/` application subtree
3. `conxius-wallet` contains embedded references to both `conxian-gateway` and `lib-conxian-core`

This is enough evidence to treat gateway duplication and embedding as an active architectural problem rather than a theoretical one.

## Finding 1 — `lib-conxian-core` contains a full gateway subtree

### Evidence observed

Direct repository evidence shows the following gateway-specific content in `lib-conxian-core`:

- `gateway/Cargo.toml`
- `gateway/Cargo.lock`
- `gateway/src/main.rs`
- `gateway/src/lib.rs`
- `gateway/src/mcp_server.rs`
- `gateway/src/api/...`
- `gateway/src/engine/...`
- `gateway/infrastructure/gcp/deployment.yaml`

### Why this is high risk

The approved boundary model says:

- `lib-conxian-core` owns shared interfaces and safety primitives
- `conxian-gateway` owns canonical adapters and integration runtime concerns

A full gateway subtree inside core creates:

- duplicated integration ownership
- contributor confusion
- increased risk that core becomes the hidden runtime center
- harder extraction of stable interfaces from implementation details

### Placement judgment

- **status**: high-risk overlap
- **recommended action**: move or split

### Proposed handling

- move runtime and adapter implementation out of `lib-conxian-core`
- preserve only:
  - shared capability interfaces
  - shared types
  - safety and verification primitives
  - abstractions truly required by more than one adapter

## Finding 2 — `Conxian` contains a separate gateway application subtree

### Evidence observed

Direct repository evidence shows the following gateway-specific content in `Conxian`:

- `gateway/README.md`
- `gateway/package.json`
- `gateway/tsconfig.json`
- `gateway/vitest.config.ts`
- `gateway/src/app.ts`
- `gateway/src/index.ts`
- `gateway/src/handlers/x402.ts`
- `gateway/src/handlers/settlement.ts`
- `gateway/src/handlers/erp.ts`
- `gateway/src/parsers/iso20022.ts`
- `gateway/src/middleware/auth.ts`
- `gateway/src/types/settlement.ts`
- `gateway/tests/gateway.test.ts`

### Why this is high risk

The approved role for `Conxian` is protocol-first unless explicitly reclassified.

A distinct gateway application subtree inside the protocol repo creates:

- protocol versus integration ambiguity
- pressure for the protocol repo to become a mixed systems repo
- duplication with `conxian-gateway`
- public confusion about which repo is the real integration surface

### Placement judgment

- **status**: high-risk overlap
- **recommended action**: move or narrow

### Proposed handling

Pick one of these explicitly:

1. if `Conxian` remains protocol-first:
- move gateway runtime logic out
- keep only protocol-relevant artifacts and references

2. if `Conxian` is reclassified in the future:
- document that change clearly before keeping mixed concerns

Current recommendation:
- keep `Conxian` protocol-first and move the gateway app concern out over time

## Finding 3 — `conxius-wallet` carries embedded gateway and core references

### Evidence observed

Direct repository evidence shows the following in `conxius-wallet`:

- embedded `conxian-gateway/README.md`
- a visible `lib-conxian-core` reference at repo root
- `.gitmodules` present
- documentation referencing submodules

The repo structure also shows signs of wide scope and operational overlap, including substantial documentation and environment material beyond a narrow reference-client role.

### Why this is high risk

The approved boundary model treats `conxius-wallet` as a reference client.

Embedded references to gateway and core material increase the risk that the wallet becomes:

- a hidden integration monorepo
- a source of canonical logic by accident
- harder to narrow to a demonstrator/reference role

### Placement judgment

- **status**: high-risk overlap
- **recommended action**: demote and separate

### Proposed handling

- remove embedded adjacent modules over time
- consume `conxian-gateway` and `lib-conxian-core` through cleaner dependency boundaries
- keep wallet-specific UX, signer interaction, and capability demonstration logic only

## Architectural interpretation

These findings reinforce the same conclusion:

- gateway concerns are currently spread across multiple repos
- core still contains runtime-level integration content
- wallet still contains embedded lower-layer dependencies

The highest-value cleanup sequence remains:

1. isolate gateway implementation from `lib-conxian-core`
2. decide and enforce the protocol-first role of `Conxian`
3. strip embedded adjacent concerns out of `conxius-wallet`

## Suggested cleanup sequence

### Step 1

Open repo-specific cleanup tasks:

- `lib-conxian-core`: gateway subtree extraction plan
- `Conxian`: protocol-repo narrowing plan
- `conxius-wallet`: submodule and embedded dependency reduction plan

### Step 2

Document target landing zones:

- canonical gateway code -> `conxian-gateway`
- shared abstractions -> `lib-conxian-core`
- protocol artifacts -> `Conxian`
- reference UX only -> `conxius-wallet`

### Step 3

Prevent recontamination:

- add ownership statements to affected repo READMEs if not already done
- use PR review comments against boundary drift
- reference the boundary decision record in cleanup work

## Follow-up waves

Wave 2 should inspect:

- `conxius-platform`
- `conxian-nexus`
- `conxian_ui`

Wave 3 should inspect supporting repos for documentation-placement consistency.

## Summary

Wave 1 confirms the most important code-placement problem in the portfolio:

- gateway logic exists in more than one strategic repo
- core still contains gateway runtime structure
- wallet still embeds adjacent strategic repos

These are the best next cleanup targets because they directly affect architecture clarity, contributor understanding, and future implementation velocity.