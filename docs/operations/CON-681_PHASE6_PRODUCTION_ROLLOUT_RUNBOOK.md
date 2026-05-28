# CON-681 Phase 6 production rollout runbook (canonical)

**Status:** Canonical
**Issue:** [CON-681](https://linear.app/conxian-labs/issue/CON-681/intelligencephase-6-production-rollout-runbook-observability-rollback)
**Visibility:** Public-safe (sensitive execution details remain in Linear records under ZSE)
**Last updated:** 2026-05-26

## 1) Purpose and scope

This runbook is the canonical operating reference for the Phase 6 production rollout.

It defines:

- staged rollout gates and objective evidence requirements,
- required observability metrics and alert thresholds per interface,
- explicit rollback triggers and deterministic operator actions,
- operator checklists and communication templates used during normal rollout and incidents.

For privileged identifiers (service account names, paging routes, secret-backed endpoints, and privileged command payloads), reference the CON-681 internal Linear sub-records.

## 2) Rollout gate model (required order)

Rollout progression is strictly sequential:

`Preflight` -> `Shadow/Internal` -> `Controlled cohort` -> `Broad enablement`

No gate may be advanced without all entry criteria and evidence completed.

| Gate | Entry criteria | Exit criteria | Primary owners | Required evidence |
| --- | --- | --- | --- | --- |
| **Preflight** | Release candidate is tagged; no unresolved P0/P1 defects; migration compatibility checks complete; alert routes validated | Shadow traffic dry-run approved; rollback path verified; go/no-go signed | Platform on-call, Gateway owner, Governance owner | CI/test evidence pack, config diff, rollback readiness checklist, approval log |
| **Shadow/Internal** | Preflight complete; production write paths remain gated; internal-only traffic routing enabled | 24h stable telemetry with no critical alerts; no contract-violation growth; internal validation sign-off | SRE on-call, Protocol owner, Nexus owner | Shadow telemetry report, incident log (if any), contract validation report |
| **Controlled cohort** | Shadow/Internal complete; cohort definition approved; blast radius constraints documented | Cohort window meets SLO/error budget; rollback drill replay validated in-window; business owner approval | SRE on-call, Product ops, Incident commander | Cohort health dashboard export, rollback drill checklist confirmation, approval record |
| **Broad enablement** | Controlled cohort complete; all blocking corrective actions resolved or accepted with owner/date | Broad rollout complete with stable 48h post-enable metrics; post-rollout review published | Platform owner, Operations lead, Governance owner | Final gate decision log, 48h observability summary, communication completion evidence |

## 3) Observability matrix (required metrics + alert thresholds)

### Metric requirements (all interfaces)

Every Phase 6 interface must report and alert on:

1. **Request rate** (throughput integrity and sudden drop/surge detection)
2. **Error rate** (5xx + explicit domain failures)
3. **p95 latency** (user and operator impact)
4. **Contract-violation counter** (schema, trait, policy, or boundary violations)

### Per-interface matrix

| Interface (Phase 6) | Request rate alert | Error rate alert | p95 latency alert | Contract-violation counter alert | Owner |
| --- | --- | --- | --- | --- | --- |
| **Conxian Gateway MCP ingress** (`/api/v1/mcp`) | Warn: <70% or >130% of expected 15m baseline for 10m; Critical: <50% for 10m | Warn: >1.5% for 5m; Critical: >3% for 10m | Warn: >300ms for 10m; Critical: >500ms for 10m | Warn: >=1/15m; Critical: >=3/15m | Gateway on-call |
| **Gateway -> Protocol contract execution path** | Warn: >120% expected signed-write volume for 10m | Warn: >1% reverted or failed writes for 5m; Critical: >2% for 10m | Warn: >450ms for 10m; Critical: >700ms for 10m | Critical: >=1 high-severity ABI/trait violation in 5m | Protocol on-call |
| **Gateway -> Nexus state reconciliation API** | Warn: <80% expected reconciliation pulls for 10m | Warn: >1% reconciliation failures for 5m; Critical: >2.5% for 10m | Warn: >400ms for 10m; Critical: >650ms for 10m | Warn: >=1 schema contract violation/15m; Critical: >=2/15m | Nexus on-call |
| **Conxius Wallet/Conxian UI status-query interface** | Warn: >140% baseline for 10m (traffic surge) | Warn: >2% for 5m; Critical: >4% for 10m | Warn: >350ms for 10m; Critical: >600ms for 10m | Warn: >=1 response contract violation/15m; Critical: >=3/15m | Client surface owner |
| **Conxius Enclave SDK attestation/session verification interface** | Warn: <75% expected successful attestations for 10m | Warn: >1% attestation/session failures for 5m; Critical: >2% for 10m | Warn: >500ms for 10m; Critical: >800ms for 10m | Critical: >=1 policy-boundary violation in 5m | Enclave on-call |

If any critical threshold is reached during `Controlled cohort` or `Broad enablement`, initiate rollback decisioning immediately per Section 4.

## 4) Rollback triggers and deterministic operator actions

### Rollback trigger table

| Trigger ID | Rollback trigger | Deterministic operator actions |
| --- | --- | --- |
| **RBT-01** | Contract-violation counter reaches critical threshold on any write-path interface | 1) Declare incident severity and freeze gate progression. 2) Disable Phase 6 write enablement flag for affected interface. 3) Route traffic back to previous stable lane profile. 4) Confirm violation counter returns to baseline for two consecutive windows. |
| **RBT-02** | Error rate remains at critical threshold for >=10m despite mitigation | 1) Trigger rollback to previous gate traffic percentage. 2) Pause promotions and deploys for affected components. 3) Re-enable last known-good release config. 4) Validate request + error recovery before reopening cohort. |
| **RBT-03** | p95 latency remains critical for >=10m and degrades customer-facing SLO | 1) Shift cohort traffic to safe baseline. 2) Disable non-essential Phase 6 features to reduce load. 3) Verify latency recovery for 15m sustained. 4) Escalate for root cause review before re-entry. |
| **RBT-04** | Data integrity/reconciliation mismatch exceeds approved tolerance | 1) Halt new state-changing operations. 2) Execute deterministic reconciliation replay from last verified checkpoint. 3) Roll back gate state to `Shadow/Internal`. 4) Resume only after mismatch delta returns within tolerance and owners sign. |
| **RBT-05** | Security or attestation boundary failure indicates fail-open risk | 1) Immediately disable impacted attestation-dependent workflows. 2) Roll traffic to safe read-only or previously validated controls. 3) Confirm fail-closed behavior and credential rotation status. 4) Require governance + security owner approval before re-enable. |

### Gate fallback map

- `Broad enablement` fallback target: `Controlled cohort`
- `Controlled cohort` fallback target: `Shadow/Internal`
- `Shadow/Internal` fallback target: `Preflight` (no production writes)
- `Preflight` fallback target: stop rollout and hold release candidate

## 5) Operator checklist

### 5.1 Pre-deploy checklist

- [ ] Gate prerequisites for `Preflight` are complete and evidenced.
- [ ] Alert routes tested for all interfaces in Section 3.
- [ ] Rollback authority and incident commander for the window confirmed.
- [ ] Last known-good release artifact and config bundle validated.
- [ ] Communication channels and template links pre-loaded.

### 5.2 Deployment/checkpoint checklist

- [ ] Gate progression announcement sent at start of each gate.
- [ ] Metrics dashboard reviewed every 15 minutes during active progression.
- [ ] Any warning threshold breach has an owner and mitigation timestamp.
- [ ] Critical threshold breaches are evaluated against rollback triggers (RBT-01..RBT-05).
- [ ] Evidence artifacts captured before requesting gate exit approval.

### 5.3 Post-deploy checklist

- [ ] 48h stability window completed (or documented exception approved).
- [ ] Post-rollout summary posted with objective metrics and incidents.
- [ ] Follow-up issues created for all non-blocking defects and risk debt.
- [ ] Documentation links in gate trackers and checklists verified.

### 5.4 Incident/rollback checklist

- [ ] Declare incident and assign incident commander.
- [ ] Identify trigger ID and confirm rollback path from fallback map.
- [ ] Execute deterministic actions from trigger table.
- [ ] Validate recovery metrics against pre-defined thresholds.
- [ ] Publish rollback completion update and corrective action plan.

## 6) Communication templates

Use these templates in rollout channels, incident threads, and issue updates.

### 6.1 Incident declaration template

```text
[PHASE6][INCIDENT] Gate: <Preflight|Shadow/Internal|Controlled cohort|Broad enablement>
Trigger: <RBT-01..RBT-05>
Start time (UTC): <YYYY-MM-DD HH:MM>
Impact summary: <one-line impact>
Immediate action: <rollback action started>
Owner(s): <incident commander>, <service owner>
Next update ETA: <time>
```

### 6.2 Rollback in-progress template

```text
[PHASE6][ROLLBACK-IN-PROGRESS] Trigger: <RBT-..>
Rollback target gate: <target>
Actions executed: <action 1>, <action 2>, <action 3>
Current metrics: error=<x%>, p95=<y ms>, violations=<count>
Risks/open items: <brief>
Next checkpoint ETA: <time>
```

### 6.3 Rollback complete template

```text
[PHASE6][ROLLBACK-COMPLETE]
Completed at (UTC): <YYYY-MM-DD HH:MM>
Restored gate/state: <state>
Recovery metrics: error=<x%>, p95=<y ms>, violations=<count>
RTO result: <actual vs target>
RPO result: <actual vs target>
Corrective actions: <ticket/issue refs>
```

## 7) Related artifacts

- Rollback drill simulation: [CON-681 Phase 6 rollback drill simulation](./CON-681_PHASE6_ROLLBACK_DRILL_SIMULATION.md)
- Cross-repo gate checklist: [Compatibility matrix and acceptance gate checklist](../COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md)
- Compatibility pointer (legacy link path): [Phase 6 observability runbook shim](../PHASE6_OBSERVABILITY_RUNBOOK.md)

For sensitive implementation details and restricted operational parameters, use CON-681 child records in Linear rather than storing those details in this repository.
