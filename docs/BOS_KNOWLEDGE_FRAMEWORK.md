# Conxian BOS Knowledge Framework
> **ITIL5-Aligned Multi-Dimensional Knowledge Architecture**
> Version: 1.0 | Generated: 2026-07-08

---

## 🎯 Framework Philosophy

This knowledge base follows **ITIL5 Service Value Chain** principles:
- **Value** over documentation
- **Outcomes** over processes
- **Stakeholders** at the center
- **Multi-dimensional** views for different purposes

### Multi-Dimensional Lens

| Dimension | Purpose | Key Questions |
|-----------|---------|--------------|
| **Spatial** | Repository structure | Where is it? What's the blast radius? |
| **Temporal** | Lifecycle & history | When? What's the timeline? |
| **Relational** | Dependencies & stakeholders | Who owns it? What depends on it? |
| **Logical** | Decision & reasoning | Why? What's the rationale? |
| **Security** | Risk & compliance | Is it safe? What's the exposure? |
| **Operational** | CI/CD & execution | How does it run? |

---

## 🏢 Entity Registry (By Dimension)

### Spatial Dimension: Repositories

```yaml
repositories:
  conxian-business:
    type: knowledge-ops
    owner: Conxian-Labs
    visibility: public
    language: Mixed (MD, TS, Rust, Clarity)
    purpose: "Business ops, governance, AGENTS.md"
    relationships:
      - type: contains
        target: conxian-nexus
      - type: contains
        target: conxian-gateway
      - type: references
        target: lib-conxian-core

  conxian-nexus:
    type: protocol-core
    owner: Conxian-Labs
    visibility: public
    language: Clarity/Rust
    purpose: "Settlement layer, DAO treasury operations"
    relationships:
      - type: depends-on
        target: lib-conxian-core

  conxian-gateway:
    type: protocol-bridge
    owner: Conxian-Labs
    visibility: public  
    language: Rust
    purpose: "ISO 20022 bridge, Bitcoin/Stacks integration"
    relationships:
      - type: depends-on
        target: lib-conxian-core

  conxius-wallet:
    type: client-facing
    owner: Conxian-Labs
    visibility: private
    language: TypeScript
    purpose: "Android wallet, sovereign key management"

  conxius-platform:
    type: developer-tool
    owner: Conxian-Labs
    visibility: private
    language: TypeScript
    purpose: "Developer orchestration, deployment tooling"

  conxius-enclave-sdk:
    type: security-module
    owner: Conxian-Labs
    visibility: public
    language: Rust/WASM
    purpose: "TEE abstraction, hardware key isolation"

  lib-conxian-core:
    type: shared-library
    owner: Conxian-Labs
    visibility: public
    language: Rust
    purpose: "Crypto primitives, ZKC, SYI foundations"
```

### Relational Dimension: Stakeholders

```yaml
stakeholders:
  Conxian-Labs:
    type: legal-entity
    role: operator
    owns:
      - conxian-business
      - conxian-nexus
      - conxian-gateway
      - conxius-wallet
      - conxius-platform
      - conxius-enclave-sdk
      - lib-conxian-core
    responsibilities:
      - protocol-development
      - compliance
      - security-operations

  Conxian.org:
    type: dao-entity
    role: governance
    responsibilities:
      - token-holder-governance
      - treasury-management
      - protocol-upgrades
```

### Security Dimension: Vulnerability Registry

```yaml
vulnerability-registry:
  last-audited: 2026-07-08
  total-open: 23
  
  by-severity:
    high: 8
    moderate: 8
    low: 7

  by-fixability:
    fixable: 11
      packages:
        - undici (6 alerts)
        - ws (2 alerts)
        - form-data (1 alert)
        - vite (1 alert)
        - postcss (1 alert)
    unfixable-transitive: 12
      chains:
        - rustls-webpki → bdk → electrum-client
        - bigint-buffer → bdk
        - crossbeam-epoch → sled → bdk
```

### Temporal Dimension: Decision Log

```yaml
decisions:
  - id: DEC-001
    date: 2026-04-23
    topic: clarity-version
    decision: "Clarity 4 only"
    rationale: "Security + epoch features required"
    status: active
    
  - id: DEC-002
    date: 2026-07-08
    topic: vulnerability-allowlist
    decision: "Allowlist transitive Rust vulns"
    rationale: "No local upgrade path; upstream dependency"
    status: active
    affected:
      - rustls-webpki
      - bigint-buffer
      - crossbeam-epoch
      
  - id: DEC-003
    date: 2026-07-08
    topic: gitguardian-patterns
    decision: "Avoid PASSWORD/SECRET in env var names"
    rationale: "GitGuardian false positives on variable names"
    status: active
```

---

## 🔗 Relationship Map

### Conxian-Labs Operational View

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONXIAN-LABS OPERATIONS                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐                                               │
│  │ conxian-     │◀─────── DEPENDS ON ───────┌───────────────┐ │
│  │ business     │                              │ lib-conxian- │ │
│  │ (Knowledge)  │                              │ core         │ │
│  └──────┬───────┘                              │ (Shared)     │ │
│         │                                          └──────▲──────┘ │
│         │                                                 │        │
│  ┌──────┴───────┐    ┌──────────────┐    ┌───────────┴────────┐ │
│  │ conxian-     │───▶│ conxian-     │───▶│ conxius-          │ │
│  │ nexus        │    │ gateway      │    │ enclave-sdk       │ │
│  │ (Protocol)   │    │ (Bridge)     │    │ (Security)        │ │
│  └──────────────┘    └──────────────┘    └───────────────────┘ │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐                           │
│  │ conxius-     │───▶│ conxius-     │     OWNED BY            │
│  │ wallet       │    │ platform     │     CONXIAN-LABS        │
│  │ (Client)     │    │ (DevOps)     │     (Pty) Ltd           │
│  └──────────────┘    └──────────────┘                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    CONXIAN.ORG GOVERNANCE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐                                               │
│  │ Treasury     │◀─────── GOVERNS ───────┌───────────────┐    │
│  │ Operations   │                         │ Protocol      │    │
│  └──────┬───────┘                         │ Upgrades      │    │
│         │                                  └───────────────┘    │
│  ┌──────┴───────┐                                               │
│  │ Token Holder │                                               │
│  │ Governance   │                                               │
│  └──────────────┘                                               │
│                                                                  │
│  RELATION: Conxian-Labs operates for Conxian.org               │
│             Conxian.org governs Conxian-Labs                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Dependency Graph (By Repo)

```
conxian-business
├── pnpm-lock.yaml
│   ├── undici ⚠️ [6 vulns] → fixable
│   ├── ws ⚠️ [2 vulns] → fixable
│   ├── form-data ⚠️ [1 vuln] → fixable
│   └── vite ⚠️ [1 vuln] → fixable
│
├── Cargo.lock (lib-conxian-core)
│   ├── rustls-webpki ⚠️ [1 vuln] → unfixable (bdk chain)
│   ├── crossbeam-epoch ⚠️ [1 vuln] → unfixable (sled chain)
│   └── bigint-buffer ⚠️ [1 vuln] → unfixable (bdk chain)
│
└── .github/workflows/
    ├── conxian-unified-ci.yml (cargo audit ignore list)
    └── secret-scan.yml (gitleaks v8.24.2)
```

---

## 📊 Query Indexes

### By Repository

| Repo | Type | Vulns | Fixable | Owner |
|------|------|-------|---------|-------|
| conxian-business | knowledge-ops | 23 | 11 | Conxian-Labs |
| lib-conxian-core | shared-lib | 3 | 0 | Conxian-Labs |

### By Severity

| Severity | Count | Fixable | Action |
|----------|-------|---------|--------|
| High | 8 | 6 | Fix now |
| Moderate | 8 | 0 | Monitor |
| Low | 7 | 0 | Accept |

### By Stakeholder

| Stakeholder | Responsibility | Active Issues |
|-------------|----------------|---------------|
| Conxian-Labs | Operations | 23 open |
| Conxian.org | Governance | 0 direct |

---

## 🔄 Change Log

| Date | Entity | Change | Rationale |
|------|--------|--------|-----------|
| 2026-07-08 | BOS_KNOWLEDGE_FRAMEWORK | Created | Multi-dimensional architecture |
| 2026-07-08 | vulnerability-registry | Updated | 23 open alerts documented |
| 2026-07-08 | DEC-002 | Added | Vulnerability allowlist decision |

---

*This document is the authoritative source for multi-dimensional knowledge.*
*Use for: diff, inspection, research, implementation, verification*
