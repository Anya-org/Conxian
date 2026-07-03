# Conxian Developer Quickstart & Architecture Guide

> **Audience**: Contributors, partners, and auditors working on the Conxian BOS.
> **BOS Version**: 1.9.5
> **Last Updated**: 2026-07-03

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Getting Started](#getting-started)
4. [Building & Testing](#building--testing)
5. [Key Concepts](#key-concepts)
6. [CI/CD Pipeline](#cicd-pipeline)
7. [Contribution Workflow](#contribution-workflow)
8. [Further Reading](#further-reading)

---

## Architecture Overview

Conxian is a **Sovereign Business Operations System (BOS)** — a programmatic state machine living directly on Bitcoin. The repository `conxian-business` is the governance and orchestration hub that wires together 10 submodules into a unified platform.

### Ecosystem Tiers

| Tier | Components | Role |
|------|-----------|------|
| **Platform & Governance** | `conxian-business/`, `conxius-platform/`, `conxius-orbit/` | Oversight, deployment tooling, CI/CD |
| **Core Operating Suite** | `conxian-nexus/`, `conxian-gateway/` | Transaction execution, compliance, cross-chain bridge |
| **Protocol & SDKs** | `Conxian/`, `conxius-enclave-sdk/`, `lib-conxian-core/` | Smart contracts, hardware enclave SDK, shared crypto library |
| **User Interfaces** | `conxius-wallet/`, `conxian-ui/`, `conxian-labs-site/` | Android wallet, web dashboard, marketing site |

### Submodule Map

| Submodule | Language | Purpose |
|-----------|----------|---------|
| `conxian-nexus` | Rust | Multi-protocol execution engine (Bitcoin, EVM, Cosmos, Stacks, Lightning, RGB, Fedimint) |
| `conxian-gateway` | Rust | ISO 20022 compliance pipe bridging Bitcoin/Stacks with legacy banking |
| `lib-conxian-core` | Rust | Shared cryptographic primitives (BitVM2, ContractBridge, Wallet) |
| `conxius-enclave-sdk` | Rust/WASM | Cross-platform hardware enclave abstractions |
| `Conxian` | Clarity | Stacks smart contracts (sovereign treasury, fiscal vault, oracle) |
| `conxius-wallet` | TypeScript | Android-first sovereign Bitcoin command center |
| `conxian-ui` | TypeScript | Web dashboard and admin interface |
| `conxius-platform` | — | Local developer deployment orchestrator |
| `conxius-orbit` | Python | GUI/CLI deployment toolkit for Stacks contracts |
| `conxian-labs-site` | — | Corporate marketing site |

### Nexus Internal Architecture

```
conxian-nexus/src/
├── api/          # HTTP/gRPC handlers (18 routes + admin)
│   ├── rest.rs      # Main router: /v1/proof, /v1/execute, /v1/bitvm2/verify-state-root, /health, etc.
│   ├── admin.rs     # Admin API (CRUD, diagnostics)
│   ├── dlc.rs       # Bitcoin DLC bond orchestrator
│   ├── erp.rs       # OData/ERP translation layer with HMAC-SHA256 attestation
│   ├── identity.rs  # BNS/ENS identity resolution
│   ├── zkml.rs      # ZKML proof verification (BitVM2/Groth16)
│   ├── settlement.rs # x402 settlement pipeline
│   ├── billing.rs   # Usage-based billing
│   ├── analytics.rs # Analytics and reporting
│   ├── grpc.rs      # gRPC gateway (tonic/prost)
│   └── services.rs  # Service health status
├── executor/     # Protocol adapters
│   ├── bitvm.rs, evm.rs, cosmos.rs, stacks.rs
│   ├── lightning.rs, rgb.rs, fedimint.rs
│   └── mod.rs        # NexusExecutor: submit, validate, rebalance
├── oracle/       # PPP (Purchasing Power Parity) tracker
│   ├── aggregator.rs # push_state_to_contract via ContractBridge::create_signed_call
│   └── mod.rs
├── storage/      # Decentralized persistence
│   ├── kwil.rs       # Kwil decentralized SQL
│   ├── tableland.rs  # Tableland sharded persistence
│   └── mod.rs
├── state/        # Merkle tree state management (MMR proofs)
├── safety/       # Safety mode and circuit breakers
├── sync/         # Cross-chain state sync
├── config.rs     # Configuration (database, Redis, feature flags)
├── orchestrator.rs # Service lifecycle orchestration
└── main.rs       # Entry point
```

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| **Rust** | stable (1.82+) | Via [rustup](https://rustup.rs) |
| **Node.js** | 20.x | LTS |
| **pnpm** | 9.15.9 | Via `npm install -g pnpm@9.15.9` |
| **Python** | 3.10+ | For scripts and conxius-orbit |
| **protoc** | ≥3.x | Protobuf compiler (for tonic/prost) |

### Quick Install (Linux/macOS)

```bash
# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
source "$HOME/.cargo/env"

# Node + pnpm
# (via nvm, fnm, or system package manager)
npm install -g pnpm@9.15.9

# Protobuf
# Ubuntu/Debian:
sudo apt-get install -y protobuf-compiler
# macOS:
brew install protobuf
```

### Dev Container

A pre-configured `.devcontainer/Dockerfile` is provided with Rust, Python 3.10, and build essentials on Ubuntu 24.04. Open in VS Code or GitHub Codespaces for zero-config setup.

---

## Getting Started

```bash
# 1. Clone with submodules
git clone --recurse-submodules https://github.com/Conxian/conxian-business.git
cd conxian-business

# 2. Initialize all submodules
git submodule update --init --recursive

# 3. Run repository health checks
python3 scripts/bos_repo_check.py
python3 scripts/verify_contamination_guard.py
python3 scripts/verify_action_versions.py
```

### Submodule Hygiene

- **Always** use `git submodule update --init --recursive` after switching branches.
- Submodule pins are validated by `scripts/verify_submodule_integrity.py`.
- The `Conxian/` submodule is pinned with `update=none` (it has its own broken submodule config — tracked as a dependency).
- All other submodules use `update=checkout` for CI pin freshness.

---

## Building & Testing

### B2B Suite — Nexus (Rust)

```bash
cd conxian-nexus

# Build
cargo build

# Run all tests
cargo test

# Run a specific test file
cargo test --test api_test
cargo test --test bitcoin_test

# Run with logging
RUST_LOG=conxian_nexus=debug cargo test -- --nocapture
```

**Key dependencies**: `axum 0.8`, `sqlx 0.8`, `redis 0.27`, `tonic 0.13`, `lib-conxian-core` (pinned git rev), `tower 0.5`.

### Core Library Suite — lib-conxian-core (Rust)

```bash
cd lib-conxian-core

# Build and test (locked dependencies)
cargo test --locked

# Clippy (strict)
cargo clippy --locked --all-targets --all-features -- -D warnings

# Security audit
cargo audit \
  --ignore RUSTSEC-2026-0098 \
  --ignore RUSTSEC-2026-0099 \
  --ignore RUSTSEC-2026-0104 \
  --ignore RUSTSEC-2024-0388
```

### Gateway Suite (Rust)

```bash
cd conxian-gateway

# Type-check API crate
cargo check -p api

# Run tests
cargo test
```

### B2C Wallet Suite (TypeScript)

```bash
cd conxius-wallet

# Install dependencies
pnpm install --frozen-lockfile

# Run tests
pnpm test -- --reporter=verbose
```

### Smart Contracts (Clarity)

```bash
cd Conxian

# Check all contracts (requires Clarinet)
clarinet check --coverage

# Regenerate Clarinet.toml from AST
python3 conxius-orbit/rebuild_toml.py
```

### Verification Scripts

```bash
# Run all checks
python3 scripts/bos_repo_check.py

# Individual checks
python3 scripts/verify_contamination_guard.py   # No testnet principals in production .clar files
python3 scripts/verify_action_versions.py       # All GitHub Actions references valid
python3 scripts/verify_submodule_integrity.py   # Submodule pins initialized and hardened
python3 scripts/verify_lts_compliance.py        # LTS toolchain versions
python3 scripts/verify_repo_governance_baseline.py
python3 scripts/verify_wallet_lifecycle_control_gates.py
```

---

## Key Concepts

### Sovereign-First Deployment Mandate

All core contracts source dynamic principals from `operational-treasury.clar`. Hardcoded `ST…` / `SP…` addresses in production source trigger an **immediate CI build-break** via the contamination guard. The guard scans all `.clar` files for testnet/simnet principals and fails if any are found outside test directories.

### Zero Secret Egress (ZSE)

| Layer | Rule |
|-------|------|
| **Secrets** | Sensitive configs live in Linear or Supabase only — never in source |
| **On-chain** | Expose state-proof primitives only; never raw config |
| **Stubs** | Production paths return `err-u501` / `err-u503` and fail-closed |

Production stub audit files (`.stub.json`) are safe for public repos — canonical details are maintained in the Conxian Linear workspace.

### Dual-Brand Architecture

| Brand | Layer | Examples |
|-------|-------|----------|
| **Conxian** | Sovereign & Protocol (B2B) | Conxian Gateway, Conxian Nexus |
| **Conxius** | Client & Access (end-user) | Conxius Wallet, Conxius Platform, Conxius Enclave SDK |

**Deprecated terms** (CI rejects these): "Conxian Gateway", "Conxius Enclave SDK", "conxius_orbit".

### Unified Theory v2.0

The BOS is governed by four variables:
- **$C_R$** (Cost of Reproduction) — Structural moat
- **$O_C$** (Opportunity Cost) — Founder's tax; goal: drive to zero
- **$V_X$** (Execution Velocity) — AI and tooling leverage
- **$A_S$** (System Autonomy) — Programmatic independence

The BOS is currently in **Phase 3 (Transition)** where the goal is to minimize manual oversight ($O_C \to 0$) and maximize system autonomy ($A_S$).

### Oracle Service

The Oracle tracks Purchasing Power Parity (PPP) across fiat corridors and pushes signed state updates to Stacks contracts via `ContractBridge::create_signed_call`. The stub flag (`ORACLE_SERVICE_IS_STUBBED`) is `false` in production — the service produces real signed contract calls.

### BitVM2 Integration

SNARK proofs are verified through `lib-conxian-core` against the BitVM2 engine per CJCS v2.0. The bridge validates Bitcoin L1 state via Groth16 proof verification.

---

## CI/CD Pipeline

The **Conxian Unified CI** (`conxian-unified-ci.yml`) runs on every push to `main`, `staged`, and `dev`.

### Pipeline Jobs

| Job | What It Tests |
|-----|--------------|
| **Repo Hygiene** | ZSE compliance, submodule integrity |
| **Detect CI Triggers** | Change detection for selective suite execution |
| **Core Library Suite** | `cargo test --locked` + `cargo clippy` + `cargo audit` in `lib-conxian-core/` |
| **B2B Suite** | `cargo test` in `conxian-nexus/` |
| **Gateway Suite** | `cargo check -p api` + `cargo test` in `conxian-gateway/` |
| **B2C Wallet Suite** | `pnpm test` in `conxius-wallet/` |
| **Testnet Simulation** | Optional — runs on PRs to `staged` |
| **Transparency Audit** | Optional — runs on releases |
| **CI Summary Gate** | Aggregates all results; fails if any required job failed |

### Promotion Pipeline

```
dev  ──→  staged  ──→  main
```

- **`dev`**: Active development, force-push allowed, all suites run
- **`staged`**: Pre-production, promotion PR from dev, Testnet Simulation may run
- **`main`**: Production, promotion PR from staged, protected branch

### Required CI Checks

- All suites must pass before merging to `main`
- Contamination guard must pass (zero testnet/simnet principals)
- Submodule pin integrity must pass
- Action version audit must pass

---

## Contribution Workflow

### 1. Set Up

```bash
git clone --recurse-submodules https://github.com/Conxian/conxian-business.git
cd conxian-business
git checkout dev
git submodule update --init --recursive
```

### 2. Branch

```bash
git checkout -b feat/your-feature-name
```

### 3. Develop

- Work in the relevant submodule (e.g., `conxian-nexus/` for Rust work, `conxius-wallet/` for TypeScript)
- Run tests locally before committing: `cargo test` or `pnpm test`
- Run verification scripts: `python3 scripts/bos_repo_check.py`

### 4. Commit

```bash
# Commit submodule changes first
cd conxian-nexus
git add . && git commit -m "feat: your change" && git push origin HEAD:main
cd ..

# Then update the submodule pin
git add conxian-nexus
git commit -m "chore: bump conxian-nexus submodule for your-feature"
```

### 5. Push & Monitor

```bash
git push origin HEAD:dev --force
```

Watch CI at `https://github.com/Conxian/conxian-business/actions`. All suites must pass.

### 6. Code Review (OpenHands automation)

Apply the `review` label to trigger automated PR review via OpenHands. The review bot inspects full repository context and posts inline comments with risk assessments.

### Submodule Change Checklist

- [ ] Changes committed and pushed to submodule's `main` branch
- [ ] Submodule pin updated in `conxian-business`
- [ ] All CI suites green
- [ ] Contamination guard passes (`verify_contamination_guard.py`)
- [ ] No deprecated brand terms in new code
- [ ] No hardcoded `ST…`/`SP…` principals in production `.clar` files

---

## Further Reading

### Architecture
- [`docs/architecture/BOS_CONTROL_PLANE_TARGET_ARCHITECTURE.md`](architecture/BOS_CONTROL_PLANE_TARGET_ARCHITECTURE.md) — Control plane architecture
- [`docs/architecture/BITCOIN_LAYER_ARCHITECTURE_BOUNDARY_NOTE.md`](architecture/BITCOIN_LAYER_ARCHITECTURE_BOUNDARY_NOTE.md) — Bitcoin layer boundaries
- [`docs/architecture/PROTOCOL_ADAPTER_MATURITY_LANES.md`](architecture/PROTOCOL_ADAPTER_MATURITY_LANES.md) — Adapter maturity lanes
- [`docs/architecture/THREE_LANE_RUNTIME_DEPLOYMENT_ARCHITECTURE.md`](architecture/THREE_LANE_RUNTIME_DEPLOYMENT_ARCHITECTURE.md) — Runtime deployment lanes
- [`docs/architecture/adrs/`](architecture/adrs/) — Architecture Decision Records

### Governance
- [`docs/CONXIAN_UNIFIED_THEORY_v2.md`](CONXIAN_UNIFIED_THEORY_v2.md) — The foundational mathematical framework
- [`AGENTS.md`](../AGENTS.md) — Agent operational standards and mandates
- [`docs/REPO_PORTFOLIO.md`](REPO_PORTFOLIO.md) — Full repository portfolio

### Operations
- [`CHANGELOG.md`](../CHANGELOG.md) — Release changelog
- [`docs/operations/`](operations/) — Operational runbooks and scorecards
- [`docs/protocols/`](protocols/) — Protocol specifications (Clarity4, custody, session broker)

### API
- [`docs/architecture/CONTROL_PLANE_ADMIN_API_V1.md`](architecture/CONTROL_PLANE_ADMIN_API_V1.md) — Admin API contract
- [`docs/architecture/NEXUS_ADMIN_SERVICE_BOUNDARY_V1.md`](architecture/NEXUS_ADMIN_SERVICE_BOUNDARY_V1.md) — Nexus admin service boundary
- [`conxian-nexus/src/api/rest.rs`](../conxian-nexus/src/api/rest.rs) — Main API router (source of truth for routes)
