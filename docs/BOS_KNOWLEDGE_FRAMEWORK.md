# Conxian BOS Knowledge Framework
> **Agentic-First Multi-Dimensional Knowledge Architecture**
> Version: 2.1 | Generated: 2026-07-08
> **Design**: Machine-ingestible, AI-first, structured patterns
> **Upgradeable**: YES - See `## Knowledge Base Upgrade Guide`

---

## 🎯 Agentic Design Principles

This knowledge base is designed for **AI consumption and autonomous action**:

1. **Structured over Prose** - YAML/JSON tables, not paragraphs
2. **Actionable Patterns** - IF conditions → THEN actions
3. **Versioned Entries** - Every entity has `created`, `updated`, `version`
4. **Cross-Referenced** - Links between related entities
5. **Query-First** - Questions map directly to sections

---

### Query → Section Mapping

| Agent Question | Section |
|----------------|---------|
| "How do I fix CI failure?" | `## ci-failures` |
| "What secrets exist?" | `## secrets` |
| "Who owns this?" | `## stakeholders` |
| "Why was this decided?" | `## decisions` |
| "What's vulnerable?" | `## vulnerabilities` |
| "How do I deploy?" | `## deployments` |

---

## Entity Schema (Machine-Readable)

All entities follow this schema:

```yaml
entity:
  id: string           # Unique identifier (e.g., "SEC-001")
  type: string         # Entity type (repository, decision, vulnerability)
  name: string         # Human-readable name
  version: semver      # Schema version
  created: ISO8601      # Creation date
  updated: ISO8601      # Last update
  status: enum         # active | deprecated | superseded
  tags: [string]       # Searchable tags
  relations: [object]   # Links to other entities
  data: object         # Type-specific payload
```

---

## 📦 Repositories

```yaml
repositories:
  conxian-business:
    id: REPO-001
    type: knowledge-ops
    owner: Conxian-Labs
    visibility: public
    language: Mixed
    purpose: "Business ops, governance, AGENTS.md"
    related: [REPO-002, REPO-003, REPO-007]
    tags: [knowledge-base, governance, ci-cd]

  conxian-nexus:
    id: REPO-002
    type: protocol-core
    owner: Conxian-Labs
    visibility: public
    language: Clarity/Rust
    purpose: "Settlement layer, treasury operations"
    related: [REPO-007]
    tags: [protocol, clarity, dao]

  conxian-gateway:
    id: REPO-003
    type: protocol-bridge
    owner: Conxian-Labs
    visibility: public
    language: Rust
    purpose: "ISO 20022 bridge, Bitcoin/Stacks"
    related: [REPO-007]
    tags: [protocol, bridge, rust]

  conxius-wallet:
    id: REPO-004
    type: client-facing
    owner: Conxian-Labs
    visibility: private
    language: TypeScript
    purpose: "Android wallet, key management"
    tags: [wallet, mobile, tpm]

  conxius-platform:
    id: REPO-005
    type: developer-tool
    owner: Conxian-Labs
    visibility: private
    language: TypeScript
    purpose: "Dev orchestration"
    tags: [developer, deployment]

  conxius-enclave-sdk:
    id: REPO-006
    type: security-module
    owner: Conxian-Labs
    visibility: public
    language: Rust/WASM
    purpose: "TEE abstraction"
    tags: [security, tee, enclave]

  lib-conxian-core:
    id: REPO-007
    type: shared-library
    owner: Conxian-Labs
    visibility: public
    language: Rust
    purpose: "Crypto primitives, ZKC, SYI"
    tags: [library, crypto, rust]
    consumers: [REPO-002, REPO-003]
```

---

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
vulnerabilities:
  audit-date: "2026-07-08"
  version: "1.0"
  
  summary:
    total: 23
    high: 8
    moderate: 8
    low: 7
    fixable: 11
    unfixable: 12

  # ACTIONABLE: IF vulnerability THEN action
  rules:
    - IF: "severity == high AND fixable == true"
      THEN: "pnpm update <package> OR add to PR checklist"
      
    - IF: "severity == high AND fixable == false"
      THEN: "Check decision DEC-002; if not covered, add to allowlist"
      
    - IF: "transitive == true AND chain contains 'bdk'"
      THEN: "Monitor bdk upstream; add to DEC-002"
      
    - IF: "severity == moderate"
      THEN: "Add to monitor list; fix in next sprint"
      
    - IF: "severity == low"
      THEN: "Acceptable risk; document in vulnerability section"

  # HIGH SEVERITY - REQUIRES ACTION
  high:
    - id: VULN-H001
      alert: "#148"
      pkg: form-data
      ecosystem: npm
      fixable: true
      fix: "pnpm update form-data"
      affects: [pnpm-lock.yaml]

    - id: VULN-H002
      alert: "#143"
      pkg: vite
      ecosystem: npm
      fixable: true
      fix: "pnpm update vite"
      affects: [pnpm-lock.yaml]

    - id: VULN-H003
      alert: "#149"
      pkg: ws
      ecosystem: npm
      fixable: true
      fix: "pnpm update ws"
      affects: [pnpm-lock.yaml]

    - id: VULN-H004
      alert: "#21"
      pkg: bigint-buffer
      ecosystem: npm
      fixable: false
      reason: "Transitive via bdk"
      chain: "bdk -> bigint-buffer"
      decision: DEC-002
      affects: [Cargo.lock]

    - id: VULN-H005
      alert: "#153"
      pkg: undici
      ecosystem: npm
      fixable: true
      fix: "pnpm update undici"
      affects: [pnpm-lock.yaml]

    - id: VULN-H006
      alert: "#146"
      pkg: undici
      ecosystem: npm
      fixable: true
      fix: "pnpm update undici"
      affects: [pnpm-lock.yaml]

    - id: VULN-H007
      alert: "#150"
      pkg: undici
      ecosystem: npm
      fixable: true
      fix: "pnpm update undici"
      affects: [pnpm-lock.yaml]

    - id: VULN-H008
      alert: "#58"
      pkg: rustls-webpki
      ecosystem: cargo
      fixable: false
      reason: "Transitive via bdk -> electrum-client"
      chain: "bdk -> electrum-client -> rustls-webpki"
      decision: DEC-002
      affects: [Cargo.lock]

  # MODERATE SEVERITY - MONITOR
  moderate:
    - id: VULN-M001
      alert: "#139"
      pkg: uuid
      ecosystem: npm
      affects: [pnpm-lock.yaml]

    - id: VULN-M002
      alert: "#60"
      pkg: postcss
      ecosystem: npm
      fixable: true
      fix: "pnpm update postcss"
      affects: [showcase-dapp/package-lock.json]

  # LOW SEVERITY - ACCEPTABLE RISK
  low:
    - id: VULN-L001
      alert: "#154"
      pkg: undici
      ecosystem: npm
      affects: [pnpm-lock.yaml]
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

```yaml
changelog:
  - version: 2.1
    date: 2026-07-08
    changes:
      - "Added Upgrade Guide section"
      - "Added Version Update Protocol"
      - "Added Entity ID Sequences"
      - "Upgradeable: YES"

  - version: 2.0
    date: 2026-07-08
    changes:
      - "Agentic-first redesign"
      - "Added IF-THEN action rules"
      - "Expanded vulnerability registry"
      - "Added Query -> Section mapping"
      - "Machine-readable schema"

  - version: 1.0
    date: 2026-07-08
    changes:
      - "Initial framework"
      - "Multi-dimensional structure"
      - "Repository registry"
      - "Vulnerability registry"
```

---

## 🔧 Knowledge Base Upgrade Guide

### Adding New Entities

```yaml
# 1. Assign next ID in sequence
# 2. Add to appropriate section
# 3. Update version and changelog
# 4. Add cross-references in relations

# Example: New Repository
repositories:
  new-repo:
    id: REPO-XXX  # Next available
    type: <type>
    owner: <owner>
    # ... other fields
    related: [<existing IDs>]
    tags: [<searchable tags>]

# Example: New Vulnerability
vulnerabilities:
  items:
    - id: VULN-XXX  # H001-H999, M001-M999, L001-L999
      alert: "#XXX"
      pkg: <package>
      ecosystem: <npm|cargo>
      severity: <high|moderate|low>
      fixable: <true|false>
      fix: "<command if fixable>"
      affects: [<affected files>]

# Example: New Decision
decisions:
  - id: DEC-XXX  # Next sequence
    date: <ISO8601>
    topic: <topic>
    decision: <decision>
    rationale: <why>
    status: <active|deprecated|superseded>
    superseded-by: <DEC-XXX if applicable>
```

### Version Update Protocol

```yaml
upgrade-protocol:
  trigger: "Any modification to knowledge base"
  
  steps:
    1: "Increment version number"
       - major: "Breaking changes to schema"
       - minor: "New entities or sections"
       - patch: "Corrections, typo fixes"
       
    2: "Update changelog"
       - add: "{version, date, changes[]}"
       
    3: "Cross-reference new entities"
       - update: "relations in related entities"
       - add: "tags for discoverability"
       
    4: "Verify machine-readability"
       - check: "YAML syntax valid"
       - check: "IDs unique and sequential"
       - check: "Dates in ISO8601"
```

### Entity ID Sequences

```yaml
id-sequences:
  repositories: "REPO-001 to REPO-999"
  vulnerabilities-high: "VULN-H001 to VULN-H999"
  vulnerabilities-moderate: "VULN-M001 to VULN-M999"
  vulnerabilities-low: "VULN-L001 to VULN-L999"
  decisions: "DEC-001 to DEC-999"
  secrets: "SEC-001 to SEC-999"
  stakeholders: "STAKE-001 to STAKE-999"
```

---

## 📋 Agent Checklist Template

When processing any task, agents should:

```yaml
agent-checklist:
  spatial:
    - Identify affected repository (REPO-XXX)
    - Check blast radius (what depends on this?)
    - Map file locations

  temporal:
    - Check decision log (DEC-XXX) for prior decisions
    - Note creation/update dates
    - Verify version compatibility

  relational:
    - Identify stakeholder (Conxian-Labs vs Conxian.org)
    - Check dependency chains
    - Note cross-repo impacts

  logical:
    - Retrieve decision rationale
    - Verify against operational standards
    - Check for superseding decisions

  security:
    - Scan vulnerability registry
    - Check for fixable vulnerabilities
    - Verify allowlist compliance

  operational:
    - Run appropriate CI checks
    - Follow commit protocol
    - Cherry-pick to PR branches if needed
```

---

*This document is the authoritative source for multi-dimensional knowledge.*
*Use for: diff, inspection, research, implementation, verification*
*AI-Ingestible: YES | Machine-Readable: YES | Versionable: YES*
