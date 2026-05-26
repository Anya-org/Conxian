# Phase 6 observability runbook (compatibility shim)

**Status:** Compatibility shim (non-canonical)
**Purpose:** Preserve existing links while directing operators to canonical CON-681 artifacts.

This file is intentionally brief. The canonical Phase 6 operations documentation now lives in:

1. [CON-681 Phase 6 production rollout runbook](./operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md)
2. [CON-681 Phase 6 rollback drill simulation](./operations/CON-681_PHASE6_ROLLBACK_DRILL_SIMULATION.md)

## Summary (for link continuity)

- Rollout progression is gate-based: `Preflight` -> `Shadow/Internal` -> `Controlled cohort` -> `Broad enablement`.
- Required observability coverage includes request rate, error rate, p95 latency, and contract-violation counters per interface.
- Rollback is trigger-driven with deterministic operator actions and communication templates.

For sensitive operational details (restricted identifiers, privileged command payloads, environment-specific routing), use the internal CON-681 Linear records under ZSE policy.
