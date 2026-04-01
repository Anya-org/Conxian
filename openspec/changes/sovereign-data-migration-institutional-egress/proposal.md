# Proposal: Sovereign Data Migration & Institutional Egress Architecture (CON-343)

## Context
The SAB datastore mapping work established the current target-state direction for canonical truth (Stacks L1) and derived query layers (PostgreSQL, analytics, and optional public mirrors). As Phase 5 approaches, two dependencies remain strategically misaligned with sovereignty and verifiability where they materially matter:

- **Supabase** for proof-carrying analytics and visual-proof workflows.
- **Neon** for PostgreSQL persistence underlying the Nexus read model.

Separately, treasury and gateway work has begun to formalize institutional accounting outputs (settlement logs, ISO 20022 outputs). This proposal frames that work as a standardized **read-only subledger egress** surface, not "custom ERP plugin" work.

## Goals
1. **Phase 5 clean break**: eliminate Supabase and Neon from correctness-critical paths.
2. **Verifiable analytics direction**: align proof/visual-proof flows to a verifiable analytics layer (e.g., Space and Time) without introducing a new source of truth.
3. **Institutional egress standard**: position `conxian-nexus` as a read-only, cryptographically verifiable **Glass Node** for external subledgers, with `conxian-gateway` as the institutional API surface.
4. **No duplicate execution lane**: sharpen and align existing SAB migration and treasury/oracle issues instead of creating parallel work.

## Non-goals
- Defining bespoke integrations for any single ERP vendor.
- Introducing any off-chain system as a canonical system of record.
- Moving secrets, keys, or PII into any analytics or egress dataset.

## Proposed Changes
- Add a focused OpenSpec package that:
  - defines the Phase 5 "clean break" constraints for Supabase and Neon.
  - defines "institutional egress" as standardized, read-only subledger export.
  - defines decision gates and compatibility checks that map directly to existing work items.

## Impact
- Existing SAB migration issues become more concrete about:
  - what changes are required for Supabase/Neon phase-out,
  - how cutover will be decided,
  - and what "institutional egress" means in terms of datasets, proofs, and API surfaces.
