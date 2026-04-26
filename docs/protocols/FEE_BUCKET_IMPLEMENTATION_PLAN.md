# Fee-bucket implementation plan (CON-481)

This document is intentionally limited to a public-safe summary.

Detailed fee vectors, gate-state snapshots, and implementation runbook procedures are maintained in private governance and operations records.

## Public-safe scope

The Conxian fee-bucket model follows these high-level controls:

1. **Versioned bucket policies**
   - Fee-routing behavior is versioned and change-controlled.
   - Policy updates require documented governance authority.

2. **Deterministic execution principles**
   - Routing logic must be deterministic and auditable.
   - Runtime execution must fail closed when required controls are missing.

3. **Governance boundary**
   - Operational execution and policy authority are explicitly separated.
   - Control transitions follow staged governance evidence and approvals.

4. **Public/private documentation boundary**
   - Public docs provide policy intent and guardrails.
   - Sensitive economic schedules and operational implementation details remain private.

## Notes

- This file remains in place to preserve existing links.
- Use `docs/protocols/ECONOMIC_RIGHTS_MAP.md` for the public-safe policy context.
- Request private governance artifacts only through authorized channels.
