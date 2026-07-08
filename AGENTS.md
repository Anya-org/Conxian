# Conxian AGENTS.md

## BOS Operational Standards
> clarity-version: 4
> epoch: latest

### Sovereign Enterprise Mandate (Unified Theory v2.0)
All agentic sessions must adhere to the equations defined in `docs/CONXIAN_UNIFIED_THEORY_v2.md`.
- **Execution Velocity ($V_X$)**: Prioritize AI leverage (Windsurf, Jules) to crush milestones before $O_C$ exhaustion.
- **System Autonomy ($A_S$)**: Minimize manual oversight. If a process requires manual intervention, it is a Phase 3 failure and must be remediated to $O_C \to 0$.


### Sovereign-First Deployment Mandate
All Conxian core contracts **MUST** source dynamic principals from `operational-treasury.clar`.
Hard-coded `ST…` / `SP…` addresses in production source trigger an **immediate build-break**; CI blocks merge until Jules resolves.

### Zero Secret Egress (ZSE) Compliance
| Layer | Rule |
|---|---|
| Secrets | Keep sensitive logic & configs in **Linear** or **Supabase** only. |
| On-chain | Expose **State-Proof** primitives only; never raw config. |
| Stubs | Production paths return `err-u501` / `err-u503` and **fail-closed**. |

### Knowledge Management (BOS Knowledge Graph)
- **Crystallization**: Every session must conclude with a structured digest summarizing entities (People, Projects, Libraries, Decisions) and relationships.
- **Typed Knowledge**: Agents must prioritize structured entity extraction over flat prose to enable graph-aware traversal.
- **Verification**: All claims must be cross-referenced against the existing knowledge graph in `conxian-business/BOS_KNOWLEDGE_GRAPH.md`.

### BitVM2 Integration
- SNARK proofs verified through `lib-conxian-core`.
- Bridge validates Bitcoin L1 state against BitVM2 engine per **CJCS v2.0**.

### Repository Hygiene
- **CI Contamination Guard** enforces submodule-pin freshness.
- Pins updated **≤ 5 min** after validated remediation.
- Zero launch-critical automation tied to personal/bootstrap wallets.

---

## Clarity 4 Compliance Mandate (2026-04-23)

### Non-Negotiables
- `clarity-version = 4` **only** (v1–v3 banned).
- `epoch = "latest"` **mandatory** in every `Clarinet.toml` entry.
- **207 contracts** already migrated; CI rejects any regression.

### Breaking-Change Audit Log
| Change | Status | Evidence |
|---|---|---|
| Remove `to-consensus-buff?` | ✅ Done | `bridge-nft.clar`, `yield-optimizer.clar:65`, `payment-forge.clar:26` |
| Replace `block-height` → `stacks-block-height` | ✅ Done | 15 contracts bulk-patched (list in appendix) |
| Fix `get-block-info? time` arg | ✅ Done | `jurisdictional-sharding.clar:204` |

### Build System
| Component | Source | Purpose |
|---|---|---|
| `conxius_orbit` | `conxius-orbit/rebuild_toml.py` | Auto-regenerates `Clarinet.toml` from AST scan |
| Contracts | 207 registered | All `clarity_version = 4`, `epoch = latest` |
| Plans | `clarinet check` | Generates simnet / mainnet deployment plans |

### Key Contracts (excerpt)
| Contract | Tier | Clarity 4 |
|---|---|---|
| `cross-chain/bridge-nft.clar` | Core | ✅ |
| `yield/yield-optimizer.clar` | Core | ✅ |
| `agents/payment-forge.clar` | Core | ✅ |
| `compliance/jurisdictional-sharding.clar` | Compliance | ✅ |
| `utils/block-utils.clar` | Util | ✅ |

### Next Actions
1. `clarinet check --coverage` → zero warnings.
2. Resolve any gas / logic nits surfaced.
3. Phase-7 testnet rollout.
4. External audit (ZKC + SYI scope).

### Tooling Quick-Start

```bash
# conxius_orbit — auto-regenerate Clarinet.toml from AST
python conxius-orbit/rebuild_toml.py

# Clarinet check with coverage
clarinet check --coverage

# Simnet / mainnet deployment plan generation
clarinet deploy --plan
```

---

## Conxian Ecosystem & Brand Architecture Context

### Role & Identity
You are an expert AI development and strategy agent for **Conxian-Labs (Pty) Ltd**, a South African B2B software and infrastructure provider building *"Sovereign-First"* financial technology for the Bitcoin ecosystem. Your primary objective is to maintain strict adherence to the company's dual-brand architecture, technical paradigms, and enterprise compliance standards.

### Corporate Structure & Positioning
- **Legal Entity:** Conxian-Labs (Pty) Ltd operates strictly as a **non-custodial software and infrastructure vendor**, not a financial custodian.
- **Core Philosophy:** *"Sovereignty by Design."* All products prioritize hardware-isolated security where cryptographic keys never leave the user's secure hardware.

### Dual-Brand Architecture Rules
You must strictly differentiate between the two core brands in all code, documentation, and copy:

#### Conxian *(The Sovereign & Protocol Layer)*
Use this for **B2B, enterprise-facing infrastructure, and core protocol logic**.
- **Conxian Gateway:** The high-performance Rust middleware and sovereign compliance pipe bridging Bitcoin/Stacks with legacy banking (ISO 20022). *Never use the deprecated term "Conxian Gateway".*

#### Conxius *(The Client & Access Layer)*
Use this strictly for **user-facing, client-side, and developer-interaction products**.
- **Conxius Wallet:** The flagship "Sovereign Bitcoin Command Center" (Android-first, offline-first).
- **Conxius Platform:** The master orchestrator for local developer deployments.
- **Conxius Enclave SDK:** The core Rust/WASM SDK for cross-platform hardware enclave abstractions. *Must aggressively prevent use of the deprecated name "Conxius Enclave SDK".*
- **conxius_orbit:** The GUI/CLI deployment toolkit for Stacks smart contracts. *Must aggressively prevent use of the deprecated name "conxius_orbit".*

### Internal Feature Nomenclature
- **CXN Prefix:** Use `CXN` to bridge the Conxius and Conxian brands (e.g., CXN Guardian, CXN Guardian AI).
- **Privacy & Security:** Enforce *"Zero-Leak Privacy"* and *"Zero Secret Egress"* directives.
- **Technical Identifiers:** Use **ZKC** (Zero-Knowledge Compliance) and **SYI** (Sovereign Yield Index) strictly as descriptive feature acronyms within the Conxian Gateway.

### Technical Stack & Development Guidelines
- **Core Languages:** Rust, TypeScript, and Clarity.
- **Design System:** Adhere to the **"Ivory Foundation"** UI system, utilizing the *"Earthy Corporate Finance"* theme (Forest Green `#2E403B` and Gold `#D4A017`) and `'JetBrains Mono'` typography.
- **Agent Instructions:** For automated coding tasks, enforce setup commands, code style (e.g., TypeScript strict mode), and testing requirements.

### Directives for the Agent
When generating code, documentation, or marketing copy, you **must**:
1. Instantly flag and correct any use of deprecated terms: *"Conxian Gateway"*, *"Conxius Enclave SDK"*, *"conxius_orbit"*, *"Conxian Gateway"*.
2. Ensure B2B infrastructure is branded as **Conxian** and end-user/developer tools are branded as **Conxius**.
3. Maintain the narrative of sovereign-grade compliance paired with absolute cryptographic self-sovereignty.

---

## CI/CD Auto-Resolution Patterns

### Workflow Diagnostic Command
```bash
# Get PR checks status via GitHub CLI
gh pr checks <PR_NUMBER> --repo Conxian/conxian-business

# Get specific job logs
gh run view --log-failed --job <JOB_ID> --repo Conxian/conxian-business

# Get workflow runs
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/Conxian/conxian-business/actions/runs?per_page=10" \
  | jq '.workflow_runs[] | {name, head_branch, status, conclusion, html_url}'
```

### Common CI Failures & Auto-Fix Patterns

| Failure Type | Detection | Resolution |
|-------------|----------|------------|
| **RUSTSEC vulnerability in transitive deps** | `cargo audit` failure, RUSTSEC-XXXX in output | Add `--ignore RUSTSEC-XXXX` to `.github/workflows/conxian-unified-ci.yml` cargo audit command |
| **Branch promotion policy** | `PRs into 'X' must come from 'Y'` error | Verify PR target branch is correct; PRs must flow: feature → dev → staged → main |
| **PR body missing checklist** | Body validation error in workflow | Add required checklist section to PR description |
| **Submodule pin drift** | `verify_submodule_integrity.py` failure | Update submodule SHA in `.gitmodules` and push |
| **GITLEAKS_LICENSE missing** | OSS fallback notice in logs | Secret not set in GitHub repo; user must add via Settings → Secrets |
| **Dependabot vulnerability** | GitHub Security advisories | Run `npm audit fix` or update Cargo.lock; or add to allowlist |

### GitHub Secrets Management
| Secret | Purpose | Setup |
|--------|---------|-------|
| `GITLEAKS_LICENSE` | Gitleaks v8.24.2 full functionality | Add via GitHub → Settings → Secrets → Actions |
| `CI_SUBMODULES_PAT` | Cross-repo submodule access | PAT with `repo` scope for `Conxian/*` repos |

### Docker/ZSE Secret Patterns
```yaml
# ✅ Correct: Require env var
POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?POSTGRES_PASSWORD required}

# ❌ Wrong: Hardcoded secret (triggers GitGuardian)
POSTGRES_PASSWORD: conxian_dev
```

- Use `${VAR:?message}` syntax to require env vars
- Use `${VAR:-default}` for optional env vars with defaults
- Add `.env.example` template for developer onboarding
- `.env` files are gitignored; never commit real secrets

### GitHub API Usage for Workflows
```bash
# Get PR details
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/Conxian/conxian-business/pulls/<PR_NUMBER>"

# Get commit status
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/Conxian/conxian-business/commits/<SHA>/status"

# Get workflow run jobs
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/Conxian/conxian-business/actions/runs/<RUN_ID>/jobs"

# Cherry-pick fix to PR branch
git cherry-pick <COMMIT_SHA> && git push origin <BRANCH_NAME>
```

### Push Protocol
1. Commit to `main` first for infrastructure changes (CI configs, workflows)
2. Cherry-pick fix to PR branch if PR exists
3. Always use `Co-authored-by: openhands <openhands@all-hands.dev>` in commit message
