# Conxian: A Sovereign-First Financial Operating System for Bitcoin

> **Technical Whitepaper Outline**
> **Issue**: [#827](https://github.com/Conxian/conxian-business/issues/827)
> **Status**: Outline (draft)
> **Version**: 1.0-draft
> **Last updated**: 2026-07-03

---

## Purpose

This document is the outline for the flagship Conxian technical whitepaper. The finished whitepaper will serve as the single authoritative technical artifact for evaluators, advanced partners, and technical diligence — explaining the full system without requiring repo-by-repo reading.

**Target audience**: Technical evaluators, compliance reviewers, institutional partners, advanced developers, and security auditors.

**Design principles for the finished paper**:
- Implemented vs target-state distinctions are explicit in every section
- Protocol, support, business, and public-interface layers are clearly separated
- Trust boundaries and dependencies are explicit
- Zero-custody, zero-raw-data doctrine is preserved throughout
- Claims are evidence-backed (each claim references a verifiable artifact)

---

## Outline

### Abstract (150 words)

- What Conxian is: A sovereign-first, non-custodial financial operating system built directly on Bitcoin
- Core innovation: BOS (Business Operations System) as a programmatic state machine with cryptographic proof of correct operation
- Key differentiators: Hardware-enforced sovereignty (TEE/StrongBox), Zero Secret Egress, BitVM2-verified cross-chain state, ISO 20022 compliance without custody
- Current maturity: Conxius Wallet (Stable), Nexus (Beta), Gateway (Beta), ConxianCSF (pre-mainnet, gated on ALEX funding)

> **Evidence**: [TRUST_AND_READINESS_VERIFICATION.md]

---

### 1) Introduction & Motivation (2 pages)

#### 1.1 The Sovereignty Gap
- Existing financial infrastructure: custodial by default, centralized trust anchors
- Bitcoin solves monetary sovereignty; does not solve operational sovereignty
- The gap: enterprises need Bitcoin-native financial operations without surrendering key custody

#### 1.2 Design Philosophy
- Sovereignty by Design: cryptographic keys never leave user hardware
- Zero Secret Egress: sensitive logic in secure enclaves, not in source code
- Fail-Closed: every privileged workflow must prove validity or abort
- Open-Core: core protocols and verification are public; operational runbooks are internal

#### 1.3 Scope of This Paper
- What is covered: system architecture, protocol layers, trust model, security invariants, current implementation state
- What is not covered: detailed API reference, deployment runbooks, pricing, forward-looking roadmap commitments

> **Evidence**: [AGENTS.md], [TRUST_AND_PROOF_MESSAGING.md], [DEVELOPER_QUICKSTART.md]

---

### 2) System Architecture (4 pages)

#### 2.1 The Five-Plane Model
- **Bitcoin Settlement Plane**: L1 finality, BitVM2 verification, DLC bonds
- **Protocol Plane**: Clarity smart contracts (CSF), sovereign treasury, fiscal vault oracle
- **Execution Plane**: Nexus multi-protocol engine (Bitcoin, EVM, Cosmos, Stacks, Lightning, RGB)
- **Compliance Plane**: Gateway ISO 20022 pipeline, ZKC (Zero-Knowledge Compliance)
- **Client Plane**: Conxius Wallet (StrongBox/TEE), Conxian UI (dashboard)

> **Evidence**: [THREE_LANE_RUNTIME_DEPLOYMENT_ARCHITECTURE.md §3]

#### 2.2 Three Deployment Lanes
- Community sovereign-node (self-hosted)
- Business-managed (managed hosting + shared controls)
- Enterprise / private-cloud (customer-operated control plane)

> **Evidence**: [THREE_LANE_RUNTIME_DEPLOYMENT_ARCHITECTURE.md]

#### 2.3 Cross-Chain State Verification
- MMR (Merkle Mountain Range) proofs for state root commitments
- BitVM2 Groth16 verification for Bitcoin L1 state
- Protocol adapters: EVM receipt verification, Cosmos IBC update verification, Stacks transaction verification

> **Evidence**: [conxian-nexus/src/api/rest.rs], [lib-conxian-core]

#### 2.4 Ecosystem Repository Map
- Flagship repos: Conxius Wallet, Conxian Gateway, Conxian Core Protocol, Conxian Labs Site, Conxius Platform
- Supporting repos: Nexus, lib-conxian-core, Conxius Enclave SDK, Conxius Orbit, Conxian UI

> **Evidence**: [REPO_PORTFOLIO.md]

---

### 3) The BOS: Business Operations as a State Machine (3 pages)

#### 3.1 Unified Theory v2.0
- Four governing variables: C_R (Cost of Reproduction), O_C (Opportunity Cost), V_X (Execution Velocity), A_S (System Autonomy)
- Four-phase lifecycle: Genesis → Forge → Transition → Sovereign State
- Current phase: Transition (Phase 3), driving O_C → 0

> **Evidence**: [CONXIAN_UNIFIED_THEORY_v2.md]

#### 3.2 Programmatic Governance
- Promotion pipeline: dev → staged → main with CI enforcement
- Contamination guard: zero hardcoded testnet principals in production contracts
- Sovereign-First Deployment Mandate: dynamic principals via operational-treasury.clar

> **Evidence**: [AGENTS.md § Sovereign-First Deployment Mandate], [verify_contamination_guard.py]

#### 3.3 Operational Metrics
- C_R: Structural moat (TEE coverage × Clarity complexity × compliance integration)
- O_C: Manual overhead on critical-path workflows
- V_X: AI and tooling leverage (completed weighted scope / median cycle time)
- A_S: Automated recurring runs / total recurring runs
- N_E: Network effects (participant uplift)

> **Evidence**: [CON-682_APPROVED_METRIC_SPEC.md]

---

### 4) Security & Trust Model (3 pages)

#### 4.1 Cryptographic Sovereignty
- Hardware-enforced key custody: Android StrongBox, TPM 2.0, TEE
- Attestation-gated access: verifiable attestation chain before session issuance
- Short-lived, capability-scoped session credentials
- No bearer tokens for privileged surfaces

> **Evidence**: [BOS_SOVEREIGN_ENTERPRISE_IDENTITY_ARCHITECTURE.md]

#### 4.2 Zero Secret Egress (ZSE)
- Three-layer rule: Secrets → Linear/Supabase; On-chain → State-proof primitives only; Stubs → fail-closed with `err-u501` / `err-u503`
- Contamination guard: production-track .clar files scanned for testnet/simnet principals; build breaks on violation

> **Evidence**: [AGENTS.md § ZSE], [BOUNDARY_DECISION_LOG.md]

#### 4.3 Trust Boundaries
- What is claimed: verifiable CI pipeline, ZSE compliance, cryptographic proof of state, honest maturity labeling
- What is NOT claimed: third-party audits, production SLAs, full decentralization, payable bug bounties

> **Evidence**: [TRUST_AND_READINESS_VERIFICATION.md §4]

#### 4.4 Supply Chain Integrity
- Submodule pin integrity audit (daily)
- Action version audit (all GitHub Actions SHA-pinned)
- LTS compliance verification
- Repo hygiene suite (ZSE + submodules)

> **Evidence**: [Conxian Unified CI workflow], [scripts/verify_*.py]

---

### 5) Protocol Layer: ConxianCSF (3 pages)

#### 5.1 Smart Contract Architecture
- 16+ Clarity contracts (clarity-version=4, epoch=latest)
- Core contracts: bridge-nft, yield-optimizer, payment-forge, jurisdictional-sharding
- Dynamic principals via operational-treasury.clar

> **Evidence**: [Conxian/], [conxius-orbit/rebuild_toml.py]

#### 5.2 Oracle System
- PPP (Purchasing Power Parity) tracking across fiat corridors
- Signed state updates via ContractBridge::create_signed_call
- Real Wallet signing (ORACLE_SERVICE_IS_STUBBED = false)

> **Evidence**: [conxian-nexus/src/oracle/aggregator.rs]

#### 5.3 Fiscal Vault & Treasury
- Sovereign treasury architecture
- Yield optimization with compliance gating
- No direct dashboard-to-contract coupling

> **Evidence**: [BOS_TREASURY_AND_YIELD_INTEGRATION_ARCHITECTURE.md]

#### 5.4 Mainnet Readiness
- Status: Conditional Go (pending ALEX funding verification)
- All P0 blockers remediated: CON-61 (admin centralization), CON-371 (ST→SP), CON-162 (TEE alignment), CON-183 (secret cleanup)
- Bounty payout gated on ConxianCSF mainnet + ALEX funding

> **Evidence**: [CSF_MAINNET_READINESS_GATE.md]

---

### 6) Execution Layer: Conxian Nexus (2 pages)

#### 6.1 Multi-Protocol Engine
- Protocol adapters: Bitcoin (BitVM2), EVM, Cosmos (IBC), Stacks, Lightning, RGB, Fedimint
- NexusExecutor: submit → validate → rebalance lifecycle
- State root commitments via MMR

> **Evidence**: [conxian-nexus/src/executor/]

#### 6.2 API Surface
- REST: 18 routes including /v1/proof, /v1/execute, /v1/bitvm2/verify-state-root, /health
- gRPC: tonic/prost gateway
- Admin API: CRUD, diagnostics, public auth metadata

> **Evidence**: [conxian-nexus/src/api/rest.rs], [DEVELOPER_QUICKSTART.md]

#### 6.3 Storage Layer
- Kwil decentralized SQL
- Tableland sharded persistence
- Safety mode and circuit breakers

> **Evidence**: [conxian-nexus/src/storage/], [conxian-nexus/src/safety/]

---

### 7) Compliance Layer: Conxian Gateway (2 pages)

#### 7.1 ISO 20022 Integration
- pacs.008 message wrapping via Nexus ERP Adapter
- HMAC-SHA256 attestation for OData/ERP translation
- Zero-Knowledge Compliance (ZKC): prove compliance without exposing raw data

> **Evidence**: [conxian-nexus/src/api/erp.rs], [conxian-gateway/]

#### 7.2 Cross-Border Settlement
- x402 settlement pipeline
- Jurisdictional sharding for regulatory compliance
- SYI (Sovereign Yield Index) for cross-fiat corridor pricing

> **Evidence**: [conxian-nexus/src/api/settlement.rs]

---

### 8) Client Layer: Conxius Wallet (2 pages)

#### 8.1 Sovereign-First Wallet Architecture
- Android-first, offline-first design
- Hardware-isolated signing (StrongBox/TEE)
- Non-custodial: keys never leave device

> **Evidence**: [conxius-wallet/README.md]

#### 8.2 Protocol Integration
- Bitcoin L1: on-chain transactions
- Lightning: BOLT 11/12 invoice handling
- Stacks: contract interactions and token management
- RGB: client-side validation
- Fedimint: federated chaumian ecash

#### 8.3 Security Model
- CXN Guardian: privacy-preserving transaction guardian
- Intent review before signing
- Role-based approval controls

> **Evidence**: [conxius-wallet/README.md]

---

### 9) Implementation Maturity (2 pages)

#### 9.1 Current State by Component

| Component | Status | Evidence |
|-----------|--------|----------|
| Conxius Wallet | Stable (v1.9.2) | CI green; versioned releases |
| Conxian Nexus | Beta (v0.4.17) | CI green; stubs removed; oracle active |
| Conxian Gateway | Beta | CI green; ISO 20022 pipeline active |
| ConxianCSF | Pre-mainnet (Go pending ALEX) | All P0 blockers remediated |
| Conxius Enclave SDK | Beta | Hardware enclave abstractions |
| lib-conxian-core | Beta | Clippy + audit enforced |

> **Evidence**: [TRUST_AND_READINESS_VERIFICATION.md §2]

#### 9.2 CI/CD Pipeline
- Conxian Unified CI: 9/9 jobs
- Suites: B2B (Nexus), B2C (Wallet), Core Library, Gateway, Repo Hygiene, Summary Gate
- Promotion pipeline: dev → staged → main with automated verification

> **Evidence**: [DEVELOPER_QUICKSTART.md § CI/CD Pipeline]

#### 9.3 What's Next (without roadmap commitments)
- ConxianCSF mainnet deployment (gated on ALEX funding)
- Community sovereign-node lane (Phase 4 target)
- Lightning coverage expansion (CON-780: 67%→90%)

---

### 10) Conclusion (1 page)

- Conxian is implemented, not aspirational: Wallet is stable; Nexus and Gateway are active Beta
- The BOS is a working state machine with cryptographic proof of correct operation
- ZSE and contamination guard provide verifiable security boundaries
- Open-core with honest maturity labeling: no over-claims, no hidden custody
- For technical diligence: all architecture docs, CI results, and verification artifacts are publicly accessible

---

### Appendices

#### A) Glossary
- BOS, CSF, ZSE, ZKC, SYI, MMR, TEE, DLC, PPP, CJCS, ADR, BOLT

#### B) Repository Index
- All 10 submodules with URLs, SHAs, and roles

#### C) Key Architecture Decision Records
- ADR-001 through ADR-006

#### D) CI Pipeline Evidence
- Representative CI run IDs and results

#### E) References
- All docs cited in this paper with links

---

## Writing Notes

### For each section when drafting:
1. **Start with the implementation state** — what exists today, not what is planned
2. **Mark target-state elements explicitly** — "[Target-state]" prefix for anything not yet implemented
3. **Reference evidence** — every architectural claim links to a public artifact (source file, CI run, spec)
4. **Honest about maturity** — use the status taxonomy: Incubating, Beta, Stable, Deprecated
5. **ZSE compliance** — no secrets, no operational runbooks, no privileged identifiers

### Sections that need additional research before drafting:
- §5.2 Oracle economics and PPP methodology (currently stub in Git; canonical in Linear)
- §7.2 SYI pricing model details (implementation detail in Linear)
- §8.2 Complete protocol integration matrix (needs wallet team input)
- §5.3 Fiscal vault mechanics (canonical in Linear per ZSE)

### Target length: 25-30 pages (including diagrams and appendices)

---

## Related Documents

- [Conxian Unified Theory v2.0](CONXIAN_UNIFIED_THEORY_v2.md)
- [Developer Quickstart & Architecture Guide](DEVELOPER_QUICKSTART.md)
- [Trust & Readiness Verification](TRUST_AND_READINESS_VERIFICATION.md)
- [Trust & Proof Messaging](TRUST_AND_PROOF_MESSAGING.md)
- [Three-Lane Runtime Deployment Architecture](architecture/THREE_LANE_RUNTIME_DEPLOYMENT_ARCHITECTURE.md)
- [BOS Sovereign Enterprise Identity Architecture](architecture/BOS_SOVEREIGN_ENTERPRISE_IDENTITY_ARCHITECTURE.md)
- [BOS Treasury & Yield Integration Architecture](architecture/BOS_TREASURY_AND_YIELD_INTEGRATION_ARCHITECTURE.md)
- [CSF Mainnet Readiness Gate](CSF_MAINNET_READINESS_GATE.md)
- [Repo Portfolio](REPO_PORTFOLIO.md)
