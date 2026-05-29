# Master Task Inventory — Conxian-Labs Ecosystem
**Generated:** 2026-05-29
**Source:** Full conversation analysis × 3 documents × 10 submodules × 2 PRDs × AGENTS.md × Knowledge Graph
**Classification:** CON-401+ (New Epic Group)
**Linear Workspace:** `linear.app/conxian-labs`

---

## How to Use

This document inventories **every actionable item** from the full conversation history. Items are organized into **6 Epics**, each with prioritized issues. Where applicable, existing Linear issues are cross-referenced.

**Recommended Linear workflow:**
1. Create each **Epic** as a Linear Project
2. Create **Issues** under each Epic with labels, priority, and assignee
3. Reference existing CON-xxx issues where applicable
4. Use the ExCo intake flow (per LINEAR_WIRING.md) for new initiative approvals

---

## Epic A: INFRASTRUCTURE & DEVOPS (BLOCKER — Immediate)

**Priority: CRITICAL** — These block all other work

| # | Issue | Type | Priority | Source | Existing Issue |
|:---|:---|---|:---:|:---|:---:|
| A-01 | **Free disk space on C: drive** (0 GB free — 239 GB total, 7.5 GB in `target/`) | BUG | 🔴 BLOCKER | Build verification | — |
| A-02 | **Configure F: drive as CARGO_TARGET_DIR** (28.85 GB free — USB, currently sandbox-blocked) | TASK | 🔴 BLOCKER | Build verification | — |
| A-03 | **Run `cargo test --workspace`** with sufficient disk | TASK | 🔴 BLOCKER | Build verification | — |
| A-04 | **Build `conxian-gateway`** workspace (5 members, independent workspace) | TASK | 🔴 BLOCKER | Build verification | — |
| A-05 | **Run `clarinet check --coverage`** on 207+ Clarity 4 contracts | TASK | 🔴 BLOCKER | Contract verification | — |
| A-06 | **Implement setup_windows.ps1** as authoritative Windows dev setup | TASK | HIGH | Dev setup | — |
| A-07 | **Configure CI/CD pipeline** for Windows + Linux builds | TASK | HIGH | Dev setup | — |
| A-08 | **Set up GitHub Actions self-hosted runner** | TASK | MEDIUM | Infra recommendation | — |
| A-09 | **Configure Oracle Cloud Free Tier** for Gateway API + Wallet backend | TASK | HIGH | Infra recommendation | — |

**Blocked-by chain:** A-01 → A-02 → A-03 → A-04 → A-05

---

## Epic B: MARKET READINESS & REVENUE (Tier 1 FAST)

**Priority: HIGH** — Revenue-generating core (85% resource allocation)

### B1: Conxius Enclave SDK (40% Allocation)

| # | Issue | Type | Priority | Source | Existing Issue |
|:---|:---|---|:---:|:---|:---:|
| B1-01 | **Launch Enclave SDK v1.0** — B2B licensing page, developer docs, API reference | FEATURE | 🔴 HIGH | Business Analysis §12 | — |
| B1-02 | **Rename internal crate from `lib-conclave-sdk` to `lib-enclave-sdk`** (deprecated name) | TECH DEBT | 🔴 HIGH | AGENTS.md mandate | — |
| B1-03 | **Fix secp256k1-sys Windows C compilation** (SDK blocked on Windows gcc) | BUG | 🔴 HIGH | Sync session | — |
| B1-04 | **Create Enclave SDK B2B licensing model** (pricing tiers, support SLAs) | TASK | MEDIUM | Business Analysis §10 | — |
| B1-05 | **Write Enclave SDK getting-started guide** for developers | DOCS | MEDIUM | Business Analysis §12 | — |
| B1-06 | **Publish Enclave SDK to crates.io** | TASK | MEDIUM | Product launch | — |

### B2: Conxius Wallet (25% Allocation)

| # | Issue | Type | Priority | Source | Existing Issue |
|:---|:---|---|:---:|:---|:---:|
| B2-01 | **Begin iOS Wallet port** (Android-only = 60%+ market unreachable) | FEATURE | 🔴 CRITICAL | Business Analysis §9 (R-06) | — |
| B2-02 | **OR: Identify iOS wallet integration partner** (Xverse, Leather, etc.) | RESEARCH | 🔴 CRITICAL | Business Analysis §9 | — |
| B2-03 | **Complete Conxius Wallet native migration** (Android) | FEATURE | 🔴 HIGH | Business Analysis §12 | — |
| B2-04 | **Wallet premium subscription model** (revenue stream) | FEATURE | MEDIUM | Business Analysis §10 | — |
| B2-05 | **Push notification backend** (for transaction alerts) | FEATURE | MEDIUM | Infra recommendation | — |
| B2-06 | **Multi-language support** (English, Afrikaans, Zulu, Xhosa — SA market) | FEATURE | LOW | Market fit | — |

### B3: Conxian Gateway (20% Allocation)

| # | Issue | Type | Priority | Source | Existing Issue |
|:---|:---|---|:---:|:---|:---:|
| B3-01 | **Identify 20 target enterprise design partners** (SA banks + UK/Europe) | TASK | 🔴 HIGH | Business Analysis §14 | — |
| B3-02 | **Secure first 3-5 design partner agreements** | TASK | 🔴 HIGH | Business Analysis §14 | — |
| B3-03 | **Build Gateway production SLA** | TASK | HIGH | Technical Readiness | — |
| B3-04 | **Complete Gateway B2B PoC with design partner** | FEATURE | HIGH | Business Analysis §10 | — |
| B3-05 | **Add Rootstock integration** (multi-chain hedge against Stacks risk) | FEATURE | MEDIUM | Business Analysis §8 (R-03) | — |
| B3-06 | **Add Liquid Network integration** | FEATURE | LOW | Business Analysis §8 | — |

---

## Epic C: TOKENOMICS & PROTOCOL (Tier 2 MEDIUM)

| # | Issue | Type | Priority | Source | Existing Issue |
|:---|:---|---|:---:|:---|:---:|
| C-01 | **Complete token consolidation spec** (1 fungible token + ERC-1155 NFT/metadata) | DESIGN | 🔴 HIGH | Research Findings | — |
| C-02 | **Deploy Stacks protocol contracts to mainnet** (currently testnet only) | TASK | 🔴 HIGH | Technical Readiness | — |
| C-03 | **Verify 207+ Clarity contracts compile cleanly** (all clarity-version = 4, epoch latest — confirmed) | TASK | HIGH | Technical Readiness — ✅ VERIFIED | — |
| C-04 | **Finalize token model design decision** (research complete, needs sign-off) | DECISION | HIGH | Research Findings | — |
| C-05 | **Implement token consolidation in Clarity** (1 token contract + ERC-1155 contracts) | FEATURE | HIGH | Business Analysis §9 (R-07) | — |
| C-06 | **Conxian Nexus mainnet deployment** | TASK | MEDIUM | Business Analysis §12 | — |
| C-07 | **Upgrade Unified Theory v2 → v2.1** (add δ, V_R, T_C, S_A variables) | DOCS | MEDIUM | Technical Readiness | — |

---

## Epic D: SECURITY & COMPLIANCE (Tier 1 OVERLAY)

**Priority: HIGH** — Applies to ALL epics

| # | Issue | Type | Priority | Source | Existing Issue |
|:---|:---|---|:---:|:---|:---:|
| D-01 | **External security audit engagement** (ZKC + SYI scope) | TASK | 🔴 HIGH | Technical Readiness (G1 gate) | — |
| D-02 | **ITIL4/5 standards assessment and integration plan** | RESEARCH | MEDIUM | Research Findings | — |
| D-03 | **ISO 20022 compliance verification** (Gateway) | TASK | MEDIUM | Business Analysis | — |
| D-04 | **ISO 27001 readiness assessment** | TASK | MEDIUM | Research Findings | — |
| D-05 | **ZSE (Zero Secret Egress) compliance audit** | TASK | MEDIUM | AGENTS.md mandate | — |
| D-06 | **Fail-closed behavior verification** (all production paths return err-u501/err-u503) | TASK | MEDIUM | AGENTS.md mandate | — |
| D-07 | **TEE security review** (enclave isolation validation) | TASK | MEDIUM | Business Analysis | — |
| D-08 | **Git vulnerability audit across all 10 submodules** | TASK | MEDIUM | User request — ✅ DONE (all clean) | — |

---

## Epic E: FUNDING & GROWTH

| # | Issue | Type | Priority | Source | Existing Issue |
|:---|:---|---|:---:|:---|:---:|
| E-01 | **Apply — Stacks Foundation Grant** ($50-500K, HIGH probability) | TASK | 🔴 HIGH | Business Analysis §10 | — |
| E-02 | **Apply — GitHub Secure OSS Fund** ($10-100K, MEDIUM probability) | TASK | 🔴 HIGH | Business Analysis §10 | — |
| E-03 | **Apply — Oracle for Startups** ($30K/yr in-kind, VERY HIGH probability) | TASK | 🔴 HIGH | Business Analysis §10 | — |
| E-04 | **Apply — AWS OSS Credits** ($10-50K) | TASK | MEDIUM | Business Analysis §10 | — |
| E-05 | **Apply — Alpha-Omega OSS Security** ($100-500K) | TASK | LOW | Business Analysis §10 | — |
| E-06 | **Create investor deck** (Pre-Seed/Seed, $500K-2M) | TASK | MEDIUM | Business Analysis §10 | — |
| E-07 | **Generate first $50K+ revenue** (SDK licensing + wallet premium) | TARGET | 🔴 HIGH | Business Analysis §14 (G1) | — |
| E-08 | **Identify 20 target enterprise design partners** | TASK | 🔴 HIGH | Business Analysis §14 | — |

---

## Epic F: ORGANIZATIONAL & STRATEGIC

| # | Issue | Type | Priority | Source | Existing Issue |
|:---|:---|---|:---:|:---|:---:|
| F-01 | **Restructure to 3-core focus** (Enclave SDK + Wallet + Gateway) | DECISION | 🔴 CRITICAL | Business Analysis §12 | — |
| F-02 | **Implement Three-Speed Framework** (FAST/MEDIUM/SLOW per project) | TASK | 🔴 HIGH | Business Analysis §12 | — |
| F-03 | **Pause Admin Dashboard + Admin Pulse BOS** (0% allocation) | DECISION | 🔴 HIGH | Business Analysis §12 | — |
| F-04 | **Reduce Conxius Platform to maintenance mode** (2% allocation) | DECISION | 🔴 HIGH | Business Analysis §12 | — |
| F-05 | **Set up Go/No-Go Gates** (G1 90d, G2 180d, G3 12mo) | TASK | 🔴 HIGH | Business Analysis §14 | — |
| F-06 | **Define team roles** (owner per workstream) | TASK | HIGH | Business Analysis §9 | — |
| F-07 | **Phase 7 NixOS control plane migration** | TASK | MEDIUM | Technical Readiness | — |
| F-08 | **Create BOS Knowledge Graph crystallization process** | TASK | MEDIUM | AGENTS.md mandate | — |
| F-09 | **Deploy own Stacks + Bitcoin node** (mini-PC, $1,500-2,500 CAPEX) | TASK | HIGH | Business Analysis §11 | — |
| F-10 | **Set up Hetzner cloud** (EU hosting for Gateway API) | TASK | MEDIUM | Business Analysis §11 | — |

---

## Existing Linear Issues (Cross-Reference)

| Issue | Status | Subject | Source |
|:---|:---:|:---|:---|
| CON-343 | Existing | Kwil Adapter implementation | Knowledge Graph |
| CON-396 | Existing | State root persistence | Knowledge Graph |
| CON-162 | Existing | Block commitment storage | Knowledge Graph |
| CON-164 | Existing | MMR node storage | Knowledge Graph |
| CON-401 | Existing | Settlement proposal tracking | Knowledge Graph |
| CON-158 | Existing | (referenced in DOCUMENTATION_ALIGNMENT_INDEX) | Doc Alignment |
| CON-152 | Existing | (referenced in DOCUMENTATION_ALIGNMENT_INDEX) | Doc Alignment |
| CON-157 | Existing | (referenced in DOCUMENTATION_ALIGNMENT_INDEX) | Doc Alignment |
| CON-160 | Existing | (referenced in DOCUMENTATION_ALIGNMENT_INDEX) | Doc Alignment |
| CON-131 | Existing | (referenced in DOCUMENTATION_ALIGNMENT_INDEX) | Doc Alignment |
| CON-325 | Existing | (referenced in DOCUMENTATION_ALIGNMENT_INDEX) | Doc Alignment |
| CON-326 | Existing | (referenced in DOCUMENTATION_ALIGNMENT_INDEX) | Doc Alignment |
| CON-327 | Existing | (referenced in DOCUMENTATION_ALIGNMENT_INDEX) | Doc Alignment |

---

## Critical Path Dependency Map

```
A-01 Free disk space ───────────────────┐
                                        ├── A-03 cargo test
A-02 Configure F: drive ────────────────┘       │
                                                ├── A-04 conxian-gateway build
A-06 setup_windows.ps1 ───────────────────────┘  │
                                                 │
B1-01 Enclave SDK v1.0 ───────────────┐          │
B2-01 iOS Wallet ─────────────────────┤          │
B3-01 Enterprise partners ────────────┤          │
C-01 Token consolidation ─────────────┤          │
C-02 Mainnet deployment ──────────────┤          │
E-01 Grant applications ──────────────┤          │
                                      ├──────────┘
E-07 First $50K revenue ◄─────── G1 (90 days)
                                      │
F-01 Restructure to 3-core ──────────┘
```

**G1 Gate Criteria (90 days):**
- 3+ grant wins OR $50K+ revenue OR 2+ design partners
- If failed: Pause all non-core, re-evaluate strategy

---

## Quick-Start: First Actions

If you want to start immediately, here are the **7 most impactful items** in order:

| Order | Issue | Why First |
|:---:|:---|---|
| 1 | **A-01**: Free disk space | Blocks EVERYTHING else |
| 2 | **F-01**: Restructure to 3-core | Changes how you allocate effort |
| 3 | **E-03**: Oracle for Startups | Highest probability, free infra immediately |
| 4 | **E-01**: Stacks Foundation Grant | $50-500K, HIGH probability |
| 5 | **B2-01**: iOS Wallet decision | Critical gap — 60% of market |
| 6 | **B3-01**: Identify 20 design partners | Starts revenue engine |
| 7 | **C-01**: Token consolidation spec | Unblocks mainnet clarity |
