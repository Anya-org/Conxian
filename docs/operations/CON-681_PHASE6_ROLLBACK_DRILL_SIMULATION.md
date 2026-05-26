# CON-681 Phase 6 rollback drill simulation

**Status:** Canonical drill artifact for CON-681 gate evidence
**Issue:** [CON-681](https://linear.app/conxian-labs/issue/CON-681/intelligencephase-6-production-rollout-runbook-observability-rollback)
**Visibility:** Public-safe (sensitive environment identifiers remain in Linear under ZSE)
**Simulation date:** 2026-05-26
**Simulation type:** Tabletop + metric replay (assumption-driven)

## 1) Scenario summary

During `Controlled cohort` rollout, the contract-violation counter on the Gateway write path spikes because of an interface mismatch between Gateway payload expectations and protocol contract parameter validation.

### Trigger condition exercised

- **Primary trigger:** `RBT-01` (critical contract-violation threshold breach)
- **Secondary stress condition:** elevated p95 latency on reconciliation path during rollback decision window

### Objective

Validate that operators can:

1. detect the breach quickly,
2. execute deterministic rollback to `Shadow/Internal`,
3. restore stability within target RTO,
4. preserve data integrity (RPO target).

## 2) Roles and ownership

| Role | Owner group | Responsibilities during simulation |
| --- | --- | --- |
| Incident commander | Platform operations | Declares incident, approves rollback execution, drives timeline checkpoints |
| Gateway operator | Conxian Gateway on-call | Disables Phase 6 write enablement and verifies ingress recovery |
| Protocol operator | Conxian Protocol on-call | Validates contract safety and confirms violation counter normalization |
| Nexus operator | Conxian Nexus on-call | Verifies reconciliation state and backlog health |
| Communications lead | Governance/ops | Sends incident + rollback updates with template messages |

## 3) Timeline (UTC)

| Time | Event | Owner |
| --- | --- | --- |
| 10:00 | Controlled cohort starts at 10% traffic | Incident commander |
| 10:06 | Contract-violation alert crosses critical threshold (`>=3/15m`) | Gateway operator |
| 10:07 | Incident declared; gate progression frozen | Incident commander |
| 10:09 | `RBT-01` confirmed; rollback authorized | Incident commander + Protocol operator |
| 10:11 | Phase 6 write-path flag disabled; traffic profile shifted to `Shadow/Internal` | Gateway operator |
| 10:14 | Error and violation rates trend down; reconciliation lag investigated | Nexus operator |
| 10:18 | Metrics stable for two windows; rollback marked complete | Incident commander |
| 10:24 | Corrective action draft recorded and assigned | Communications lead |

## 4) Execution steps performed

1. **Detection and triage**
   - Alert policy identified critical contract-violation threshold breach.
   - Incident commander confirmed affected interface and froze gate progression.
2. **Rollback execution**
   - Phase 6 write enablement switched off for cohort path.
   - Traffic shifted from `Controlled cohort` back to `Shadow/Internal` profile.
   - New state-changing operations paused while reconciliation checks ran.
3. **Stability validation**
   - Gateway error rate returned below warning threshold.
   - Contract-violation counter returned to zero in consecutive windows.
   - Reconciliation backlog drained within tolerance.
4. **Closure and follow-up**
   - Rollback completion update published.
   - Corrective actions logged for schema drift prevention and faster triage.

## 5) Observed metrics during simulation

| Metric | Peak observed | Recovery value | Threshold/target | Result |
| --- | --- | --- | --- | --- |
| Gateway request rate deviation | +18% vs expected | +4% vs expected | <30% deviation | Pass |
| Gateway error rate | 3.4% (critical) | 0.8% | <1.5% warning target | Pass after rollback |
| Gateway p95 latency | 520ms (critical) | 240ms | <300ms warning target | Pass after rollback |
| Contract-violation counter | 4 in 15m (critical) | 0 | 0 critical violations sustained | Pass after rollback |
| Nexus reconciliation lag | 6m lag | <1m lag | <2m target | Pass |

## 6) RTO / RPO results

| Objective | Target | Actual | Result |
| --- | --- | --- | --- |
| **RTO** (detect + rollback + stabilize) | <=20 minutes | 12 minutes (10:06 -> 10:18) | Pass |
| **RPO** (state/data loss) | 0 untracked writes | 0 untracked writes observed | Pass |

## 7) Outcome and corrective actions

### Outcome

- Drill objective achieved: rollback path executed deterministically and restored stable operation inside target window.
- No data-loss event observed in simulation assumptions.

### Corrective actions

1. Add a preflight contract schema compatibility diff gate before any `Controlled cohort` activation.
2. Add a dedicated dashboard panel for contract-violation counters by interface and gate.
3. Add a runbook quick-action card mapping `RBT-01..RBT-05` to copy/paste response steps.
4. Run a follow-up drill that includes concurrent attestation degradation (`RBT-05`) to test multi-trigger coordination.

## 8) Assumptions (tabletop simulation)

This artifact includes tabletop assumptions and metric replay rather than unrestricted live-production experimentation.

- Production traffic was represented by controlled replay samples.
- Sensitive environment identifiers (service IDs, pager routes, exact secret-backed toggles) were omitted from this repo per ZSE policy.
- Detailed evidence artifacts are tracked in CON-681 internal Linear records.

## 9) Linked canonical references

- Canonical rollout runbook: [CON-681 Phase 6 production rollout runbook](./CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md)
- Cross-repo acceptance gate checklist: [Compatibility matrix and acceptance gate checklist](../COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md)
