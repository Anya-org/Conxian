# ADR: Conxian L3 profile on Stacks (CON-441)

- **Status:** Accepted
- **Date:** 2026-04-25
- **Decision owners:** BOS architecture + protocol/gateway maintainers
- **Related docs:**
  - `docs/architecture/BITVM2_SBTC_BRIDGE_TARGET_ARCHITECTURE.md`
  - `docs/SAB_MIGRATION_WAVES.md`
  - `docs/COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md`

## Context

Conxian needs an explicit L3 operating profile that can ship incrementally without conflating:

1. application/business control-plane signing,
2. Stacks Nakamoto consensus signing/finality, and
3. sBTC peg custody signing.

Previous references described these boundaries implicitly, which made rollout and rollback decisions hard to audit.

## Decision

Conxian will operate as a **Stacks-anchored L3 profile** with a compatibility-first migration path and strict signer-boundary separation.

### 1) Settlement model (adopted)

1. **Execution lane:** Conxian services (Gateway/Nexus/Wallet/UI) produce intents and state transitions in Conxian-defined interfaces.
2. **Settlement lane:** authoritative economic settlement is finalized on Stacks contracts and, where required by bridge flow, anchored to Bitcoin through sBTC/BitVM2 flows.
3. **Evidence lane:** every settlement-relevant derived state must be reproducible from chain events/checkpoints; off-chain stores remain derived and non-authoritative.

Normative rule: no Conxian off-chain service may be treated as the final settlement authority.

### 2) Signer boundary (explicitly separated)

| Boundary | Role | Controlled by | In scope for Conxian repos | Not allowed |
| --- | --- | --- | --- | --- |
| **Nakamoto signers** | Stacks consensus/finality path | Stacks protocol signer set | Consume finality signals and heights as external truth inputs | Replacing or emulating Nakamoto finality with app-level signatures |
| **sBTC signers** | Peg-in / peg-out custody path | sBTC signer federation/protocol controls | Integrate with published bridge state/events and enforce policy around when bridge state is accepted | Treating Conxian BOS signers as sBTC custody authority |
| **Conxian BOS signers** | Application/ops approvals (policy, treasury, emergency controls) | SAB/DAO governance model | Authorize Conxian-owned control-plane actions and contract calls | Claiming consensus finality authority or bridge custody authority |

Normative rule: a valid Conxian BOS signature cannot stand in for Nakamoto or sBTC signer decisions.

### 3) Migration principle (compatibility-first dual lane)

Conxian adopts a **dual-lane migration** until promotion gates are met:

- **Lane A (Compatibility lane):** existing production-safe behavior remains active and is the default routing path.
- **Lane B (L3 target lane):** new L3-compatible flow runs in parallel with deterministic comparison and explicit rollback.

Required dual-lane behavior:

1. Same canonical request envelope enters both lanes.
2. Divergence is measured at deterministic checkpoints (state root, settlement receipt, policy decision).
3. Any unresolved divergence beyond threshold blocks promotion.

### 4) Promotion and rollback gates (must pass in order)

| Gate | Promotion requirement | Objective evidence | Rollback trigger |
| --- | --- | --- | --- |
| **G0 — Interface freeze** | Contract/API/event schema versions frozen for cutover window | Tagged schema inventory + compatibility matrix sign-off | Unversioned or breaking interface change |
| **G1 — Dual-lane determinism** | Lane A/B equivalence on agreed checkpoint set | 2+ controlled runs with zero unresolved high-severity mismatch | Any settlement-impacting mismatch |
| **G2 — Signer-boundary enforcement** | Boundaries enforced in code and policy checks | Tests/audit logs showing BOS cannot bypass Nakamoto/sBTC decisions | Any path where BOS signer can bypass boundary |
| **G3 — Operational readiness** | Runbooks/alerts/ownership complete for cutover | On-call map, alert drills, rollback rehearsal evidence | Missing owner, missing drill, or failed drill |
| **G4 — Controlled promotion** | Gradual traffic promotion within SLO/error budget | Promotion report with traffic percentages and rollback decision log | SLO breach or untriaged bridge/finality anomaly |

Rollback rule: if any rollback trigger occurs, route traffic to Lane A, freeze Lane B writes where required, and open an incident-linked remediation action before re-promotion.

## Consequences

### Positive

- Clear authority boundaries reduce custody/finality ambiguity.
- Promotion decisions become auditable and objective.
- Rollback can be executed without redesigning interfaces.

### Trade-offs

- Dual-lane operation adds temporary operational overhead.
- Promotion speed is constrained by evidence quality, not feature-completion claims.

## Implementation notes

1. Keep this ADR as the decision source for L3 boundary semantics.
2. Keep `docs/architecture/BITVM2_SBTC_BRIDGE_TARGET_ARCHITECTURE.md` as the target-state implementation architecture.
3. Use `docs/COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md` as the per-repo evidence and gate checklist.
