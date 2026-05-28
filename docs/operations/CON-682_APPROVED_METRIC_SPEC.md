# CON-682 Approved Metric Spec (v1)

## Context and scope

This artifact materializes the approved v1 metric definitions from Linear issue [CON-682](https://linear.app/conxian-labs/issue/CON-682) as the durable in-repo source of truth.

Scope is limited to v1 canonical metric formulas, ownership, data sources, refresh cadence, and required data contracts/dependencies.

## Canonical metric table

| Metric | Formula (v1) | Owner (function) | Data source / query | Refresh cadence | Required data contracts / dependencies |
| --- | --- | --- | --- | --- | --- |
| `C_R` | `0.35*TEE + 0.25*Clarity + 0.20*Compliance + 0.20*IntegrationStickiness` (components scored 0–100; output 0–100) | Architecture | `architecture_moat_scorecard` weekly snapshot (`tee_score`, `clarity_score`, `compliance_score`, `integration_stickiness_score`) | Weekly (Mon 00:00 UTC) | Weekly scorecard must publish all 4 component scores plus evidence links; integration registry must be current for the same week. |
| `O_C` | `SUM(manual_hours)` for founder-owned critical-path workflows in period | Ops | `founder_worklog` + Linear tasks tagged `critical-path`; weekly rollup over tagged entries | Daily refresh, weekly review | All founder-critical workflows must log duration and `critical_path=true`; Linear workflow state mapping must remain stable. |
| `V_X` | `completed_weighted_scope_7d / NULLIF(median_cycle_time_days_7d, 0)` | Engineering | `engineering_flow_metrics` from GitHub merges + Linear completed scope and lead-time | Daily refresh, weekly review | Every merged PR must map to a Linear work item; scope-weight field required on completed items. |
| `A_S` | `automated_recurring_runs_7d / total_recurring_runs_7d` | BOS/Automation | `automation_run_events` (`workflow_id`, `run_mode`, `status`, `recovery_minutes`) | Daily refresh, weekly review | Run-event schema must include `workflow_id`, `run_mode` (`auto`/`manual`), `status`, `recovery_minutes`; autonomy guardrails: `>=99.5%` reconciliation and `<=15m` autonomous recovery. |
| `N_E` | `AVG(existing_participant_uplift_pct)` over enterprises onboarded in trailing 30d, where `uplift_pct = max(cost_reduction_pct, liquidity_depth_increase_pct)` | Growth/Protocol | `network_outcomes` + enterprise onboarding registry + jurisdiction dimension | Weekly (trailing 30d) | Active enterprise-node registry by jurisdiction + attributable participant-outcome dataset; threshold guardrails: `>=5` active enterprise nodes across `>=2` jurisdictions, and each added enterprise yields `>=3%` cost reduction or `>=5%` liquidity-depth uplift over trailing 30d. |

## Notes on cadence/contracts

- Cadence is part of metric correctness for v1. `C_R` and `N_E` are weekly snapshots; `O_C`, `V_X`, and `A_S` refresh daily with weekly operational review.
- A metric is considered non-reportable for a period if its required data contract/dependency is missing or stale.
- Guardrails defined in the table (autonomy and network thresholds) are required constraints for accepting v1 metric outputs.
