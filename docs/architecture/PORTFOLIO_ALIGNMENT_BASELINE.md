# Portfolio Alignment Baseline

## Purpose

This document aligns the strongest existing Conxian portfolio work with the newer builder-platform and Bitcoin-layer support strategy.

It is intentionally preservative rather than revisionist.

The goal is to:

- read existing work first
- preserve the strongest material already written
- reduce duplication between strategy, market, portfolio, and repo-boundary documents
- make future changes additive and convergent rather than destructive

## Read-first principle

Before changing portfolio strategy, repo roles, architecture notes, or public narrative:

1. read the relevant existing docs first
2. identify the strongest reusable material
3. preserve language, structure, or insights that remain correct
4. only replace material that is clearly conflicting, obsolete, or lower quality

This should be treated as a working documentation policy for all future portfolio-alignment work.

## Current strong documents to preserve

### Portfolio and repo mapping

These remain strong and should be treated as source material, not bypassed:

- `docs/REPO_PORTFOLIO.md`
- `docs/REPOSITORY_CATALOG.md`
- `docs/PORTFOLIO_REPOSITORY_INVENTORY.md`
- `docs/PORTFOLIO_BUSINESS_UNIT_MAP.md`

### Market and narrative work

This remains useful and should be preserved where consistent with the builder-platform thesis:

- `docs/CONXIAN_MARKET_NARRATIVE_ONE_PAGER.md`

### New strategy and boundary work

These now provide the clearest current direction and should be treated as the active architectural baseline:

- `docs/research/BITCOIN_LAYER_CAPABILITY_MATRIX.md`
- `docs/research/BITCOIN_LAYER_REPO_ALIGNMENT_PLAN.md`
- `docs/research/REPO_BOUNDARY_OVERLAP_AUDIT.md`
- `docs/architecture/REPO_BOUNDARY_DECISION_RECORD.md`

## Current alignment summary

The strongest coherent direction across the docs is:

- Conxian should be positioned as a builder platform
- Conxian should help others support Bitcoin mainnet and Bitcoin-connected layers natively
- Conxian should own capability interfaces, secure signing, integration quality, and developer experience
- Conxian should avoid drifting into a direct full-service financial operator identity
- Conxian should preserve reference clients and public narrative work, but not let those become the strategic center

## What should now be considered settled

### 1. Portfolio center

The portfolio center is infrastructure for builders, not direct financial-service construction.

### 2. Phase 1 technical focus

First-class support focus:

- Bitcoin mainnet
- Lightning
- Stacks

### 3. Repo center of gravity

Primary strategic repos:

- `lib-conxian-core`
- `conxian-gateway`
- `conxius-enclave-sdk`
- `conxius-platform`

Reference repo:

- `conxius-wallet`

Protocol-first repo unless reclassified:

- `Conxian`

### 4. Documentation policy

Do not replace older portfolio and market docs when they can be integrated.

Prefer:

- cross-reference
- narrow updates
- decision records
- addenda

Over:

- large destructive rewrites
- parallel competing narratives
- undocumented shifts in repo role

## What should still be clarified

### `conxian-nexus`

Its role still needs a dedicated narrowing decision.

### `conxian_ui`

Its future place in the portfolio remains unclear and should be reviewed against the builder-platform thesis.

### Public narrative wiring

The public-facing narrative across public repos and the site should be updated gradually to reflect the builder-platform identity while preserving the strongest prior messaging.

## Working document hierarchy

To reduce confusion, the following hierarchy should apply.

### Level 1: decision and boundary authority

- `docs/architecture/REPO_BOUNDARY_DECISION_RECORD.md`
- future architecture decision records in `docs/architecture/`

### Level 2: strategy and implementation framing

- `docs/research/BITCOIN_LAYER_CAPABILITY_MATRIX.md`
- `docs/research/BITCOIN_LAYER_REPO_ALIGNMENT_PLAN.md`
- `docs/research/REPO_BOUNDARY_OVERLAP_AUDIT.md`

### Level 3: portfolio and narrative source material

- `docs/REPO_PORTFOLIO.md`
- `docs/REPOSITORY_CATALOG.md`
- `docs/PORTFOLIO_REPOSITORY_INVENTORY.md`
- `docs/PORTFOLIO_BUSINESS_UNIT_MAP.md`
- `docs/CONXIAN_MARKET_NARRATIVE_ONE_PAGER.md`

The intention is not to devalue Level 3 documents. It is to make clear how they should be interpreted after the new boundary decisions.

## Documentation change rules

When editing portfolio-related docs going forward:

- read the nearest higher-authority doc first
- preserve valid existing analysis where possible
- avoid creating duplicate role definitions across multiple docs
- add explicit links between old and new strategy documents
- prefer small clarifying edits over large rewrites when the older work is still useful

## Recommended next steps

1. use this baseline when updating repo READMEs and ownership docs
2. add references from older portfolio docs to the newer decision records
3. create a focused decision for `conxian-nexus`
4. review `conxian_ui` against the builder-platform thesis
5. update public messaging incrementally rather than replacing all prior narrative at once

## Summary

Conxian already has a lot of strong work in place.

The right approach is not to discard it.

The right approach is to:

- read first
- preserve the best parts
- align them under a clear builder-platform architecture
- make future work converge on one coherent portfolio direction