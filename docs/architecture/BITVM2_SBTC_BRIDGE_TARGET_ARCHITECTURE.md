# BitVM2 & sBTC bridge target architecture (CON-464)

This document defines the **target-state architecture** for Conxian’s BitVM2 + sBTC bridge integration under the L3 profile.

Related canonical docs:

- `docs/architecture/CONXIAN_L3_PROFILE_ADR.md` (decision and signer-boundary policy)
- `docs/SAB_MIGRATION_WAVES.md` (program sequencing)
- `docs/COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md` (cross-repo acceptance evidence)

ZSE note: this is a public-safe architecture spec. It intentionally excludes key material, signer identities, private endpoints, and custody procedures.

## 1) Scope and non-goals

### Goals

- Define concrete components and trust boundaries for bridge-integrated settlement.
- Specify proof generation and verification flow from Conxian state transition to Bitcoin-anchored evidence.
- Define failure handling and operational controls required for safe rollout.
- Provide phased checkpoints with explicit promotion/rollback criteria.

### Non-goals

- Replacing Stacks or sBTC protocol internals.
- Defining custody key ceremonies or signer rosters.
- Providing deployment-specific infrastructure addresses.

## 2) Target-state components

| Component | Responsibility | Interfaces |
| --- | --- | --- |
| **Conxian Gateway** | Ingress/egress policy enforcement, intent routing, bridge-state aware execution gating | Gateway APIs, policy hooks, signed-event envelope |
| **Conxian Nexus (Glass Node)** | Deterministic state projection, checkpoint assembly, bridge reconciliation index | Checkpoint feeds, state/event APIs |
| **Bridge Orchestrator** | Coordinates proof jobs, challenge windows, and settlement finalization state machine | Proof job queue, verifier status bus, rollback controls |
| **BitVM2 Prover Workers** | Generate claim/proof artifacts from canonical state commitments | Prover job spec, artifact storage (hash-addressed) |
| **BitVM2 Verifier/Watcher Set** | Independent verification and challenge observation; emits mismatch/timeout signals | Verification reports, challenge events |
| **sBTC Bridge Adapter** | Reads sBTC bridge state/events and normalizes them into Conxian settlement states | sBTC event ingestion, status mapping |
| **Policy/Control Plane (BOS)** | Enforces signer-boundary policy, approval gates, and emergency controls | Policy registry, runbook automation hooks |
| **Evidence Ledger (derived)** | Stores immutable references to proofs, decisions, txids, and checkpoint hashes | Audit query API, compliance export |

## 3) Trust boundaries

### 3.1 Boundary model

```text
Client/App -> Gateway -> Nexus/Bridge Orchestrator -> (Prover + Verifier + sBTC Adapter)
                                              |                    |
                                              +-> BOS policy ------+
                                                           |
                                                    Settlement acceptance
                                                           |
                                            Stacks + Bitcoin anchored evidence
```

### 3.2 Boundary rules (normative)

1. **Consensus/finality inputs are external truths**
   - Nakamoto finality and sBTC bridge state are consumed as authoritative external inputs.
2. **BOS policy is mandatory but not a finality substitute**
   - BOS approvals gate Conxian-controlled actions but cannot override chain/bridge finality.
3. **Derived stores are non-authoritative**
   - Evidence ledger and SQL projections aid observability/reconciliation only.
4. **Prover and verifier paths are separated**
   - A single service must not both author and unilaterally approve proof acceptance.

## 4) Proof and verification flow

### 4.1 End-to-end flow

1. Gateway accepts a settlement-relevant intent and assigns `intent_id`.
2. Nexus materializes the deterministic pre-state/post-state commitment pair.
3. Bridge Orchestrator creates a `proof_job` tied to checkpoint height + `intent_id`.
4. Prover Workers generate BitVM2 claim artifacts and publish artifact hashes.
5. Verifier/Watcher Set independently validates claim artifacts.
6. If verification passes and no challenge condition is active, orchestrator marks `PROOF_ACCEPTABLE`.
7. sBTC Bridge Adapter confirms bridge state requirements (for flows requiring sBTC custody path).
8. BOS policy checks signer-boundary, rate-limit, and risk controls.
9. Settlement state advances to `SETTLEMENT_CONFIRMED` only when steps 5–8 all pass.
10. Evidence ledger records: checkpoint hash, proof artifact hash, verifier result, bridge status, decision timestamp.

### 4.2 Verification invariants

- Proof acceptance requires at least one independent verifier path in addition to prover output.
- Any unresolved disagreement between verifier paths is a hard stop (`SETTLEMENT_BLOCKED`).
- Bridge state freshness must be within configured bounds for acceptance.
- Evidence ledger entry must be complete before final state is marked confirmed.

## 5) Failure modes and required behavior

| Failure mode | Detection signal | Required automated response | Manual follow-up |
| --- | --- | --- | --- |
| **Proof generation timeout** | `proof_job` exceeds SLA | Mark intent `PENDING_RETRY`; stop promotion of dependent batch | Capacity/root-cause review; retry with new job id |
| **Verifier mismatch** | Verifier results disagree | Mark `SETTLEMENT_BLOCKED`; disable affected lane | Incident review with artifact diff |
| **Challenge-window uncertainty** | Challenge status unresolved/stale | Hold settlement finalization (fail closed) | Confirm canonical chain state and watcher health |
| **sBTC bridge state stale** | Bridge adapter freshness breach | Reject bridge-dependent finalization | Recover indexer/feed and replay from last confirmed checkpoint |
| **Policy-control outage** | BOS policy lookup unavailable | Block settlement approvals (fail closed) | Restore policy service; verify no bypass occurred |
| **Evidence write failure** | Ledger append fails | Do not mark confirmed; keep transaction in recoverable pending state | Reconcile write path and replay append operation |
| **Rollback trigger activated** | Gate/SLO breach or explicit operator decision | Route traffic to compatibility lane; freeze target-lane writes if needed | Execute rollback runbook and produce post-incident report |

## 6) Operational controls

### 6.1 Control classes

1. **Separation of duties**
   - Prover execution, verifier approval, and policy override authority must be independent roles.
2. **Deterministic replayability**
   - All acceptance decisions must be reproducible from stored artifacts and chain data.
3. **Rate and blast-radius controls**
   - Promotion uses bounded traffic increments with automatic rollback thresholds.
4. **Freshness constraints**
   - Finalization requires fresh bridge/finality signals within defined SLO windows.
5. **Fail-closed defaults**
   - Missing verifier, stale bridge status, missing policy decision, or missing evidence append must block confirmation.

### 6.2 Minimum runtime telemetry

The following metrics are mandatory for go/no-go decisions:

- `proof_job_success_rate`
- `proof_generation_latency_p95`
- `verifier_mismatch_count`
- `bridge_state_freshness_seconds`
- `settlement_blocked_count`
- `rollback_trigger_count`

## 7) Phased rollout checkpoints

| Phase | Objective | Entry criteria | Exit criteria (objective evidence) |
| --- | --- | --- | --- |
| **P0 — Architecture freeze** | Lock interfaces and state model | ADR and interface versions approved | Signed compatibility matrix + version manifest |
| **P1 — Shadow proofs** | Produce proofs without affecting settlement | Deterministic checkpoint pipeline active | 2+ consecutive runs with complete artifact/evidence chain |
| **P2 — Dual-lane settlement gating** | Run compatibility lane + target lane in parallel | Shadow proof success within SLO | Zero unresolved critical divergence across cutover sample |
| **P3 — Controlled production slice** | Promote limited live traffic to target lane | P2 exit + rollback drill completed | SLO-compliant run at approved traffic %, rollback remains < target RTO |
| **P4 — General availability** | Make target lane default | P3 stable period complete | Gate owner sign-off + retained rollback path validated |

Promotion between phases is blocked unless all listed evidence is attached to the acceptance checklist.

## 8) Rollback and recovery posture

- Rollback target is always the compatibility lane until GA sign-off is complete.
- Rollback decisions must be tied to explicit triggers (mismatch, stale bridge state, policy outage, SLO breach).
- Recovery must produce a reconciliation artifact listing:
  - impacted `intent_id`s,
  - settlement status before/after rollback,
  - whether any replay is required.

## 9) Conformance checklist

A deployment conforms to this target architecture only if all are true:

1. Component boundaries in section 2 are implemented or explicitly mapped to equivalent services.
2. Trust-boundary rules in section 3 are enforced and test-covered.
3. Proof flow invariants in section 4 are verifiable from logs/evidence.
4. Failure-mode responses in section 5 are implemented as automated controls.
5. Operational telemetry in section 6 is available in production dashboards.
6. Phase evidence in section 7 is documented before each promotion.
