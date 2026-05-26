# CON-683 — Phase 3 controlled production slice evidence pack (2026-05-26)

- **Issue:** https://linear.app/conxian-labs/issue/CON-683/build-phase-3-evidence-pack-for-autonomy-gate
- **Repository:** `Conxian/conxian-business`
- **Snapshot commit (pack authoring start):** `477817cbbd673c8c9c363583b2b3336d48e1167b`
- **Local evidence artifacts:** `audit/evidence/con-683/`
- **ZSE boundary:** this pack includes only public-safe references and local command outputs; private operational runbooks are represented as documented placeholders.

## Gate context and scope

Phase 3 is defined as **"Controlled production slice"** in the target architecture. Entry requires P2 completion plus rollback drill completion, and exit requires an SLO-compliant run at approved traffic percentage with rollback under target RTO.

Canonical source anchors:

- Architecture + gate sequence:
  - [`docs/architecture/BITVM2_SBTC_BRIDGE_TARGET_ARCHITECTURE.md#L119-L136`](../docs/architecture/BITVM2_SBTC_BRIDGE_TARGET_ARCHITECTURE.md#L119-L136)
  - [`docs/architecture/CONXIAN_L3_PROFILE_ADR.md#L56-L66`](../docs/architecture/CONXIAN_L3_PROFILE_ADR.md#L56-L66)
- Gate/checklist requirements:
  - [`openspec/specs/mainnet-acceptance-evidence-pack/spec.md#requirement-evidence-pack-content`](../openspec/specs/mainnet-acceptance-evidence-pack/spec.md#requirement-evidence-pack-content)
  - [`docs/COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md#2-migration-gate-model-objective-evidence-driven`](../docs/COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md#2-migration-gate-model-objective-evidence-driven)
  - [`docs/PROMOTION_CHECKLISTS.md#mainnet-acceptance-evidence-pack`](../docs/PROMOTION_CHECKLISTS.md#mainnet-acceptance-evidence-pack)
- Runbook + recovery context:
  - [`docs/PHASE6_OBSERVABILITY_RUNBOOK.md#2-observability-metrics`](../docs/PHASE6_OBSERVABILITY_RUNBOOK.md#2-observability-metrics)
  - [`docs/PHASE6_OBSERVABILITY_RUNBOOK.md#3-rollback-drills`](../docs/PHASE6_OBSERVABILITY_RUNBOOK.md#3-rollback-drills)
  - [`docs/INTEGRATED_SYSTEM_TESTNET_GATE.md#evidence-format-minimum`](../docs/INTEGRATED_SYSTEM_TESTNET_GATE.md#evidence-format-minimum)

In-scope for this pack:

1. Threshold-linked telemetry signals and gating requirements.
2. Recovery drill/runbook evidence expectations.
3. Objective pass/fail checks from reproducible local command artifacts.
4. Missing instrumentation/documentation gaps that block a clean GO decision.

Out-of-scope for this pack:

- Private incident playbooks, secrets, signer details, and internal-only operational procedures (ZSE constrained).

## Telemetry threshold evidence matrix

| Telemetry threshold / signal | Canonical source | Concrete evidence pointer | Status | Verification note |
| --- | --- | --- | --- | --- |
| Gateway strain threshold: MCP telemetry latency `>200ms` indicates risk | `docs/PHASE6_OBSERVABILITY_RUNBOOK.md:13` | [`14-telemetry-signal-threshold-scan.txt`](./evidence/con-683/14-telemetry-signal-threshold-scan.txt) | **documented** | Threshold exists in runbook; no current production timeseries snapshot attached in-repo. |
| Enclave alert threshold: biometric signature failure rate `>5%` | `docs/PHASE6_OBSERVABILITY_RUNBOOK.md:15` | [`14-telemetry-signal-threshold-scan.txt`](./evidence/con-683/14-telemetry-signal-threshold-scan.txt) | **documented** | Trigger condition exists; no linked drill/output proving alert pipeline observed in this pack. |
| Mandatory Phase evidence metrics (`proof_job_success_rate`, `proof_generation_latency_p95`, `verifier_mismatch_count`, `bridge_state_freshness_seconds`, `rollback_trigger_count`) | `docs/architecture/BITVM2_SBTC_BRIDGE_TARGET_ARCHITECTURE.md:119-124` | [`11-phase3-checkpoints-and-metrics.txt`](./evidence/con-683/11-phase3-checkpoints-and-metrics.txt) | **documented** | Metric names are explicit; metric values for current slice are not attached. |
| P3 exit requires SLO-compliant run and rollback `< target RTO` | `docs/architecture/BITVM2_SBTC_BRIDGE_TARGET_ARCHITECTURE.md:133` | [`11-phase3-checkpoints-and-metrics.txt`](./evidence/con-683/11-phase3-checkpoints-and-metrics.txt) | **documented** | Exit criteria captured, but no commit-pinned slice report proving completion. |
| Promotion gate requires SLO/error-budget packet | `docs/COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md:48,102` | [`12-gate-checklist-pass-fail-criteria.txt`](./evidence/con-683/12-gate-checklist-pass-fail-criteria.txt) | **documented** | Requirement is objective and explicit; current evidence packet does not yet include SLO/error-budget result artifact. |

## Recovery drill / runbook evidence matrix

| Recovery requirement | Canonical source | Concrete evidence pointer | Status | Verification note |
| --- | --- | --- | --- | --- |
| P3 entry requires rollback drill completed before controlled slice | `docs/architecture/BITVM2_SBTC_BRIDGE_TARGET_ARCHITECTURE.md:133` | [`11-phase3-checkpoints-and-metrics.txt`](./evidence/con-683/11-phase3-checkpoints-and-metrics.txt) | **documented** | Gate condition captured; no linked executed drill report in this repo snapshot. |
| G3 rollback readiness requires timed drill + reconciliation evidence + RTO compliance | `docs/COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md:47,95-97` | [`12-gate-checklist-pass-fail-criteria.txt`](./evidence/con-683/12-gate-checklist-pass-fail-criteria.txt) | **documented** | Acceptance criteria are objective; required execution artifacts are currently missing. |
| Runbook has rollback scenarios (Gateway disconnect, contract vulnerability) | `docs/PHASE6_OBSERVABILITY_RUNBOOK.md:17-26` | [`03-recovery-runbook-and-drill-requirements.txt`](./evidence/con-683/03-recovery-runbook-and-drill-requirements.txt) | **partial** | Public-safe scenario steps exist; does not include timed drill outputs or reconciliation report. |
| Sensitive runbooks/logs must stay outside git and be linked from Linear | `docs/INTEGRATED_SYSTEM_TESTNET_GATE.md:59` | [`13-integrated-testnet-evidence-and-no-go.txt`](./evidence/con-683/13-integrated-testnet-evidence-and-no-go.txt) | **documented** | Policy supports private evidence placement; this pack currently lacks direct Linear artifact links for drill execution. |
| Maintainer payout runbook and some operational docs are stubs canonical in sovereign layer | `docs/DOCUMENTATION_ALIGNMENT_INDEX.md:174-177`, `docs/bounties/MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md` | [`07-known-doc-gaps-scan.txt`](./evidence/con-683/07-known-doc-gaps-scan.txt) | **gap identified** | Stub policy is clear, but concrete private links required for full recovery evidence traceability are not present in this repo pack. |

## Pass/fail criteria with objective verification pointers

| Criterion | Objective verification pointer(s) | Result |
| --- | --- | --- |
| Evidence-pack format and checklist anchors are present in-repo | [`01-evidence-pack-spec-and-promotion-checklist.txt`](./evidence/con-683/01-evidence-pack-spec-and-promotion-checklist.txt) | **PASS** |
| Production-path residue scan for stubs/mocks/placeholders returns clean | [`04-production-residue-scan.txt`](./evidence/con-683/04-production-residue-scan.txt) (`rg` exit `1` = no matches) | **PASS** |
| Testnet principal literals in non-doc production paths return clean | [`05-testnet-principal-literal-scan.txt`](./evidence/con-683/05-testnet-principal-literal-scan.txt) (`rg` exit `1` = no matches) | **PASS** |
| Hardcoded `networkFromName('testnet')` defaults in scripts return clean | [`06-hardcoded-testnet-network-scan.txt`](./evidence/con-683/06-hardcoded-testnet-network-scan.txt) (`rg` exit `1` = no matches) | **PASS** |
| Baseline compartmentalization check executes successfully | [`08-unbundle-check.txt`](./evidence/con-683/08-unbundle-check.txt) | **PASS** |
| Full local test suite runs in current environment | [`09-test-suite-check.txt`](./evidence/con-683/09-test-suite-check.txt), [`10-submodule-status.txt`](./evidence/con-683/10-submodule-status.txt) | **BLOCKED** (workspace submodules not initialized; missing `conxian-nexus/Cargo.toml`) |
| Telemetry + gate threshold requirements are traceably documented for Phase 3 | [`02-telemetry-threshold-criteria.txt`](./evidence/con-683/02-telemetry-threshold-criteria.txt), [`11-phase3-checkpoints-and-metrics.txt`](./evidence/con-683/11-phase3-checkpoints-and-metrics.txt), [`14-telemetry-signal-threshold-scan.txt`](./evidence/con-683/14-telemetry-signal-threshold-scan.txt) | **PASS (requirements capture)** |
| Recovery/no-go policy is explicitly documented and fail-closed oriented | [`03-recovery-runbook-and-drill-requirements.txt`](./evidence/con-683/03-recovery-runbook-and-drill-requirements.txt), [`13-integrated-testnet-evidence-and-no-go.txt`](./evidence/con-683/13-integrated-testnet-evidence-and-no-go.txt) | **PASS (requirements capture)** |

## Missing instrumentation / documentation gaps

1. **Missing metric-value artifacts for mandatory Phase telemetry signals.**
   - Required metrics are listed (`proof_job_success_rate`, `proof_generation_latency_p95`, etc.), but this pack has no commit-pinned dashboard export or query snapshot proving current values.
2. **Missing rollback drill execution evidence required by P3/G3.**
   - No timed rollback drill report, no reconciliation artifact, and no proof that rollback completion met target RTO.
3. **Missing private runbook evidence links (ZSE-compliant placeholders only).**
   - Repo policy correctly points private operational detail to sovereign/Linear, but this pack lacks concrete private artifact links for the specific recovery drills.
4. **Local integration validation blocked by submodule/workspace state.**
   - `make test-all` failed because required workspace member `conxian-nexus` is not initialized in this environment.

## Current gate recommendation

**Decision: CONDITIONAL**

Rationale:

- Objective requirement references are now consolidated and reproducible via local artifacts.
- Production residue scans are clean for the checked patterns.
- However, the required **runtime evidence** for Phase 3 (SLO/error-budget output, telemetry metric values, timed rollback drill + reconciliation, and RTO proof) is not yet attached.
- Local full-suite validation is blocked by submodule initialization constraints, so current verification remains incomplete.

Conditions to move from **CONDITIONAL** to **GO**:

1. Attach commit-pinned telemetry outputs covering all mandatory Phase metrics and SLO/error-budget window results.
2. Attach rollback drill evidence (timed run, reconciliation artifact, and measured rollback `< target RTO`).
3. Add ZSE-safe references to private runbook/drill artifacts in Linear (placeholder links where public docs intentionally stub details).
4. Re-run full validation after submodule initialization (or attach equivalent CI evidence) and link artifacts.

## Local evidence artifact inventory

| Artifact | Purpose | Status |
| --- | --- | --- |
| [`01-evidence-pack-spec-and-promotion-checklist.txt`](./evidence/con-683/01-evidence-pack-spec-and-promotion-checklist.txt) | Confirms evidence-pack format/checklist anchors | pass |
| [`02-telemetry-threshold-criteria.txt`](./evidence/con-683/02-telemetry-threshold-criteria.txt) | Threshold and no-go language discovery | pass |
| [`03-recovery-runbook-and-drill-requirements.txt`](./evidence/con-683/03-recovery-runbook-and-drill-requirements.txt) | Recovery/runbook requirement discovery | pass |
| [`04-production-residue-scan.txt`](./evidence/con-683/04-production-residue-scan.txt) | Residue scan in production paths | pass (clean, no matches) |
| [`05-testnet-principal-literal-scan.txt`](./evidence/con-683/05-testnet-principal-literal-scan.txt) | Hardcoded testnet principal scan | pass (clean, no matches) |
| [`06-hardcoded-testnet-network-scan.txt`](./evidence/con-683/06-hardcoded-testnet-network-scan.txt) | Hardcoded testnet default scan in scripts | pass (clean, no matches) |
| [`07-known-doc-gaps-scan.txt`](./evidence/con-683/07-known-doc-gaps-scan.txt) | ZSE stub and doc-gap discovery | pass |
| [`08-unbundle-check.txt`](./evidence/con-683/08-unbundle-check.txt) | Compartmentalization baseline check | pass |
| [`09-test-suite-check.txt`](./evidence/con-683/09-test-suite-check.txt) | Full test suite execution attempt | blocked |
| [`10-submodule-status.txt`](./evidence/con-683/10-submodule-status.txt) | Submodule state evidence for blocked tests | blocked context |
| [`11-phase3-checkpoints-and-metrics.txt`](./evidence/con-683/11-phase3-checkpoints-and-metrics.txt) | Phase 3 checkpoint and metric anchors | pass |
| [`12-gate-checklist-pass-fail-criteria.txt`](./evidence/con-683/12-gate-checklist-pass-fail-criteria.txt) | Objective pass/fail checklist anchors | pass |
| [`13-integrated-testnet-evidence-and-no-go.txt`](./evidence/con-683/13-integrated-testnet-evidence-and-no-go.txt) | Integrated gate evidence/no-go/fail-closed anchors | pass |
| [`14-telemetry-signal-threshold-scan.txt`](./evidence/con-683/14-telemetry-signal-threshold-scan.txt) | Consolidated telemetry signal threshold anchors | pass |
