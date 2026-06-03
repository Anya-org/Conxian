# Compatibility matrix and acceptance gate checklist (CON-441)

This document is the cross-repo compatibility baseline for Conxian L3-profile migration and BitVM2/sBTC cutover readiness.

Related canonical docs:

- `docs/architecture/CONXIAN_L3_PROFILE_ADR.md`
- `docs/architecture/BITVM2_SBTC_BRIDGE_TARGET_ARCHITECTURE.md`
- `docs/SAB_MIGRATION_WAVES.md`
- `docs/operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md`
- `docs/operations/CON-681_PHASE6_ROLLBACK_DRILL_SIMULATION.md`

## 1) Scope (13-repo migration set)

This matrix covers the 13-repo execution set used for migration gate decisions.

### Group A — Protocol and settlement core

1. `Conxian`
2. `conxian-nexus`
3. `conxian-gateway`

### Group B — Client and product surfaces

4. `conxius-wallet`
5. `conxian-ui` (upstream repo: `Conxian_UI`)
6. `conxian-labs-site`

### Group C — Shared runtime and operational tooling

7. `lib-conxian-core`
8. `lib-conclave-sdk`
9. `conxius-platform`
10. `conxius_orbit`
11. `cxn-grid-oracle`

### Group D — Governance and control plane

12. `conxian-business`
13. `.github`

## 2) Migration gate model (objective, evidence-driven)

| Gate | Purpose | Required evidence (objective) |
| --- | --- | --- |
| **G0: Interface freeze** | Prevent mid-cutover contract/API/schema drift | Version manifest + changelog entries + compatibility sign-off |
| **G1: Dual-lane compatibility** | Prove legacy lane and target lane produce equivalent outcomes for in-scope flows | Replay/parallel-run report with mismatch classification |
| **G2: Boundary enforcement** | Ensure signer/finality/bridge boundaries are enforced and non-bypassable | Tests + policy checks + negative test evidence |
| **G3: Rollback readiness** | Demonstrate controlled fallback within RTO | Executed rollback drill report (timed) + post-drill reconciliation + link to `docs/operations/CON-681_PHASE6_ROLLBACK_DRILL_SIMULATION.md` |
| **G4: Promotion readiness** | Approve controlled production promotion | Gate review packet with SLO/error-budget results, owner approvals, and canonical rollout reference (`docs/operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md`) |

A repo is considered “gate-ready” only when required evidence is attached to its gate checklist entry.

## 3) Cross-repo compatibility matrix

| Function group | Repo | Compatibility scope (must remain stable) | Required gates | Objective evidence requirements |
| --- | --- | --- | --- | --- |
| Protocol core | `Conxian` | Contract traits, event schema, settlement-state transitions | G0, G1, G2, G3, G4 | Versioned ABI/trait manifest; deterministic test vectors; signed rollback drill result for contract-level feature flags |
| Protocol core | `conxian-nexus` | Checkpoint schema, reconciliation records, state-query contracts for Gateway/UI | G0, G1, G2, G3, G4 | Schema diff report (no unapproved breaking changes); dual-lane checkpoint comparison; replay evidence for indexed state rebuild |
| Protocol core | `conxian-gateway` | Ingress/egress policy APIs, bridge-state gating, idempotency semantics | G0, G1, G2, G3, G4 | API contract test report; policy boundary negative tests; cutover canary and rollback logs |
| Client surface | `conxius-wallet` | Signing flow compatibility, session/auth assumptions, settlement status handling | G0, G1, G2, G4 | Integration test report against frozen Gateway APIs; signer-boundary conformance checks; release-note acknowledgement of no bypass paths |
| Client surface | `conxian-ui` (`Conxian_UI`) | Read-model/API compatibility and state-label semantics | G0, G1, G4 | Snapshot/API contract tests; UI state mapping evidence tied to canonical status codes |
| Client surface | `conxian-labs-site` | Public status/docs references and migration comms correctness | G0, G4 | Published docs link validation; release-communication checklist sign-off |
| Shared runtime | `lib-conxian-core` | Shared model/version semantics used by Gateway/Nexus/Wallet | G0, G1, G2 | Semantic-version delta report; downstream compile/test compatibility report across dependents |
| Shared runtime | `lib-conclave-sdk` | Attestation/session primitives and signer-boundary helper APIs | G0, G1, G2 | Interface freeze tag; attestation boundary test report; compatibility matrix of consumers |
| Shared runtime | `conxius-platform` | Environment orchestration for dual-lane validation and rollback drills | G0, G1, G3 | Reproducible environment manifests; drill execution logs; dependency lockfile integrity evidence |
| Shared runtime | `conxius_orbit` | Deployment/promote/rollback tooling behavior for contract/service rollout | G0, G2, G3, G4 | Tooling dry-run logs; signed promotion script checksum; rollback rehearsal evidence |
| Shared runtime | `cxn-grid-oracle` | Oracle feed schema and freshness semantics consumed by migration flows | G0, G1, G2 | Feed schema contract tests; freshness/staleness alarm evidence; fail-closed behavior test |
| Governance | `conxian-business` | Canonical docs, gates, and migration decision records | G0, G4 | Updated canonical docs with gate mapping; review approvals captured in change log |
| Governance | `.github` | CI policy/workflow enforcement of gate evidence and link integrity | G0, G2, G4 | Required-check configuration evidence; workflow run logs proving gate check enforcement |

## 4) Gate acceptance checklist (program-level)

### G0 — Interface freeze checklist

- [ ] Version manifest captured for all 13 repos.
- [ ] Breaking-change review completed and approved.
- [ ] Compatibility matrix updated with current versions and owners.
- [ ] CI checks confirm no unapproved schema/ABI drift.

### G1 — Dual-lane compatibility checklist

- [ ] Parallel-run dataset and traffic sample defined.
- [ ] Deterministic mismatch thresholds approved.
- [ ] Mismatch report produced with severity classification.
- [ ] No unresolved high-severity mismatches.

### G2 — Boundary enforcement checklist

- [ ] Nakamoto signer vs sBTC signer vs BOS signer boundaries verified in tests.
- [ ] Negative tests prove no boundary bypass path.
- [ ] Fail-closed behavior validated for stale/invalid bridge and attestation states.
- [ ] Evidence linked for each affected repo.

### G3 — Rollback readiness checklist

- [ ] Rollback runbook executed in controlled environment.
- [ ] Measured rollback completion time meets RTO target.
- [ ] Reconciliation report proves no orphaned settlement state.
- [ ] On-call ownership and escalation paths confirmed.
- [ ] Evidence packet links to `docs/operations/CON-681_PHASE6_ROLLBACK_DRILL_SIMULATION.md`.

### G4 — Promotion readiness checklist

- [ ] SLO/error-budget results captured for promotion window.
- [ ] Required owner approvals recorded (protocol, gateway, nexus, governance).
- [ ] User-facing communication/docs updated and link-checked.
- [ ] Decision log includes go/no-go rationale and fallback trigger conditions.
- [ ] Decision log references `docs/operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md` as canonical rollout authority.

## 5) Evidence quality standard (applies to every gate)

Each evidence item MUST be:

1. **Objective:** generated from tests, CI logs, or reproducible scripts (not narrative-only).
2. **Traceable:** linked to commit SHA, run ID, or immutable artifact hash.
3. **Scoped:** clearly tied to one repo and one gate.
4. **Current:** produced in the same release window as the gate decision.

Evidence that fails any of the above does not satisfy gate acceptance.
