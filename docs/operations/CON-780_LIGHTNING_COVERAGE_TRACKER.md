# CON-780 Lightning Coverage Tracker (GAP-009)

## Context links

- Linear issue: [CON-780](https://linear.app/conxian-labs/issue/CON-780/expand-lightning-test-coverage-from-67percent-to-90percent-gap-009)
- Umbrella tracker (business): [conxian-business#723](https://github.com/Conxian/conxian-business/issues/723)
- Nexus execution issue (service layer): [conxian-nexus#104](https://github.com/Conxian/conxian-nexus/issues/104)
- Gateway execution issue (adapter layer): [conxian-gateway#117](https://github.com/Conxian/conxian-gateway/issues/117)

## Ownership split (Lightning coverage boundary)

| Area | Primary owner | Coverage focus | Execution issue |
| --- | --- | --- | --- |
| Nexus service-layer coverage | conxian-nexus team | Lightning domain behavior, business rules, persistence and retry semantics, service-level error handling | [conxian-nexus#104](https://github.com/Conxian/conxian-nexus/issues/104) |
| Gateway adapter-layer coverage | conxian-gateway team | Adapter/protocol boundary behavior, upstream integration failures, payload/response validation, transport-level retries | [conxian-gateway#117](https://github.com/Conxian/conxian-gateway/issues/117) |

## Shared Lightning test matrix (agreed baseline: 10 scenarios)

| # | Scenario | Nexus service-layer tests | Gateway adapter-layer tests |
| --- | --- | --- | --- |
| 1 | Happy-path payment create/settle | Validate state transitions and settlement lifecycle | Validate request/response mapping for create + settle paths |
| 2 | Invoice generation/lookup/paid transition | Validate invoice state machine lifecycle | Validate adapter lookup + paid callback/event translation |
| 3 | Timeout/expired invoice | Validate expiry detection and terminal state handling | Validate upstream timeout/expiry mapping to canonical errors |
| 4 | Insufficient liquidity/routing failure | Validate domain error classification and fallback behavior | Validate routing failure payload translation and retry policy |
| 5 | Duplicate/idempotency | Validate duplicate create/pay idempotency keys and safe replay | Validate upstream duplicate response normalization |
| 6 | Upstream unavailability/retry | Validate bounded retries, backoff, and terminal failure behavior | Validate transport retries/circuit-breaker integration behavior |
| 7 | Invalid/malformed input rejection | Validate schema/business validation rejection | Validate adapter input sanitization and upstream payload guards |
| 8 | Partial failure + error propagation | Validate mixed-success rollback/compensation semantics | Validate partial upstream failure translation with preserved context |
| 9 | Persistence/state reconciliation after restart/retry | Validate persisted state recovery and replay safety | Validate adapter state handoff consistency across restart/retry |
| 10 | Observability assertions (logs/metrics/coverage artifact in CI) | Validate structured logs/metrics emitted for core paths | Validate adapter telemetry + PR-level coverage artifact publication |

## Milestones and evidence

| Milestone | Objective | Minimum evidence | Status |
| --- | --- | --- | --- |
| M0 | Scope + boundary confirmed | Ownership split accepted in this tracker + linked in [conxian-business#723](https://github.com/Conxian/conxian-business/issues/723) | Active |
| M1 | Tests added | PRs linked from [conxian-nexus#104](https://github.com/Conxian/conxian-nexus/issues/104) and [conxian-gateway#117](https://github.com/Conxian/conxian-gateway/issues/117) showing new matrix coverage | Planned |
| M2 | CI fail-under gate active (>=90% scoped) | CI config enforces `>=90%` on scoped Lightning modules with failing build on regressions | Planned |
| M3 | PR-level coverage artifact/reporting active | Every Lightning PR publishes coverage artifact/report with Nexus + Gateway scoped visibility | Planned |

## Shared definition of done

- All 10 shared matrix scenarios are covered by automated tests across Nexus service-layer and Gateway adapter-layer boundaries.
- [conxian-nexus#104](https://github.com/Conxian/conxian-nexus/issues/104) and [conxian-gateway#117](https://github.com/Conxian/conxian-gateway/issues/117) are both closed with linked evidence and traceability back to [conxian-business#723](https://github.com/Conxian/conxian-business/issues/723) and [CON-780](https://linear.app/conxian-labs/issue/CON-780/expand-lightning-test-coverage-from-67percent-to-90percent-gap-009).
- Scoped Lightning coverage gate is enforced in CI at `>=90%` with fail-under behavior.
- PR-level coverage artifacts are generated for Lightning changes and retained for review.
- No open P1 regressions remain for GAP-009 in the production-readiness roadmap.
