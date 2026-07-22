# Registration Fee Audit & Roadmap (Issue #504)

**Status:** Phase 3 bounded candidate implemented locally: a canonical,
fail-closed registration-compliance read-only gate. The registration-fee
escrow manager, fee configuration, activation lifecycle, revenue split, and
deployment are **not implemented by this change**.

**Evidence baseline:** `origin/main` at
`d9aa09d281886f0efabc0b78416e1d373eae03cf`, reviewed on 2026-07-22.

## 1. Scope and research question

Issue [#504](https://github.com/Conxian/Conxian/issues/504) asks for paid user,
protocol, and integration registration. The repository already contains a
usage-billing foundation for integrations, but it does not contain one
registration lifecycle that combines payment, compliance, refundable escrow,
activation, and exactly-once revenue routing.

This session deliberately selected the smallest safe dependency: make the
compliance decision canonical before adding money movement. The implemented
API is:

```clarity
(is-registration-compliant
  (user principal)
  (minimum-kyc-level uint))
;; -> (response bool uint)
```

It lives in `compliance-manager.clar`, because that contract owns the existing
freshness-bearing `compliance-records` map. The gate combines that record with
the authoritative `kyc-registry` record-presence, tier, and sanction decision.
Future registration-fee code should consume this result rather than
recomposing KYC, sanctions, registry-presence, and freshness checks from
separate contracts.

## 2. Evidence-based gap map

| Area | Repository evidence | Verified gap | Phase 3 disposition |
|---|---|---|---|
| Canonical compliance decision | [`compliance-manager.clar`](../contracts/compliance/compliance-manager.clar) stores `kyc-level`, the legacy `sanctions-checked` field, and `last-updated`; [`kyc-registry.clar`](../contracts/identity/kyc-registry.clar) stores authoritative tier and sanction flags. | No single read-only API combined both sources with explicit registry record presence. | **Implemented:** `is-registration-compliant` requires both sources. |
| Existing split hooks | [`compliance-hooks.clar`](../contracts/compliance/compliance-hooks.clar) exposes KYC/AML checks and `verify-kyc`; `verify-kyc` updates the manager record but not the registry. | A hook-only path cannot prove authoritative registry presence. | Preserved for compatibility; the gate fails closed until registry evidence exists. |
| Clean-screen meaning | `sanctions-checked` has historical callers that use `false` for “not attested” and `is-compliant` treats `true` as acceptable. | The field is ambiguous as the registration gate's source of truth. | **Implemented:** the gate ignores the field and uses `kyc-registry.is-sanctioned`; positive legacy writes are restricted to the configured sanctions provider. |
| Freshness | `VALIDITY_PERIOD` is `u144`; manager updates use `burn-block-height`. | No registration-specific boundary API existed. | **Implemented:** `0 <= current - last-updated <= 144`; exact `144` is valid, `145` is stale, and a future timestamp fails closed. The future branch is retained defensively but is not directly fixture-tested. |
| Minimum tier | Manager and registry store numeric tiers; existing minimum behavior starts at `u1`. | No explicit rejection for invalid caller/configured minimum or out-of-range stored tiers. | **Implemented:** both stored tiers must be within `u1-u3` and meet the requested minimum; invalid minimums return `ERR_INVALID_MINIMUM_KYC_LEVEL` (`u3003`). |
| Registration payment | No registration-fee manager or registration-specific escrow map exists in `Clarinet.toml` or the simnet plan. | No exact-payment, escrow, refund, finalization, or liability accounting path. | Deferred; do not move funds in this phase. |
| Integration foundation | [`integration-registry.clar`](../contracts/integrations/integration-registry.clar) and [`integration-fee-collector.clar`](../contracts/integrations/integration-fee-collector.clar) support usage billing and exact STX settlement. | Usage settlement is not an upfront refundable registration lifecycle. | Reuse is a later design input, not evidence that registration fees exist. |
| Revenue destination | [`CXIP-013.md`](../CXIP-013.md) says registration fees are 100% vault recycling. Issue #504's initial text says bounty/operations treasury. | The two statements are a policy conflict; no approved registration-specific split exists. | **Deferred:** no split or destination was chosen or encoded. |
| Deployment | Existing deployment generation includes the compliance contracts, but no registration-fee contract exists to deploy. | The new manager-to-registry read-only dependency must remain ordered after `kyc-registry`. | No contract set or registration-fee deployment was added; dependency ordering is kept explicit in the active/legacy Clarinet configs and generated release plans. |
| Documentation truth | Revenue documents describe supported integration fees and CXIP-013 flows, but do not clearly state that registration fees are absent. | Readers could mistake roadmap language for an implemented billing path. | **Implemented:** this roadmap plus explicit revenue/economics status notes. |

## 3. Candidate selection and transparent score

The selected candidate was scored against the actual repository state, not a
claim that the full registration product is complete. Each criterion is rated
from `0` (does not satisfy) to `5` (strongly satisfies). The weighted score is:

```text
score = 20 * (
  0.35 * safety_and_fail_closed
  + 0.25 * phase_scope_fit
  + 0.20 * existing_state_reuse
  + 0.10 * testability
  + 0.10 * policy_isolation
)
```

| Candidate | Safety / fail-closed (35%) | Phase scope fit (25%) | Existing state reuse (20%) | Testability (10%) | Policy isolation (10%) | Score |
|---|---:|---:|---:|---:|---:|---:|
| **Canonical read-only gate in `compliance-manager.clar`** | 5 | 5 | 5 | 5 | 5 | **100** |
| Separate new compliance gate contract | 4 | 3 | 2 | 4 | 5 | 69 |
| Full registration-fee manager before policy decisions | 2 | 1 | 4 | 2 | 1 | 41 |

The canonical gate wins because it adds no asset movement, reuses the existing
freshness-bearing record, checks an authority-owned registry instead of
reinterpreting a legacy boolean, makes invalid configuration explicit, and
isolates the unresolved fee and revenue policy decisions. The score is a
planning heuristic, not a security audit rating or implementation percentage.

## 4. Open-issue dependency context

The prior review reported 25 open GitHub work items and specifically omitted
pull requests [#535](https://github.com/Conxian/Conxian/pull/535),
[#537](https://github.com/Conxian/Conxian/pull/537),
[#540](https://github.com/Conxian/Conxian/pull/540),
[#541](https://github.com/Conxian/Conxian/pull/541), and
[#542](https://github.com/Conxian/Conxian/pull/542). An exact refresh at
**2026-07-22T14:24:50Z** returned **27 open GitHub work items: 20 issues and 7
pull requests**. The two additional open pull requests observed during this
refresh are [#543](https://github.com/Conxian/Conxian/pull/543) and
[#544](https://github.com/Conxian/Conxian/pull/544). This timestamped snapshot
is intentionally explicit about drift: it is a point-in-time inventory, not a
promise that the count will remain 27. Pull requests are included because the
reported omissions were pull requests; this table does not imply that every
open item is a registration dependency.

`dependency-graph.json` was synchronized manually from the active
`Clarinet.toml` because repository inspection found no dependency-graph
generator. The patch adds the manifest's `compliance-manager -> kyc-registry`
edge and preserves the existing `compliance-hooks` manifest dependencies.

| Work item | Class | Relationship to registration fees |
|---|---|---|
| [#544](https://github.com/Conxian/Conxian/pull/544) | Adjacent | Scheduled protocol-fee collector and KPI specification; informs fee custody and reporting but is not registration-specific. |
| [#543](https://github.com/Conxian/Conxian/pull/543) | Independent | Risk-manager orchestration; no registration-gate dependency. |
| [#542](https://github.com/Conxian/Conxian/pull/542) | Adjacent | Enterprise subscription billing and KYC/AML purchase gates; a separate commercialization surface. |
| [#541](https://github.com/Conxian/Conxian/pull/541) | Independent | CXLP mint/burn authorization; unrelated to registration compliance or fee policy. |
| [#540](https://github.com/Conxian/Conxian/pull/540) | Independent | CXLP custody/reconciliation primitives; unrelated to this gate. |
| [#538](https://github.com/Conxian/Conxian/issues/538) | Adjacent | Revenue-automation policy handoff; may affect a downstream revenue boundary. |
| [#537](https://github.com/Conxian/Conxian/pull/537) | Adjacent | Fail-closed deployment receipt verification; relevant to future production proof, not gate semantics. |
| [#536](https://github.com/Conxian/Conxian/issues/536) | Independent | CLP custody/accounting work; outside this phase and not a registration dependency. |
| [#535](https://github.com/Conxian/Conxian/pull/535) | Adjacent | Documentation/session-state automation; may update evidence hygiene but does not change registration behavior. |
| [#532](https://github.com/Conxian/Conxian/issues/532) | Adjacent | Partnership security, legal, and commercialization launch gate; a future release dependency. |
| [#531](https://github.com/Conxian/Conxian/issues/531) | Adjacent | Partnership deployment wiring and receipt verification; relevant to future launch proof. |
| [#530](https://github.com/Conxian/Conxian/issues/530) | Adjacent | Partnership gateway, SDK, and indexing; adjacent external integration surface. |
| [#529](https://github.com/Conxian/Conxian/issues/529) | Adjacent | Partner usage ledger and split settlement; explicitly separate from registration-fee policy. |
| [#528](https://github.com/Conxian/Conxian/issues/528) | Adjacent | Partner registry and versioned fee policy; useful policy precedent, not a registration implementation. |
| [#527](https://github.com/Conxian/Conxian/issues/527) | Adjacent | Partnership fee/legal/asset-scope decisions; unresolved commercial policy context. |
| [#526](https://github.com/Conxian/Conxian/issues/526) | Adjacent | ALEX production activation; may affect downstream route verification, not this read-only gate. |
| [#515](https://github.com/Conxian/Conxian/issues/515) | Adjacent | Main-branch merge gates and CODEOWNERS; process dependency for a future PR. |
| [#507](https://github.com/Conxian/Conxian/issues/507) | Independent | sBTC vault completion; unrelated asset scope. |
| **[#504](https://github.com/Conxian/Conxian/issues/504)** | Direct | **Target issue: registration-fee lifecycle and compliance integration.** |
| [#503](https://github.com/Conxian/Conxian/issues/503) | Direct | Enterprise subscription monetization; a directly competing commercialization policy surface. |
| [#501](https://github.com/Conxian/Conxian/issues/501) | Independent | Dual stacking orchestrator; unrelated to the registration gate. |
| [#500](https://github.com/Conxian/Conxian/issues/500) | Independent | Production oracle configuration and DEX wiring; unrelated to this compliance record. |
| [#498](https://github.com/Conxian/Conxian/issues/498) | Independent | Risk-manager work; no direct registration dependency. |
| [#496](https://github.com/Conxian/Conxian/issues/496) | Direct | Partnership-fee umbrella plan; directly relevant to the unresolved fee boundary. |
| [#488](https://github.com/Conxian/Conxian/issues/488) | Direct | Proposed 2% fee and 50/30/20 split; direct evidence of unresolved/conflicting fee economics. |
| [#480](https://github.com/Conxian/Conxian/issues/480) | Adjacent | Sandbox truthfulness and proof path; relevant to not claiming unavailable billing flows. |
| [#468](https://github.com/Conxian/Conxian/issues/468) | Independent | Incomplete CXLP accounting primitive; broader accounting risk outside this phase. |

Direct policy dependencies are [#504](https://github.com/Conxian/Conxian/issues/504),
[#488](https://github.com/Conxian/Conxian/issues/488),
[#496](https://github.com/Conxian/Conxian/issues/496), and
[#503](https://github.com/Conxian/Conxian/issues/503). The remaining links are
adjacent context, release/process work, or independent protocol work; none is
silently treated as completed by this change. At this snapshot there are 4
direct, 14 adjacent, and 9 independent items.

## 5. Decisions and defaults for the bounded candidate

- **Contract location:** enhance `compliance-manager.clar`; do not create a
  duplicate compliance state machine.
- **API shape:** return `(response bool uint)`. Valid configuration returns
  `(ok true|false)`; invalid minimum tier returns a stable error.
- **Minimum tier:** caller/configuration must supply `u1`, `u2`, or `u3`.
  `u0` and values above `u3` are invalid, not implicit “no requirement.”
- **Trust model:** the gate requires a fresh manager record, manager tier in
  `u1-u3`, an existing `kyc-registry` record, a registry tier in `u1-u3`, both
  tiers at or above the requested minimum, and
  `kyc-registry.is-sanctioned == false`.
- **Legacy clean-screen field:** `sanctions-checked` is retained for existing
  APIs but is not consumed by the registration gate. `false` remains valid for
  the normal `verify-kyc` update path; `true` may be written only by the
  configured sanctions provider.
- **Hook integration:** `compliance-hooks.verify-kyc` creates or refreshes the
  manager record with `sanctions-checked=false`; it does not create the
  authoritative KYC record. The gate therefore returns `ok(false)` until the
  KYC-registry admin writes a matching status.
- **Freshness:** the existing `VALIDITY_PERIOD` of `u144` burn blocks is used;
  the boundary is inclusive. `burn-block-height` is the slow-path clock for
  this attestation window.
- **Missing or malformed state:** missing records, low tiers, non-clean records,
  stale records, and records with a future timestamp all return `ok false`.
- **Backward compatibility:** existing function signatures remain available;
  `verify-kyc` now propagates manager errors instead of panicking, while its
  normal false-flag update behavior remains unchanged.
- **Economic boundary:** no registration fee amount, refund policy, escrow,
  activation, revenue split, or deployment plan is selected here.
- **Data minimization:** the gate consumes existing on-chain fields and adds no
  PII, raw credentials, or external sanctions-list data.

These defaults describe protocol behavior for this gate; they are not a legal
certification or a substitute for jurisdiction-specific compliance review.

## 6. Phased implementation plan

### Phase 0 — Research and policy lock

1. Reconcile issue #504 with [CXIP-013](../CXIP-013.md), especially the
   registration-fee destination.
2. Decide registration types, fee amounts, asset scope, refund window,
   activation timing, and authority model.
3. Decide whether each registration type uses the same minimum tier or a
   versioned per-type policy.

### Phase 3 — Bounded compliance candidate (this change)

1. Add one canonical read-only gate in `compliance-manager.clar`.
2. Reject invalid minimum tiers explicitly.
3. Test owner/approved-provider writes, unauthorized writers, configured
   sanctions-provider authority, missing/low/malformed/sanctioned registry
   evidence, stale and exact-boundary behavior, and the normal
   `compliance-hooks.verify-kyc` path.
4. Record the gap map, score, dependencies, and non-goals in this document.

### Phase 4 — Registration-fee manager (deferred)

Only after policy approval, add one STX-first manager with:

- versioned per-type configuration and immutable registration snapshots;
- exact STX escrow with a pending-liability invariant;
- owner-only full refund through an explicitly defined deadline;
- permissionless finalization only after the deadline;
- activation and revenue routing that either complete atomically or revert;
- exactly-once terminal transitions and replay protection;
- no generic admin withdrawal of pending escrow;
- the canonical compliance gate called before funds move.

### Phase 5 — Deployment and launch proof (deferred)

Reconcile `Clarinet.toml`, simnet plans, testnet/mainnet plans, release
manifests, wiring calls, receipts, and interface checks. A plan or workflow
success must not be reported as an on-chain deployment.

## 7. Acceptance criteria

### Phase 3 candidate — satisfied by this change

- A single read-only API combines a fresh manager record with authoritative
  KYC-registry record presence, minimum tier, and non-sanctioned status.
- Invalid minimum tiers return a deterministic error.
- Exact freshness boundary (`144`) is accepted; the next block is rejected.
- Missing, low-tier, malformed, sanctioned, and stale evidence fails closed.
- Owner, approved-provider, configured-sanctions-provider, unauthorized-writer,
  and `verify-kyc` behaviors are regression-tested.
- The future-height guard remains in production code but is explicitly not
  claimed as directly fixture-tested because no production API can create a
  future-dated manager record without weakening the trust boundary.
- No fee manager, revenue split, deployment plan, issue closure, or external
  comment is added.

### Future manager — not satisfied by this change

- Exact payment, escrow solvency, refund, finalization, activation, routing,
  replay, pause, overflow, rollback, and post-condition tests.
- Approved fee policy and revenue destination.
- Testnet receipts and production deployment verification.

## 8. Deferred policy decisions

1. Fee amounts for user, protocol, and integration registrations.
2. Whether registration types are `u1/u2/u3` and whether that mapping is
   versioned on-chain.
3. Refund window length, deadline inclusivity, and who may claim.
4. Whether activation is delayed until the refund window expires.
5. Revenue destination: CXIP-013 vault recycling versus the issue's earlier
   bounty/operations wording.
6. STX-only scope versus SIP-010 support, including decimals, whitelisting,
   accounting units, and per-asset routing.
7. Registration target identity, duplicate rules, and hash/PII boundaries.
8. External sanctions-list provenance, refresh cadence, and appeal handling;
   the on-chain authority boundary for positive legacy attestations is already
   enforced by `set-sanctions-provider`.
9. Whether a registration-specific policy stores minimum tiers on-chain or
   passes them from an approved configuration caller.
10. Legal, jurisdictional, tax, and consumer-refund requirements.

## 9. Primary sources and repository evidence

- [Issue #504](https://github.com/Conxian/Conxian/issues/504) — current
  registration-fee request and research thread.
- [`compliance-manager.clar`](../contracts/compliance/compliance-manager.clar)
  — source of truth for the implemented gate and `VALIDITY_PERIOD`.
- [`compliance-hooks.clar`](../contracts/compliance/compliance-hooks.clar) —
  existing KYC/AML APIs plus the compatibility `verify-kyc` update path.
- [`kyc-registry.clar`](../contracts/identity/kyc-registry.clar) — authoritative
  record-presence, tier, and sanction semantics used by the gate.
- [`integration-registry.clar`](../contracts/integrations/integration-registry.clar)
  and [`integration-fee-collector.clar`](../contracts/integrations/integration-fee-collector.clar)
  — existing usage-fee foundation, not a registration escrow lifecycle.
- [`CXIP-013.md`](../CXIP-013.md) — repository-authored registration-fee
  destination language.
- [Stacks Clarity keywords](https://docs.stacks.co/reference/clarity/keywords)
  — `burn-block-height` reference.
- [Stacks Clarity types](https://docs.stacks.co/reference/clarity/types) and
  [functions](https://docs.stacks.co/reference/clarity/functions) — response,
  lazy boolean, and safe error-return semantics used by the gate.
- [NIST SP 800-63 Digital Identity Guidelines](https://pages.nist.gov/800-63-4/)
  — official U.S. government guidance on identity proofing, authentication, and
  federation; relevant to the gate's identity-assurance boundary, but not a
  sanctions-list or legal-compliance determination.
- [OFAC Sanctions List Service](https://ofac.treasury.gov/sanctions-list-service)
  — primary U.S. sanctions-list source; the current contract's gate does not
  ingest this list on-chain and instead relies on the authority-owned
  `kyc-registry` flag.
