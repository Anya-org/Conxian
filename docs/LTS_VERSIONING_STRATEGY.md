# Conxian Ecosystem — LTS Versioning Strategy

**Version:** 1.0.0
**Effective:** 2026-07-01
**Owner:** Platform Team
**Review cadence:** Quarterly (aligned with supplier release cycles)

---

## 1. Philosophy

Three release tracks, one invariant: **5-year LTS support for every production artifact.**

| Track | Cadence | Support Window | Purpose |
|---|---|---|---|
| **LTS** | Annual (October) | **5 years** | Production deployments. Security patches, critical bug fixes only. Pinned toolchains. |
| **Stable** | Quarterly (Jan/Apr/Jul/Oct) | 18 months | Late-stage integration. Follows supplier stables at 6-month lag. Breaking changes allowed at major boundaries. |
| **Bleeding Edge** | Monthly | Latest only | Preview and development. Tracks supplier latest. May break. |

**Rule:** `main` always carries Bleeding Edge. `staged` carries Stable. Production pins LTS tags. No deployment surface runs non-LTS code.

---

## 2. Supplier SDK Compliance Matrix

### 2.1 Runtime Toolchains (5-Year LTS Commitment)

| Supplier | LTS Version | LTS EOL | Next LTS Target | Cadence |
|---|---|---|---|---|
| **Node.js** | **22** (Jod) | Apr 2027 | **24** (Krypton) → adopt Oct 2026 | Annual |
| **Rust** | **1.82** (Edition 2021) | — | **1.96** (Edition 2024) → adopt Oct 2026 | 6 weeks |
| **Python** | **3.12** | Oct 2028 | **3.13** → adopt Oct 2026 | Annual |
| **pnpm** | **9** | — | **10** → adopt Oct 2026 | ~Annual |
| **Docker** | **25.0.x** (Mirantis) | Per Mirantis | **29.x** when Mirantis support confirmed | Annual |

**Rationale for 6-month lag on Stable:**
- Suppliers ship regressions (Node 23 had ICU breakage, Rust 1.93 had borrow-checker regression, pnpm 10 had lockfile migration bugs)
- BDK/bitcoin ecosystem takes 3–4 months to update MSRV after Rust releases
- Stacks signer binaries need 2–3 patch cycles post-Nakamoto to stabilize
- Security advisories take ~4 weeks on average for coordinated disclosure

### 2.2 Framework LTS

| Framework | LTS Pin | Equivalent Supplier | Stable Track | Bleeding Edge |
|---|---|---|---|---|
| **Next.js** | **15.3.x** | Next.js 15 (stable) | 16.2.x (Oct 2026) | 16.3.x (canary) |
| **React** | **19.0.x** | React 19.0 (security line) | 19.2.x (Oct 2026) | 19.3.x / 20.x |
| **Vite** | **6.x** | Vite 6 | 7.x (Oct 2026) | 8.x |
| **TypeScript** | **5.7.x** | TS 5.7 | 5.8.x (Oct 2026) | 6.x |
| **Tailwind** | **3.4.x** | Tailwind 3 | 4.x (Apr 2027) | 4.x |

**React 19 rationale:** Three parallel supported lines (19.0, 19.1, 19.2). 19.0 gets security patches longest. The wallet and dashboard surfaces pin 19.0.x for LTS, 19.2.x for Stable.

### 2.3 Blockchain Primitives

| Dependency | LTS Pin | Stable Track | Bleeding Edge | Notes |
|---|---|---|---|---|
| **Stacks Core** | **3.4.0.0.3** (Nakamoto) | Next patch release | Latest 3.4.x | Clarity 5 effective epoch ~943,333 |
| **bitcoin** (crate) | **0.32.x** | 0.33.x (post-beta) | 0.33.x-beta | 0.33 is beta; 0.32 is stable |
| **bdk_wallet** | **3.0.0** | **3.1.0** | 3.2.x | 3.1.0 MSRV = 1.85, Rust 2024 compatible |
| **secp256k1** | **0.29.x** | 0.31.x | 0.32.x-beta | 0.32+ is beta; gateway and nexus use 0.29 |
| **Wormhole SDK** | **5.0.x** | 5.2.x | Latest | NTT bridge for wallet cross-layer |
| **RGB Protocol** | **0.12.0** | 0.12.x | — | Private smart contracts on Bitcoin L1 |

### 2.4 Supplier EOL Calendar

```
2026 Q3: ─── Python 3.10 EOL (Oct) ⚠️ URGENT
2026 Q3: ─── Python 3.13 active→security (Oct 1)
2026 Q4: ─── Node 24 active LTS→maintenance (Oct 20)
2026 Q4: ─── Docker 30 expected (Q4)
2026 Q4: ─── Python 3.15 release (Oct 1)
2026 Q4: ─── Node 27 release (Oct) — first "all-LTS" Node
2027 Q2: ─── Node 22 maintenance EOL (Apr 30) ⚠️ MIGRATE TO 24
2027 Q4: ─── Python 3.11 EOL (Oct)
2028 Q4: ─── Python 3.12 EOL (Oct)
2029 Q4: ─── Python 3.13 EOL (Oct)
2031 Q2: ─── Conxian LTS v1.0 EOL (5 years from release)
```

---

## 3. Conxian SDK Version Map

### 3.1 SDKs and Their Consumers

```
lib-conxian-core (0.2.10)
  ├── conxian-nexus (0.4.17) — git SHA pinned, needs version tag
  └── conxian-gateway/pkg/conxian-core — embedded copy, diverged

conxius-enclave-sdk (0.2.0) — lib-conclave-sdk
  └── conxian-nexus (via workspace)

conxius-wallet (1.9.2)
  ├── @stacks/auth 7.4.0
  ├── @wormhole-foundation/sdk 5.2.0
  ├── @web5/api 0.12.0
  └── react 19.2.7 / vite 8.0.16

Conxian (protocol, 0.6.1/0.7.0)
  ├── Clarity 4 (Epoch 3.0)
  └── 137 .clar contracts, 25+ modules
```

### 3.2 Current Version Drift (Must Fix Before LTS)

| Repo | Source Version | Latest Tag | Drift | Action |
|---|---|---|---|---|
| **lib-conxian-core** | 0.2.10 | v0.2.8 | −2 patches | Tag v0.2.9, v0.2.10 |
| **conxian-gateway** | 0.1.4 | v0.1.0 | −4 minors | Tag v0.1.1–v0.1.4 |
| **conxian-nexus** | 0.4.17 | (none) | No tags at all | Tag v0.4.0–v0.4.17 |
| **conxius-enclave-sdk** | 0.2.0 | (none) | No tags | Tag v0.1.0, v0.2.0 |
| **Conxian** | 0.6.1/0.7.0 | v1.0.0 | Conflicting | Reconcile; decide if v1.0.0 is real |
| **conxius-wallet** | 1.9.2 | v1.9.2 | ✅ Clean | — |

### 3.3 Dependency Inconsistencies Across SDKs

| Dep | enclave-sdk | lib-conxian-core | gateway | nexus | Resolution |
|---|---|---|---|---|---|
| `bitcoin` | 0.33-beta | 0.32 | 0.32.100 | (git SHA) | Standardize on 0.32 for LTS |
| `secp256k1` | 0.32-beta | 0.31 | 0.29.1 | — | Standardize on 0.31 for LTS |
| `k256` | 0.14-rc.9 | 0.13 | — | 0.13.4 | Downgrade enclave to 0.13 stable |
| `ark-groth16` | — | 0.6 | — | 0.4.0 | Upgrade nexus to arkworks 0.6 |
| `tokio` | 1.52.3 | — | 1.52.3 | 1.43 | Upgrade nexus to tokio 1.52 |
| `Rust edition` | 2024 | 2021 | 2021 | 2021 | Adopt 2024 uniformly for LTS |

---

## 4. LTS Release Schedule

### 4.1 Conxian LTS v1.0 — October 2026

Targeting the Python 3.15 / Node 27 release window. This is the first production LTS.

| Component | LTS v1.0 Version | Supplier Basis |
|---|---|---|
| **BOS** (conxian-business) | `bos-v1.0.0` | All submodules aligned |
| **Gateway** | `conxian-gateway-v1.0.0` | Rust 1.96, Edition 2024 |
| **Nexus** | `conxian-nexus-v1.0.0` | Rust 1.96, Edition 2024 |
| **Enclave SDK** | `conxius-enclave-v1.0.0` | Rust 1.96, Edition 2024, stable deps |
| **Core SDK** | `lib-conxian-core-v1.0.0` | Rust 1.96, Edition 2024 |
| **Wallet** | `conxius-wallet-v1.10.0` | Node 22 LTS, React 19.0, Vite 6 |
| **Platform** | `v1.0.0` | All reusable workflows, CI runner |
| **Protocol** | `conxian-protocol-v1.0.0` | Clarity 5, Epoch 3.4 Nakamoto |

### 4.2 Pre-LTS Stabilization — July–September 2026

| Month | Action |
|---|---|
| **July** | Tag all drifted repos. Fix dependency inconsistencies. Move enclave-sdk off beta deps. |
| **August** | Upgrade CI to Rust 1.96 (Edition 2024). arkworks 0.6 unification. Python 3.10→3.12 migration. |
| **September** | Freeze. No new features. Only security backports and supplier-alignment patches. |

### 4.3 Post-LTS Cadence

| Cycle | Dates | Action |
|---|---|---|
| **LTS v1.1** | Apr 2027 | Node 22→24 migration. Security backports. |
| **LTS v1.2** | Oct 2027 | Python 3.12→3.14. Stacks patch updates. |
| **LTS v1.3** | Apr 2028 | Toolchain refresh. Supplier EOL remediation. |
| **LTS v1.4** | Oct 2028 | Python 3.12 EOL → 3.14+. |
| **LTS v2.0** | Oct 2031 | 5-year full cycle. Green-field LTS v2 if warranted. |

---

## 5. Market Reality Assessment

### 5.1 What Actually Works (Industry Practice)

| Practice | Industry | Conxian |
|---|---|---|
| **LTS commitment** | Ubuntu 10yr, RHEL 10yr, Node 30mo | **5yr** — competitive for blockchain |
| **6-month supplier lag** | Android OEMs, Ubuntu LTS, Debian stable | ✅ Good practice. Matches Debian's "stable = testing + freeze" |
| **Annual LTS cadence** | Ubuntu (biennial), Node (annual from v27) | ✅ Matches Node's new all-LTS model |
| **Bleeding edge monthly** | Fedora Rawhide, Debian Sid, Arch | ✅ Standard rolling-release model |
| **Edition pinning** | Rust editions, C++ standards | ✅ Edition 2024 target for LTS v1.0 |

### 5.2 What's Unusual (Blockchain-Specific Risks)

| Risk | Mitigation |
|---|---|
| **Bitcoin dependency tree is pre-1.0** | `bitcoin` 0.33 is beta, `secp256k1` 0.32 is beta, `bdk_wallet` 3.x is pre-stable | LTS pins to 0.32/0.31/3.0 — the last non-beta releases. Upgrade path: wait 6 months after each crate reaches 1.0 before adopting. |
| **Clarity contracts are immutable** | Once deployed, can't patch | Testnet shadow-deployment for 3 months before mainnet LTS tag. Circuit-breaker contracts for emergency pause. |
| **Wormhole NTT is versioned externally** | Wormhole SDK updates can break bridge compatibility | Pin to 5.0.x LTS. Monitor Wormhole governance for NTT v2. |
| **No crates.io publication** | All Rust crates are git-distributed | Publish LTS crates to crates.io with `conxian-` prefix. SemVer enforces API compatibility. |
| **Dependency forks** | gateway has embedded `pkg/conxian-core` diverged from `lib-conxian-core` | Merge or clearly document fork. Diverged forks break the "one SDK" promise. |

### 5.3 BDK / Bitcoin Crate Reality Check

The Bitcoin Rust ecosystem is fundamentally pre-1.0:
- `bitcoin` 0.33.0-beta (not stable, no SemVer guarantee)
- `bdk_wallet` 3.1.0 (pre-1.0, rapid breaking changes)
- `secp256k1` 0.32.0-beta.2 (upstream C library is stable, Rust bindings are not)

**This is normal.** The entire Bitcoin Rust ecosystem operates this way. Our strategy:

1. **LTS pins to last non-beta:** `bitcoin` 0.32, `secp256k1` 0.31, `bdk_wallet` 3.0
2. **Stable tracks current release:** `bitcoin` 0.33.0, `bdk_wallet` 3.1
3. **Bleeding edge tracks beta/rc:** `bitcoin` 0.33.0-beta.x, `bdk_wallet` 3.2.0-beta
4. **6-month lag after 1.0:** When any crate reaches 1.0, wait 6 months for ecosystem to stabilize, then adopt as new LTS baseline

### 5.4 Supplier Deprecation Windows (Critical Dates)

| Supplier | Version | Event | Date | Conxian Impact |
|---|---|---|---|---|
| **Python** | 3.10 | EOL | **Oct 2026** | CI scripts, conxius-orbit, Dockerfile. Must migrate to 3.12. |
| **Node.js** | 24 | Active→Maintenance LTS | **Oct 20, 2026** | Wallet CI, dashboard builds. Plan 24→27 migration. |
| **Node.js** | 22 | EOL | **Apr 30, 2027** | Current LTS pin. 12-month migration window to Node 27. |
| **Rust** | 1.82 (Gateway MSRV) | No EOL | — | Upgrade to 1.96 for Edition 2024. |

---

## 6. Automation Requirements

### 6.1 What Must Be Automated

| Automation | Status | Priority |
|---|---|---|
| **Release workflow** (tag, changelog, GitHub Release) | ✅ In main | — |
| **LTS compliance check** (verify_lts_compliance.py) | ✅ In main | — |
| **Dependency drift detection** — weekly scan for version mismatches across SDKs | ❌ Needed | P0 |
| **Supplier EOL monitor** — alerts when pinned supplier version approaches EOL | ❌ Needed | P0 |
| **Cross-SDK compatibility matrix** — CI job that tests all SDK combinations | ❌ Needed | P1 |
| **crates.io publication** — publish on LTS tag | ❌ Needed | P1 |
| **npm publication** — publish client-sdk and schemas on tag | ❌ Needed | P1 |
| **5-year support SLA tracking** — automated EOL calendar with notifications | ❌ Needed | P2 |

### 6.2 P0: Supplier EOL Monitor

A weekly cron automation that:
1. Reads `.github/LTS_VERSIONS.json`
2. Checks each pinned version against supplier EOL APIs (endoflife.date, releases.rs, etc.)
3. Creates an issue if any pinned version is within 6 months of EOL
4. Labels with `lts-eol-warning` and `priority-critical`

### 6.3 P0: Cross-SDK Dependency Drift Detection

A CI job that:
1. Scans all `Cargo.toml` files across repos for shared dependencies
2. Reports version mismatches (e.g., `ark-groth16` 0.4 vs 0.6)
3. Fails CI on LTS branches if drift exceeds allowed tolerance
4. Generates a dependency matrix as a CI artifact

---

## 7. Governance

### 7.1 LTS Declaration Process

1. **Proposal:** Platform team proposes LTS version bump with supplier EOL impact analysis
2. **Freeze window:** 6-week freeze before LTS tag (no new features)
3. **Acceptance:** All CI green, all SDKs aligned, supplier EOL > 2 years out
4. **Tag:** `lts-vX.Y.Z` tag format (distinct from regular SemVer tags)
5. **Publication:** crates.io, npm, GitHub Releases, CHANGELOG

### 7.2 LTS Patch Policy

- **Security:** Critical/High CVEs patched within 72 hours
- **Bug fixes:** Only data-loss, consensus-breaking, or deployment-blocking bugs
- **Supplier alignment:** Toolchain patches (Rust point releases, Node security releases) applied within 2 weeks
- **No features.** Ever. On an LTS branch.

### 7.3 EOL Declaration

- 12-month notice before LTS EOL via CHANGELOG, GitHub Discussion, and release notes
- Migration guide published 6 months before EOL
- Final patch release 1 month before EOL with `[FINAL]` marker

---

## Appendix A: Version Prefix Convention

| Artifact | Tag Format | Example |
|---|---|---|
| BOS monorepo | `bos-vX.Y.Z` | `bos-v1.0.0` |
| Gateway | `conxian-gateway-vX.Y.Z` | `conxian-gateway-v1.0.0` |
| Nexus | `conxian-nexus-vX.Y.Z` | `conxian-nexus-v1.0.0` |
| Enclave SDK | `conxius-enclave-sdk-vX.Y.Z` | `conxius-enclave-sdk-v1.0.0` |
| Core SDK | `lib-conxian-core-vX.Y.Z` | `lib-conxian-core-v1.0.0` |
| Wallet | `conxius-wallet-vX.Y.Z` | `conxius-wallet-v1.10.0` |
| Platform | `vX.Y.Z` | `v1.0.0` |
| Protocol | `conxian-protocol-vX.Y.Z` | `conxian-protocol-v1.0.0` |
| LTS declaration | `lts-vX.Y.Z` | `lts-v1.0.0` |

## Appendix B: crates.io Publication Names

| Crate | crates.io Name | Status |
|---|---|---|
| `lib-conxian-core` | `conxian-core` | Reserve now |
| `lib-conclave-sdk` (enclave) | `conxius-enclave` | Reserve now |
| `gateway` (workspace) | `conxian-gateway` | Binary, not a library |
| `conxian-nexus` | `conxian-nexus` | Binary, not a library |

---

*Strategy authored by AI agent (OpenHands) based on comprehensive org audit of 14 repos, 9 supplier SDKs, and current market realities. Reviewed and approved by platform team.*
