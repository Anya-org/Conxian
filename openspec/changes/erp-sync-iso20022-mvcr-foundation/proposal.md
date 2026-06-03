# Proposal: ERP sync + ISO 20022 mapping + MVCR artifact foundation (Milestone 1)

## Context
Sovereign adoption requires deterministic ERP synchronization behavior, clear ISO 20022 field mapping, and auditable compliance artifacts.

This change initializes that foundation in `Conxian/conxian-business` for follow-on integration work tracked from `Conxian/conxius-platform#635`.

## Scope (Milestone 1)

1. Define a first-pass ERP settlement event contract and deterministic identity primitives.
2. Establish ISO 20022 canonical mapping metadata needed by trigger extraction and compliance lineage.
3. Introduce MVCR artifact generation with both:
   - machine-readable output (`JSON`), and
   - human-readable output (`Markdown`).
4. Integrate generation into an existing executable flow (`conxian-business/transparency_custodian.py`) behind an optional settlement input.
5. Add tests for deterministic identity and MVCR generation success/failure behavior.

## Non-goals

- Full ERP transport adapters (SOAP/WSDL/OData) in this milestone.
- Full end-to-end gateway + nexus production wiring.
- Jurisdiction-specific compliance policy engines.

## Acceptance criteria

1. Trigger identity is deterministic for semantically equivalent settlement payloads.
2. ERP idempotency key generation is deterministic from ERP system + direction + trigger identity.
3. MVCR artifacts include explicit lineage to settlement trigger and ERP sync idempotency identity.
4. MVCR generator can emit JSON and Markdown artifacts.
5. Tests cover at least one successful MVCR generation path and at least one failure/edge-case path.
