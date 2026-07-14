# Business Unit Charters

> **Version:** 1.0 (2026-07-14)
> **Authority:** BOS (conxian-business)
> **Reference:** [PORTFOLIO_BUSINESS_UNIT_MAP.md](./PORTFOLIO_BUSINESS_UNIT_MAP.md)

This document defines explicit ownership, responsibilities, and escalation paths for each business unit in the Conxian ecosystem.

---

## Business Unit Overview

| Unit | Market | Core Obligation | Owner |
|------|--------|----------------|-------|
| **Conxius** | B2C | Sovereign wallet and key custody | Conxian-Labs |
| **CSF** | Protocol | On-chain contracts, assets, fee logic | Conxian-Labs |
| **Fusion** | B2B/B2G | Cross-layer gateway + compliance | Conxian-Labs |
| **Nexus** | State | Authoritative state node/services | Conxian-Labs |

---

## Unit Charters

### 1. Conxius (B2C — Client Layer)

**Scope:** End-user facing products and developer tools.

**Responsibilities:**
- Sovereign wallet implementation (conxius-wallet)
- Local development orchestration (conxius-platform)
- Stacks deployment tooling (conxius-orbit)
- TEE abstraction layer (conxius-enclave-sdk)

**Exposes:**
- Wallet signing APIs
- Local dev environment
- Deployment CLI

**Depends On:**
- Conxian/ (Protocol)
- conxian-gateway (Settlement)
- conxius-enclave-sdk (Key isolation)

**Owner:** Conxian-Labs Platform Team

**Escalation:** CON-XXX (TBD)

---

### 2. CSF — Conxian Finance Protocol (Protocol)

**Scope:** On-chain smart contracts and token logic.

**Responsibilities:**
- 221 Clarity smart contracts
- CXD, CXLP, CXVG token standards
- DAO governance mechanisms
- Yield optimization logic

**Exposes:**
- ClarityVM RPC interface
- SIP-010 token traits
- Governance voting

**Depends On:**
- Nothing (root of trust)

**Depended On By:**
- conxian-gateway
- conxian-nexus
- conxius-wallet

**Owner:** Conxian-Labs Protocol Team

**Escalation:** CON-XXX (TBD)

---

### 3. Fusion (B2B/B2G — Gateway)

**Scope:** Enterprise integration and compliance pipelines.

**Responsibilities:**
- ISO 20022 banking messaging
- x402 payment mandates
- RPC pooling and failover
- ZK compliance verification

**Exposes:**
- REST API endpoints
- x402 mandate translation
- Compliance audit trails

**Depends On:**
- Conxian/ (Protocol)
- lib-conxian-core
- conxian-nexus (State)

**Depended On By:**
- conxian-ui
- conxius-wallet
- conxian-market

**Owner:** Conxian-Labs Infrastructure Team

**Escalation:** CON-XXX (TBD)

---

### 4. Nexus (State + Telemetry)

**Scope:** Authoritative off-chain state and verification.

**Responsibilities:**
- Multi-chain state synchronization
- PPP (Proof-of-Progress) tracking
- Settlement execution
- Kwil/Tableland persistence

**Exposes:**
- State service APIs
- Settlement endpoints
- Analytics feeds

**Depends On:**
- Conxian/ (Protocol)
- lib-conxian-core

**Depended On By:**
- conxian-gateway
- conxian-ui
- conxian-market

**Owner:** Conxian-Labs Infrastructure Team

**Escalation:** CON-XXX (TBD)

---

## Operating Functions

These functions cross-cut all business units and should not be embedded in product repos:

| Function | Scope | Location |
|----------|-------|----------|
| **Governance** | BOS, OpenSpec, standards | conxian-business |
| **Treasury** | Yield, bonds, revenue | Fiscal-Vault-Oracle |
| **Compliance** | Policy, anti-fragility | Nakamoto-Guardian |
| **Ops** | CI/CD, automation | Sovereign-Ops-Orchestrator |
| **Strategy** | M&A, IP, planning | Sovereign-Strategy-Nexus |
| **UI/Web** | Marketing, docs | conxian-labs-site, conxian-ui |

---

## Change Control

| Change Type | Approval Required | Process |
|------------|-----------------|---------|
| API contract change | Unit owner + downstream | OpenSpec proposal |
| Contract principal change | Protocol owner | Linear issue |
| Dependency addition | Unit owner | PR review |
| Cross-unit interface change | Both unit owners | PR + test |

---

## Escalation Matrix

| Severity | Definition | Response Time |
|----------|------------|---------------|
| P0 | Production down, data loss | 1 hour |
| P1 | Major feature broken | 4 hours |
| P2 | Minor feature broken | 24 hours |
| P3 | Enhancement, documentation | 1 week |

---

## Maintenance

**Review:** Quarterly (align with sprint cycles)

**Updates:** Any change to unit boundaries requires BOS approval

---

*Generated per P0-1 mandate in PORTFOLIO_BUSINESS_UNIT_MAP.md*
