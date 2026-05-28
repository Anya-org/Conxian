# Protocol Adapter Maturity Lanes

## Status

Canonical baseline for protocol-adapter maturity lanes and intake defaults (CON-715).

## Purpose

This document defines a single maturity-lane model for protocol-adapter work, especially for emerging rails. It standardizes intake metadata, promotion criteria, and cross-repo handoffs.

## Lane taxonomy and default rule

| Lane | Use when | Delivery posture |
| --- | --- | --- |
| `Build-now` | The adapter is prioritized for near-term production rollout with committed capacity. | Full implementation and release-gate evidence are expected in the active delivery cycle. |
| `Pilot` | The adapter needs controlled real-environment validation before broad rollout. | Limited-scope implementation with explicit pilot controls and rollback criteria. |
| `Partner` | The adapter depends on external partner readiness, contracts, or shared runbooks. | Integration planning and execution are staged around partner dependencies. |
| `Research` | The adapter is exploratory, pre-commitment, or lacks production readiness inputs. | Discovery-first with bounded experiments and explicit promotion blockers. |

**Default rule:** If a maturity lane is not explicitly set in intake, the lane **must default to `Research`**.

## Intake schema (required fields)

Use this schema for protocol-adapter and emerging-rail intake items.

| Field | Requirement |
| --- | --- |
| `lane` | Required. Allowed values: `Build-now`, `Pilot`, `Partner`, `Research`. If missing, set `Research` by default and record that default was applied. |
| `railScope` | Required. Define the target rail(s) and boundary (for example: Lightning, Rootstock, Liquid, or another named rail). |
| `targetAdapterInterface` | Required. Name the interface or service boundary the adapter must satisfy. |
| `owner` | Required. Single accountable owner for lane progression decisions. |
| `reviewCadence` | Required. Minimum review rhythm (weekly, bi-weekly, or milestone-based) for maturity reassessment. |
| `riskRegister` | Required. Link or reference to tracked technical, regulatory, and dependency risks. |
| `promotionBlockers` | Required. Explicit blockers that must clear before lane promotion. |

## Promotion criteria by transition

| Transition | Minimum criteria |
| --- | --- |
| `Research -> Pilot` | Scope and interface are stable, major risks are logged with owners, an executable pilot plan exists, and success/rollback signals are defined. |
| `Pilot -> Partner` | Pilot evidence is captured, key runtime/operational gaps are closed or accepted, and external dependency requirements are documented. |
| `Partner -> Build-now` | Partner obligations are confirmed, implementation sequencing is approved, release-gate evidence plan is complete, and production ownership is staffed. |

Lane promotion is not automatic. Promotion requires a documented review decision and updated blockers.

## Test and observability expectations by lane

| Lane | Minimum test expectations | Minimum observability expectations |
| --- | --- | --- |
| `Research` | Hypothesis tests and adapter-interface contract checks for explored paths. | Basic structured logs and experiment notes tied to intake references. |
| `Pilot` | Deterministic integration-harness runs, negative-path checks, and rollback rehearsal coverage. | Rail-specific metrics, error-rate tracking, and pilot health dashboards or equivalent evidence. |
| `Partner` | Partner-boundary contract tests, dependency-failure simulations, and evidence of partner acceptance criteria. | Cross-boundary tracing, SLA/SLO checkpoints, and dependency health alerts. |
| `Build-now` | Production-path end-to-end tests, release-gate suite coverage, and fail-closed verification tests. | Full production telemetry (logs, metrics, alerts), incident runbook linkage, and release monitoring evidence. |

## Cross-repo handoff map

| Surface | Primary responsibility | Handoff requirement |
| --- | --- | --- |
| `conxian-gateway` | Owns protocol-adapter implementation and provider/node integration paths. | Intake lane context, target adapter interface, and promotion blockers must be carried into implementation issues/PRs. |
| `conxius-platform` | Owns integration harness/runtime composition, rehearsal environments, and observability wiring. | Lane-specific test/observability requirements must be reflected in harness plans and validation artifacts. |
| `lib-conxian-core` | Owns reusable interfaces and shared verification primitives used across adapters. | Interface changes must be explicitly handed off with compatibility expectations for gateway and platform consumers. |

This handoff model preserves Conxian protocol boundaries while keeping Conxius runtime tooling aligned to lane maturity evidence.
