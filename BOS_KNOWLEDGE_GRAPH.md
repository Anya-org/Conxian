# Conxian Labs BOS Knowledge Graph
> Clarity-version: 4 | Epoch: latest | Generated: 2026-07-08

## Overview

This document is the **mandatory BOS Knowledge Graph** referenced in `AGENTS.md`. It provides structured entity extraction for graph-aware traversal by agentic systems.

---

## Entity Registry

### 🏢 Organizations

| Entity | Type | Relationships | Source |
|--------|------|---------------|--------|
| **Conxian-Labs (Pty) Ltd** | Legal Entity | owns: Conxian, Conxius | AGENTS.md |
| **Conxian** | Protocol Brand | implements: CXD, CXLP, CXVG | Conxian repo |
| **Conxius** | Client Brand | provides: Wallet, Platform, Enclave SDK | AGENTS.md |

### 📦 Repositories (Submodules)

| Entity | GitHub | Language | Focus | Status |
|--------|--------|----------|-------|--------|
| `conxian-business` | Conxian/conxian-business | Mixed | Business ops, AGENTS.md | ✅ Active |
| `Conxian` | Conxian/Conxian | Clarity | Smart contracts (221) | ⚠️ 27 issues |
| `conxian-gateway` | Conxian/conxian-gateway | Rust | ISO 20022 bridge | ✅ Active |
| `conxian-nexus` | Conxian/conxian-nexus | Clarity/Rust | Settlement layer | ✅ Active |
| `conxius-wallet` | Conxian/conxius-wallet | TypeScript | Android wallet | ✅ Active |
| `conxius-platform` | Conxian/conxius-platform | TypeScript | Dev orchestration | ✅ Active |
| `conxius-orbit` | Conxian/conxius-orbit | TypeScript | Deployment toolkit | ✅ Active |
| `conxius-enclave-sdk` | Conxian/conxius-enclave-sdk | Rust | TEE abstraction | ✅ Active |
| `conxian-ui` | Conxian/Conxian_UI | TypeScript | UI components | ✅ Active |
| `lib-conxian-core` | Conxian/lib-conxian-core | Rust | Crypto primitives | ✅ Audited |
| `conxian-labs-site` | Conxian/conxian-labs-site | TypeScript | Marketing site | ✅ Active |

### 🔐 Smart Contracts (Core)

| Entity | File | Tier | Clarity 4 | Issues |
|--------|------|------|-----------|--------|
| `bridge-nft.clar` | cross-chain/ | Core | ✅ | 0 |
| `yield-optimizer.clar` | yield/ | Core | ✅ | 0 |
| `payment-forge.clar` | agents/ | Core | ✅ | 0 |
| `jurisdictional-sharding.clar` | compliance/ | Compliance | ✅ | 0 |
| `block-utils.clar` | utils/ | Util | ✅ | 0 |
| `operational-treasury.clar` | agents/ | **Critical** | ✅ | 0 |
| `pausable.clar` | access/ | **Critical** | ✅ | ❌ ACL missing |

### 🪙 Tokens

| Entity | Type | Trait | Issue |
|--------|------|-------|-------|
| **CXD** | Stablecoin | ft-trait | No peg mechanism |
| **CXLP** | LP Token | sip-010-ft-trait | Mint/burn broken |
| **CXVG** | Governance | sip-010-ft-trait | No distribution |

### 🔧 Technical Components

| Component | Technology | Purpose | Status |
|-----------|------------|---------|--------|
| **CXN Guardian** | TEE (SGX/TrustZone) | Hardware key isolation | ✅ Implemented |
| **ZKC** | Zero-Knowledge | Compliance verification | ✅ Designed |
| **SYI** | Sovereign Yield Index | Yield measurement | ✅ Designed |
| **BitVM2** | Groth16 | L2 state verification | ⚠️ Stub |
| **RGB** | Client-side | Asset validation | ⚠️ In progress |

### 🔧 CI/CD & DevOps

| Component | Technology | Purpose | Status |
|-----------|------------|---------|--------|
| **Gitleaks** | v8.24.2 | Secret scanning | ✅ Configured |
| **cargo audit** | Rust advisory db | Dependency vulnerability scanning | ✅ Active |
| **Conxian Unified CI** | GitHub Actions | Multi-suite test orchestration | ✅ Active |
| **Secret Scan** | Gitleaks workflow | Pre-commit secret detection | ✅ Active |
| **Branch Promotion Policy** | GitHub Actions | Enforce dev → staged → main flow | ✅ Active |

### 🛡️ Vulnerability Allowlist (Cargo Audit)

| RUSTSEC ID | Crate | Status | Rationale |
|------------|-------|--------|------------|
| RUSTSEC-2026-0204 | crossbeam-epoch | ✅ Ignored | Transitive via sled → bdk → electrum-client; no local upgrade path |
| RUSTSEC-2026-0104 | (various) | ✅ Ignored | Transitive dep chain |
| RUSTSEC-2026-0099 | rustls-webpki | ✅ Ignored | Transitive via bdk/electrum-client |
| RUSTSEC-2026-0098 | rustls-webpki | ✅ Ignored | Transitive via bdk/electrum-client |
| RUSTSEC-2024-0388 | instant | ✅ Ignored | Transitive via parking_lot |

### 👥 People (Entity Relationships)

| Role | Entity | Repository Access | Responsibility |
|------|--------|-------------------|----------------|
| Founder | - | All repos | Network operator (transitioning) |
| Protocol Architect | - | All repos | Future role (post-transition) |
| ZKC Auditor | - | lib-conxian-core | Compliance verification |
| SYI Strategist | - | conxian-gateway | Yield index design |

---

## Relationship Graph

```mermaid
graph TB
    subgraph "Legal Entity"
        CL[Conxian-Labs Pty Ltd]
    end
    
    subgraph "Conxian (Protocol Layer)"
        CNX[Conxian]
        CXD[CXD Token]
        CXLP[CXLP Token]
        CXVG[CXVG Token]
        NEXUS[conxian-nexus]
        GATEWAY[conxian-gateway]
    end
    
    subgraph "Conxius (Client Layer)"
        WALLET[conxius-wallet]
        PLATFORM[conxius-platform]
        ORBIT[conxius-orbit]
        ENCLAVE[conxius-enclave-sdk]
    end
    
    subgraph "Core Library"
        CORE[lib-conxian-core]
    end
    
    CL --> CNX
    CL --> WALLET
    
    CNX --> CXD
    CNX --> CXLP
    CNX --> CXVG
    
    CNX --> GATEWAY
    CNX --> NEXUS
    
    GATEWAY --> CORE
    NEXUS --> CORE
    ENCLAVE --> CORE
    
    WALLET --> ENCLAVE
    PLATFORM --> ORBIT
```

---

## Decision Registry

| Decision | Date | Rationale | Superseded By |
|----------|------|----------|---------------|
| Clarity 4 only | 2026-04-23 | Security + epoch features | - |
| epoch = "latest" mandatory | 2026-04-23 | Always use newest epoch | - |
| Dynamic principals from treasury | 2026-04-23 | Eliminate hardcoded SPOF | - |
| TEE via conxius-enclave-sdk | 2026-04-23 | Hardware key isolation | - |
| ISO 20022 via Conxian Gateway | 2026-04-23 | Legacy banking bridge | - |
| Cargo audit allowlist for transitive deps | 2026-07-08 | Transitive vulnerabilities without local upgrade path | Upgrade dep chain |
| Gitleaks license via GitHub Secrets | 2026-07-08 | ZSE compliance; no hardcoded secrets | - |
| Infrastructure fixes to main, cherry-pick to PR | 2026-07-08 | Workflow configs belong in main | - |

---

## Knowledge Citation Index

| Topic | Knowledge Doc | Last Updated |
|-------|---------------|--------------|
| Operational Standards | `AGENTS.md` | 2026-07-06 |
| Mathematical Framework | `lib-conxian-core/docs/CONXIAN_UNIFIED_THEORY_v2.md` | 2026-04-23 |
| Security Audit | `lib-conxian-core/docs/ADVISORY_REPORT_2026_07_06.md` | 2026-07-06 |
| Knowledge Gaps | `docs/KNOWLEDGE_GAP_ANALYSIS.md` | 2026-07-06 |
| Gateway Research | `conxian-gateway/docs/research/KNOWLEDGE_MAP.md` | 2026-04-23 |
| ISO 20022 Patterns | External: BIS d218, ISO white paper | 2025 |
| Clarity Patterns | External: Stacks Cookbook, CertiK | 2026 |

---

## Critical Links

### Standards
- [Clarity 4](https://stacks.co/blog/clarity-4-bitcoin-smart-contract-upgrade)
- [SIP-033](https://stacks.org/sip-033-clarity-4)
- [SIP Process](https://github.com/stacksgov/sips)
- [ISO 20022 Web APIs](https://iso20022.org)

### Security
- [CertiK Clarity Checklist](https://www.certik.com/resources/blog/clarity-best-practices-and-checklist)
- [sBTC Security Review](https://clarityalliance.org/reports/sbtc)

### Integration
- [Chainlink ISO 20022](https://chain.link/article/iso-20022-integration)
- [BIP-322 Signed Messages](https://bips.dev/322)
- [Lightspark ISO](https://lightspark.com/glossary/iso-20022)

---

## Maintenance

**Crystallization Rule:** Every agent session MUST update this document with:
1. New entities discovered
2. Relationship changes
3. Decision outcomes
4. Issue resolutions

**Verification:** Cross-reference claims against this graph before acting.

---

*Generated per AGENTS.md Knowledge Management mandate*
*Next update: After Phase 1 remediation (Week 2)*
