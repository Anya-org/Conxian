# BOS preserve / enhance / replace gap matrix (CON-443)

**Date:** 2026-04-16

This document is the BOS control matrix for deciding when to **preserve**, **enhance**, **replace**, or **defer** a major BOS component.

It is meant to:

- prevent duplicate or destructive refactors across repos/submodules
- make upgrade sequencing explicit (what must be stabilized first)
- keep trust boundaries intact (dashboards propose/observe; BOS executes/proves)

## Decision legend

- **Preserve**: keep the component and its responsibility intact; only do hygiene/bugfixes.
- **Enhance**: keep the component, but add capabilities or close documented gaps.
- **Replace**: migrate responsibilities to a different component or target-state design (usually with a temporary compatibility period).
- **Defer**: explicitly do not work this surface yet (avoid partial refactors that create drift).

> Composite decisions (for example: **Preserve + Enhance (in Linear)**) indicate a split between the current on-repo posture and the target state. Use the first verb for the current repo posture and the second for the target architecture or canonical Linear artifacts.

## Sequencing rules (non-negotiable)

These rules assume, and do not override, the global invariants in `docs/architecture/THREE_LANE_RUNTIME_DEPLOYMENT_ARCHITECTURE.md` (canonical truth on-chain, signed/replay-resistant events, dynamic principals, no dashboard-to-contract coupling, fail-closed behavior).

1. **CSF-first proof gates are upstream of distribution**
   - See `docs/CSF_FIRST_OPERATING_SEQUENCE_AND_PROOF_GATES.md`.
2. **No dashboard-to-contract coupling**
   - See `docs/architecture/BOS_TREASURY_AND_YIELD_INTEGRATION_ARCHITECTURE.md`.
3. **Dynamic principals (no hardcoded production addresses)**
   - On-chain execution surfaces must resolve principals via `operational-treasury` (see the architecture doc above).
4. **Fail closed**
   - Functional stubs must return explicit service errors (no mock success paths).

## Gap matrix

| Component | Current responsibility | Known strengths | Upgrade gaps / risks | Decision | Sequencing notes |
| --- | --- | --- | --- | --- | --- |
| **BOS integration boundary** (`docs/architecture/BOS_TREASURY_AND_YIELD_INTEGRATION_ARCHITECTURE.md`) | Canonical intent-based boundary for treasury/yield; defines trust boundaries and reconciliation model | Clear invariants (“dashboards propose/observe; BOS executes/proves”); explicit fail-closed rules | Needs to be kept aligned as services evolve (avoid “tribal knowledge” drift) | **Preserve** | Update this doc first when adding new treasury/yield execution surfaces |
| **CSF-first sequencing gates** (`docs/CSF_FIRST_OPERATING_SEQUENCE_AND_PROOF_GATES.md`) | Locks the operating order (CSF → economy → gateway) to prevent claim drift | Prevents premature distribution/refactors that outpace proof | Gate evidence must stay linkable and commit-pinned | **Preserve** | Treat as the upstream constraint for any “Gateway/Wallet/UI” work |
| **On-chain protocol (Conxian)** (`Conxian/`) | Core protocol primitives and execution contracts (CSF, control surfaces, automation) | Strong on-chain-first posture; explicit governance and recovery docs | **Dynamic principal** contamination risk (no hardcoded principals); submodule pin drift can invalidate audits | **Enhance** | Must be stabilized before expanding BOS execution and any “broadcast” surfaces |
| **Shared core primitives** (`lib-conxian-core/`) | Shared models, crypto/proof primitives, and conventions used by Gateway/Nexus/Wallet | Centralizes shared types and proof conventions | Ensure BitVM2 / state-proof integration stays aligned to the SNARK-based state proof standard; avoid stubs in production paths | **Enhance** | Make core proof/model changes before refactoring Gateway or Nexus call surfaces |
| **State node (Nexus / Glass Node)** (`conxian-nexus/`) | Indexes Stacks L1 state; produces verifiable telemetry and state proofs | Reorg handling, persistent MMR roots, MEV transparency logging | Operator runbooks (state recovery, safety mode thresholds) lag behind implementation; avoid coupling correctness to hosted datastores | **Enhance** | Stabilize state/proof outputs before expanding downstream dashboards or automation |
| **Compliance + ingress gateway** (`conxian-gateway/`) | Sovereign ingress, compliance gating, and API aggregation for external systems | Unified API surface; strong “proposal-only” external trigger posture; broad protocol coverage | Partner onboarding docs and explicit T+0 constraints are incomplete; some ERP sync surfaces remain simulated | **Enhance** | Downstream of CSF gates; do not embed BOS orchestration logic into Gateway |
| **BOS orchestrator (execution coordinator; data plane)** (`Sovereign-Ops-Orchestrator/`) | Intended home for Linear↔BOS wiring and orchestration runbooks (ZSE stubs in repo; canonical in Linear) | ZSE-safe: prevents accidental leakage of operational wiring | Implementation detail is intentionally out of repo; risk is duplicating orchestration logic elsewhere and creating drift | **Preserve + Enhance (in Linear)** | Treat this directory as the canonical pointer; do not spin up “shadow orchestrators” in other repos |
| **Fiscal Vault Oracle** (`Fiscal-Vault-Oracle/`) | Treasury runway/yield control surfaces and oracle publishing (ZSE stubs in repo; canonical in Linear) | Clear separation between public-safe pointers and internal-only operational detail | Current BOS state-layer dependencies (Supabase/hosted SQL) must remain derived-only; checkpointing requirements must be enforced | **Enhance** | Keep it downstream of on-chain truth and Nexus projections; avoid treating off-chain tables as canonical |
| **Policy enforcement / guardian** (`Nakamoto-Guardian/`) | Intended home for compliance/policy enforcement loops (ZSE stubs in repo; canonical in Linear) | Keeps operational enforcement details out of git | Easy to accidentally re-implement policy logic in Gateway/Wallet; creates hard-to-audit divergence | **Preserve + Enhance (in Linear)** | Guardian rules should be upstream of BOS execution, but downstream of CSF gate evidence |
| **Strategy Nexus** (`Sovereign-Strategy-Nexus/`) | Strategy tracking and narrative scaffolding (ZSE stubs in repo; canonical in Linear) | ZSE-safe stubs preserve link targets | Avoid mixing strategy material into product repos; keep it in Linear | **Preserve** | Not on the critical path for mainnet correctness; do not block infra work on strategy artifacts |
| **Wallet (end-user trust boundary)** (`conxius-wallet/`) | Non-custodial signing, intent review, and user-facing protocol UX | StrongBox/TEE boundary; consumes Gateway/Nexus APIs instead of duplicating them | Needs an explicit role-based “who approves what” map and day-2 incident runbooks (internal-only) | **Preserve + Enhance** | Keep regulated/jurisdiction-sensitive flows partner-powered (Gateway), not hardcoded in-app |
| **Platform orchestration / DevEx** (`docs/CONXIUS_PLATFORM_BOS_BUILDOUT.md`) | Reference environment wiring and local orchestration for stack operators | Makes multi-repo wiring reproducible | Needs operator-class deployment guides; avoid making platform scripts a correctness dependency | **Enhance** | Keep “platform” as orchestration, not a source of business truth |
| **BOS state layer (hosted SQL)** (`docs/SAB_MIGRATION_DEPENDENCY_INVENTORY.md`) | Current hosted datastores (Supabase/Neon) used as derived read models and audit surfaces | Fast iteration and observability today | Risk of accidental “off-chain becomes canonical”; sovereignty migration required | **Replace (target-state)** | Replace only after on-chain checkpointing + verifiable projections are in place; until then enforce derived-only semantics |
| **Sovereign persistence pilots (Kwil/Tableland)** (`conxian-nexus/docs/PRD.md`) | Pilot decentralized relational persistence and audit mirroring | Moves toward sovereignty and operator portability | Still a pilot; avoid prematurely depending on it for production correctness | **Enhance + Defer (full cutover)** | Keep pilots parallel until migration readiness gates are met |
| **Grid oracle (agnostic)** (`cxn-grid-oracle/`) | Schema-level oracle surface for grid intelligence signals | Small, public-safe interface contract | Alpha; no production stability guarantees | **Defer** | Safe to iterate as schema docs, but not a BOS critical dependency |
| **Showcase DApp / public web surfaces** (`showcase-dapp/`) | Demonstration and public-facing UI surfaces | Not in the correctness path; can evolve quickly | Risk: accidentally treated as evidence source or operational control plane | **Defer** | Keep downstream of proof gates; ensure it only observes derived state |
