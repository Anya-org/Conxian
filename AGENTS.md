# Conxian Protocol: Agent Directives (July 2026 — Sprint Complete)

## 0. Knowledge Base Automation (M2M Native Induction)

### OpenHands Automation Framework
This repository uses OpenHands Cloud automations for knowledge base maintenance and cross-session alignment.

#### Active Automations
| Automation | Trigger | Purpose |
|------------|---------|---------|
| **Repo Sync & Alignment** | Cron: `0 9 * * *` (daily) | Pull latest code, sync AGENTS.md, verify alignment |
| **Issue Triage** | Event: `issues.opened` | Auto-label, prioritize, and route new issues |
| **PR Review Assistant** | Event: `pull_request.opened` | Run standards validation, post automated review |
| **Documentation Validator** | Event: `push` to main | Validate docs freshness, check for broken links |
| **Session State Tracker** | Event: `workflow_run.completed` | Update DOCUMENTATION_STATE.md with session results |

#### M2M Integration Patterns
- **GitHub App (openhands-ai)**: Primary M2M identity for cross-repo operations
- **GitHub Actions Workflows**: Repository-level CI/CD automation (see `.github/workflows/`)
- **KV Store State**: Automations persist "last processed" state between runs
- **Webhook Filters**: Use JMESPath expressions to filter events (see automation docs)

#### Automation Best Practices (per GitHub Agentic Workflows best practices)
1. **Human-in-the-loop**: All agent drafts go through PR review; no auto-commits
2. **Mirrored Checkouts**: For cross-repo edits, use separate tokens per repo
3. **Docs-Worthy Gate**: Automation validates if changes require documentation
4. **Progressive Rollout**: Start with narrow scope, expand with validation
5. **Embed Drift Monitoring**: Track when KB content drifts from source truth

#### Environment Variables for Commits
**ALWAYS use environment variables for git commits to avoid email privacy issues:**

```bash
# Set environment variables BEFORE any git operations
export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-openhands}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-openhands@all-hands.dev}"
export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-openhands}"
export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-openhands@all-hands.dev}"

# Configure git to use environment (overrides .gitconfig)
git config --global user.useconfigonly true

# Verify before committing
git var GIT_AUTHOR_NAME
git var GIT_AUTHOR_EMAIL
```

**Verification Steps:**
1. Check `git var GIT_AUTHOR_EMAIL` returns `openhands@all-hands.dev`
2. If push fails with "GH007: Your push would publish a private email address":
   - Amend with: `git commit --amend --reset-author`
   - Or set env vars and recommit

**Current Config Status:**
- ✅ Environment variables verified for commits
- Use `GIT_AUTHOR_EMAIL=openhands@all-hands.dev` for commits
- Push via PR required (main branch protected)
- PR pending: [#490](https://github.com/Conxian/Conxian/pull/490)

---

## 1. System Build Ethos
- **Sovereign Autonomy**: All core logic must be autonomous. Avoid manual admin interventions.
- **Nakamoto Alignment**: Use `burn-block-height` for slow-path strategy and `block-height` for fast-path reflexes.
- **Defensive Engineering**: NO `unwrap-panic` in public functions or critical logic. Use `try!`, `match`, or `unwrap!` with explicit errors.
- **CXIP-013 Compliance**: All revenue must flow through the 6-way Fiscal Dam V4.
- **Root-to-Leaf Integrity**: Centralize decision logic in Risk/Treasury agents; keep Core engines as pure executive layers.

## 2. Technical Standards
- **Clarity Version**: Clarity 4 (Epoch 3.0) for Mainnet. Use `stacks-block-time` and `burn-block-height`.
- **SIP Standards**: Strict adherence to SIP-010 (FT) and SIP-009 (NFT). Transfer functions MUST handle optional memos.
- **Principal Injection**: Avoid hardcoding contract literals. Use `data-vars` for external contract principals to support modularity and resolve circular dependencies in tests.

## 3. Operational Directives
- **Dual-Clock Heartbeat**: The `trigger-epoch-update` in `ops-engine.clar` is the protocol's heartbeat. Ensure it is efficient and incentivized.
- **Predictive Risk**: `risk-unit.clar` is the canonical liquidation/risk-score unit; `risk-manager.clar` is query-compatible only, while `agent-risk` publishes normalized scores through explicit wiring.
- **Financial Accuracy**: Always normalize asset decimals (e.g., STX u6 to CXD u8) when calculating TVL or protocol-wide metrics.

## 4. Troubleshooting
- **Circular Dependencies**: If tests fail with `CircularReference`, verify that all contracts use the "Principal Injection" pattern via public setters.
- Ensure `.ops-engine` is an authorized minter in `cxd-token.clar` for keeper rewards.
- Verify `.risk-unit` is authorized to call `liquidate-position` in `dimensional-core.clar`.

## 5. Testing Protocols
- **Root-to-Leaf**: Always verify system integration starting from the `ops-engine` heartbeat.
- **Leaf-to-Root**: Ensure individual manager contracts are unit-tested before integration.
- **Dual-Mode**: Use `block-utils.clar` for any time-based or C4-native operations in tests.

## 6. Business Operations System (BOS) Logic
- **Principal Registry**: All Conxian core contracts must use dynamic principals fetched via `operational-treasury.clar`.
- **Contamination Gating**: Any hardcoded `ST...` or `SP...` addresses in `contracts/` are considered a build-break. Jules must flag and fix these during the planning phase.
- **BitVM2 Compliance**: Job Card completions (CJCS v2.0) must be verified against the BitVM2 state root in `lib/clarity-bitcoin.clar` before settlement.

---

## 7. Architecture Overview (July 2026 Audit)

### Repository Scale
- **231 Clarity contract source files** across 45+ modules
- **76+ test files** (Vitest + Clarinet SDK)
- **2 Clarinet configs**: `Clarinet.toml` (232 contract-section entries, active) and `Clarinet.complete.toml` (231 contract-section entries, legacy)
- **Key tokens**: CXD (stablecoin), CXLP (LP), CXVG (governance) — consolidated from 6 to 3 tokens per Sprint 2026-07
- **Key NFTs**: position-nft (SIP-009 compliant), bridge-nft (NON-COMPLIANT), enhanced-governance-nft (soulbound)

### Contract Dependency Hierarchy
```
sip-standards / core-traits / defi-traits / conxian-csf-trait
    ↓
conxian-access / conxian-protocol / kyc-registry / regulatory-adapter
    ↓
cxd-token / oracle-aggregator / bme-engine / enhanced-circuit-breaker
    ↓
concentrated-liquidity-pool / swap-router / lending-manager / dimensional-engine
    ↓
agent-risk / agent-treasury / risk-unit / revenue-distributor / revenue-automation
    ↓
ops-engine (heartbeat) / alex-adapter / governance suite
```

## 8. Deployment Pipeline (July 2026 Sprint)

### Current workflow safety state (July 22, 2026)

Both `.github/workflows/deploy-testnet.yml` and `.github/workflows/deploy-mainnet.yml` are **preflight/plan-only**. They validate checked-in plans and produce plan-only artifacts; neither workflow signs, broadcasts, or invokes an on-chain deployment command.

Non-dry attempts are blocked before signing/broadcast pending issue #531's structured receipt-producing deployment path, upstream issues #527–#530, and an approved signer-derived mainnet SP/SM identity. Unresolved plan identities must not be used or capitalized, and workflow success or plan artifacts are not deployment proof.

| Target | Plan Ready | Current Workflow State | Live Deployment Proof |
|--------|------------|------------------------|-----------------------|
| **Testnet** | ✅ Yes | Preflight/plan-only | None claimed by the workflow |
| **Mainnet** | ✅ Yes | Preflight/plan-only | None claimed by the workflow |

### Historical deployment notes
- Historical session records include deployment-plan generation and CI validation. They are retained as audit context only and do not authorize a broadcast or establish current on-chain state.
- Any address check is scoped to the checked address or addresses; it must not be read as a claim of global nonexistence.

### Deployment Plans
- `deployments/full-system.testnet-plan.yaml` — 12 batches (11 contract-publish + 1 contract-call wiring; 216 publishes after adding CLP V2 and quarantining `zkml-verifier`)
- `deployments/full-system.mainnet-plan.yaml` — same 12-batch/216-publish structure, mainnet costs
- Generated via `scripts/gen-deployment-plans.py` from `default.simnet-plan.yaml`
- 9 test helpers excluded: `mock-circuit-breaker`, `mock-csf-protocol`, `mock-proposal`, `mock-regulatory-adapter`, `mock-token`, `mock-fee-source`, `mock-compoundable-vault`, `mock-admin-forwarder`, `test-c4-helper`
- All contracts: `clarity-version: 4`, `epoch: 3.0`, `anchor-block-only: true`

### CI Workflows
- **Validate** (PR + push): `clarinet check` → `run-tests.sh` → `coverage`
- **Deploy Testnet**: preflight/plan-only validation and artifact generation; non-dry requests are blocked before signing/broadcast.
- **Deploy Mainnet**: manual preflight/plan-only validation with exact confirmation, plan-hash, and identity gates; non-dry requests are blocked before signing/broadcast.
- **Clarinet version**: v3.21.0 is pinned for validation; the deployment workflows do not invoke a broadcast command.
- **Runtime error detection**: `run-tests.sh` captures fd 2, allowlists 4 known benign clarinet-sdk errors, fails on new errors

### Known Benign Noise
4 contracts produce non-fatal "Runtime error while interpreting" during simnet init:
`conxian-protocol`, `dex-factory`, `office-manager`, `mock-token`

These are clarinet-sdk v3.21.0 artifacts from plan regeneration with different random seeds. Not contract bugs. Allowlisted in `run-tests.sh`.

## 9. Critical Issues (P0 — Block Deployment)

### ~~P0-1: cxd-token.clar SIP-010 Trait Type Mismatch~~ ✅ FIXED
- `get-name` and `get-symbol` now return 32-char padded strings matching the trait.

### ~~P0-2: dimensional-core.clar Missing Liquidation Authorization~~ ✅ FIXED
- `liquidate-position` now gated to `.risk-unit`, `.risk-manager`, or contract admin.

### ~~P0-3: CXIP-013 Emission Weights~~ ✅ FIXED
- Weights aligned: DEX 45% (u4500), Bounty 30% (u3000), Gov 15% (u1500), Grants 10% (u1000).
- Lending category replaced with Grants; `register-grants-activity` added.

### ~~P0-4: bme-engine swap-and-burn Stub~~ ✅ FIXED
- `swap-and-burn` now routes tokens to `.swap-router`, executes `csf-swap`, receives CXD, burns via `cxd-token.burn`.
- `revenue-distributor` pre-transfers tokens to `.bme-engine` before calling.
- `distribute-stx` now routes STX to `.swap-router`.

## 9. High-Priority Issues (P1)

### P1-1: 77 unwrap-panic Calls (PRIVATE/READ-ONLY) -- MONITORED
- 32 files affected; common patterns: check-clean-hands-compliance, has-role, map-get?
- User-facing paths (swap-router, lending-manager, dimensional-core) are now clean
- Remaining are in compliance gates, oracle adapters, registry lookups -- fail-hard semantics acceptable for these
- Will address in post-testnet audit sweep

### ~~P1-2: ops-engine.clar No Authorization~~ FIXED
- trigger-heartbeat, trigger-epoch-update, trigger-emergency-pause now admin-gated.

### ~~P1-3: bridge-nft.clar Non-SIP-009 Compliant~~ FIXED
- Added impl-trait, transfer, get-last-token-id, get-token-uri, get-owner.

### ~~P1-4: Testnet Deployment Plan Address Mismatch~~ FIXED
- All 18 expected-sender entries corrected to testnet deployer address.
- Mainnet manifest expanded from 14 to 55 contracts across 9 phased batches.

### ~~cxd-token.clar Burn Authorization Bug~~ FIXED
- burn function now checks burners map instead of is-minter.

## 10. Medium-Priority Issues (P2)

### ~~P2-1: alex-adapter.clar Stub Implementation~~ -- FIXED (July 2026)
- execute-csf-swap calls ALEX swap-helper-v1-03 via compile-time constant.
- claim-conxian-yield routes through alex-reserve-pool.
- get-csf-health queries reserve pool balance.
- ALEX protocol addresses documented with source URLs.
- Uses define-constant for integration references (Clarity requires static principals for contract-call?).

### P2-2: Test Suite Cannot Run -- REMAINING
- Requires clarinet binary (not installed in CI/workspace).

### P2-3: cxs-token.clar Stub Token -- REMAINING
- transfer is no-op; all balances return 0.

### P2-4: revenue-distributor.clar Hardcoded References -- PARTIAL
- Pre-transfer logic fixed; relative contract references remain.

## 11. What Passed Audit

| Area | Status | Detail |
|------|--------|--------|
| Hardcoded principals | SCOPED CLEAN | `scripts/verify_contamination_guard.py` found no matches for its configured testnet-contamination principal in scanned core paths; this is not a global ST.../SP... audit |
| Principal injection | GOOD | All admin/owner state initialized via tx-sender |
| cxlp-token.clar SIP-010 | COMPLIANT | 32-char padded strings, correct transfer |
| cxtr-token.clar SIP-010 | COMPLIANT | 32-char padded strings, correct transfer |
| cxvg-token.clar SIP-010 | COMPLIANT | 32-char padded strings, correct transfer |
| position-nft.clar SIP-009 | COMPLIANT | Full SIP-009 interface implemented |
| bridge-nft.clar SIP-009 | COMPLIANT | Full SIP-009 interface implemented (July 2026) |
| cxd-token.clar SIP-010 | COMPLIANT | 32-char padded strings, correct burn auth (July 2026) |
| revenue-automation.clar | COMPLIANT | 100 bps fee enforced correctly |
| risk-unit.clar liquidation | COMPLIANT | Tiered thresholds, proper auth, cache management |
| operational-treasury.clar | SOLID | Principal registry, multi-path authorization |
| enhanced-circuit-breaker | PRESENT | Multi-tier isolation, global pause |
| bme-engine.clar CXIP-013 | COMPLIANT | Weights aligned: DEX 45%, Bounty 30%, Gov 15%, Grants 10% |
| dimensional-core.clar | SECURE | liquidation-position gated to risk-unit/risk-manager/admin |

## 12. Deployment Prerequisites and Blockers -- CURRENT STATUS

Live deployment prerequisites are not complete. Both deployment workflows remain preflight/plan-only, and non-dry attempts are blocked before signing/broadcast pending issue #531's structured receipt-producing deployment path, upstream issues #527–#530, and an approved signer-derived mainnet SP/SM identity.

Unresolved plan identities must not be used or capitalized, guessed signer identities are invalid, and workflow results are not deployment proof. Address checks remain scoped to the addresses checked and do not establish global nonexistence.

### Historical sprint checklist (July 2026 records; not current deployment proof)

1. ~~Fix cxd-token get-name/get-symbol~~ -- DONE (P0-1)
2. ~~Add liquidation auth to dimensional-core~~ -- DONE (P0-2)
3. ~~Align BME weights with CXIP-013~~ -- DONE (P0-3)
4. ~~Implement actual swap-and-burn~~ -- DONE (P0-4)
5. ~~Add auth to ops-engine heartbeat functions~~ -- DONE (P1-2)
6. ~~Fix testnet deployment plan~~ -- DONE (P1-4)
7. ~~Implement bridge-nft SIP-009~~ -- DONE (P1-3)
8. ~~Verify BitVM2 attestation in clarity-bitcoin.clar~~ -- HARDENED
9. ~~Finalize mainnet manifest~~ -- DONE (216 contracts, 11 publish batches)
10. ~~Deploy to testnet~~ -- historical record referenced block 28719280478 and 4.37 STX; not revalidated here and not current workflow proof
11. ~~Deploy to mainnet~~ -- historical record referenced block 28732058625 and 10.79 STX; not revalidated here and not current workflow proof
12. ~~Merge all sprint PRs (#446, #447, #448, #449, #450)~~ -- DONE

### Remaining Protocol Work (not deployment authorization)
- Replace 63 private/read-only unwrap-panic calls (P1-1)
- Complete alex-adapter with real ALEX contract calls (P2-1)
- cxs-token.clar stub implementation (P2-3)

## CI Status (July 2026 -- Preflight-Only Deployment State)
- `clarinet check` passes on all active contracts in `Clarinet.toml`.
- Test suite: 7 suites pass (236 known benign clarinet-sdk stderr warnings suppressed).
- Runtime error detection active via `run-tests.sh`: allowlists 4 known benign contracts, fails on new errors.
- Deploy workflows (testnet + mainnet) validate plans and produce preflight artifacts only; non-dry attempts are blocked before signing/broadcast.

---

## 13. OpenHands Automations Setup

### Available Automations (OpenHands Cloud)

Run the following curl commands to set up automations:

```bash
# 1. Daily Repo Sync & Alignment (Cron-based)
curl -X POST "${OPENHANDS_HOST}/api/automation/v1/preset/prompt" \
  -H "Authorization: Bearer ${OPENHANDS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Conxian Daily Repo Sync",
    "prompt": "Pull latest code from origin/main. Read AGENTS.md and verify it is up-to-date with current branch. Check DOCUMENTATION_STATE.md and update if session results are missing. Verify all 4 open issues have corresponding labels. Report any misalignments found.",
    "trigger": {"type": "cron", "schedule": "0 9 * * *", "timezone": "UTC"}
  }'

# 2. Issue Triage (Event-based)
curl -X POST "${OPENHANDS_HOST}/api/automation/v1/preset/prompt" \
  -H "Authorization: Bearer ${OPENHANDS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Conxian Issue Triage",
    "prompt": "Analyze new issue. Extract: priority (P0/P1/P2 based on severity keywords), category (protocol-fee/treasury/security/dex/governance/other), and description summary. Post automated triage comment with labels suggestion.",
    "trigger": {
      "type": "event",
      "source": "github",
      "on": "issues.opened",
      "filter": "repository.full_name == '\''Conxian/Conxian'\''"
    }
  }'

# 3. PR Standards Validation (Event-based)
curl -X POST "${OPENHANDS_HOST}/api/automation/v1/preset/prompt" \
  -H "Authorization: Bearer ${OPENHANDS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Conxian PR Standards Check",
    "prompt": "Review the PR for: 1) Does it update AGENTS.md if changing agent-facing code? 2) Does it add tests for new contracts? 3) Does it update docs/STANDARDS_VALIDATION_SESSION_N.md for standards changes? Post review comments with pass/fail for each criterion.",
    "trigger": {
      "type": "event",
      "source": "github",
      "on": "pull_request.opened",
      "filter": "repository.full_name == '\''Conxian/Conxian'\''"
    }
  }'
```

### GitHub Actions Workflows (`.github/workflows/`)

The repository uses GitHub Actions for repository-level automation:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `validate.yml` | PR + push | `clarinet check` → `run-tests.sh` → coverage |
| `docs-validate.yml` | Push to main | Validate doc freshness, broken links |
| `session-tracker.yml` | Workflow completion | Track session outcomes in DOCUMENTATION_STATE.md |

---

## 14. Session Alignment Protocol (Per-Session Induction)

### Every Session Checklist

1. **Pull latest**: `git fetch origin && git log --oneline -1 origin/main`
2. **Check AGENTS.md**: Verify section 13 (Automations Setup) has current automation IDs
3. **Sync state**: Update DOCUMENTATION_STATE.md with session results
4. **Verify issues**: Ensure all open issues have appropriate labels
5. **Align docs**: If contract changes made, update corresponding README.md

### M2M Native Induction Pattern

```
[External Event] 
    → GitHub Webhook 
    → OpenHands Automation Trigger 
    → Agent Context (AGENTS.md loaded)
    → Task Execution
    → Human-in-the-loop (PR Review)
    → State Update (DOCUMENTATION_STATE.md)
    → Next Agent Context
```

---

## 15. Open Issues Summary (Session 34)

| # | Title | Priority | Labels | Status |
|---|-------|----------|--------|--------|
| 489 | [P0] MAINNET DEPLOYMENT NOT EXECUTED | P0 | deployment, critical | **ACTION REQUIRED** |
| 488 | [CON-1427] Implement 2% Protocol Fee Collection | HIGH | protocol-fee, treasury | OPEN |
| 480 | [P0] Developer Sandbox: TTFV < 15 minutes | P0 | deployment, developer-experience | OPEN |
| 458 | [HIGH] Fake mock pollution: createMockSimnet() returns hardcoded success | HIGH | bug, testing | OPEN |

**Historical deployment-status note (checked-address scope only):**
- Earlier records reported a zero-balance/zero-transaction check for one unresolved deployer address. That observation is historical, scoped to the checked address, and is not a global nonexistence claim or an approved signer identity.
- Current testnet and mainnet workflows are preflight/plan-only. Non-dry attempts are blocked before signing/broadcast pending issue #531, upstream issues #527–#530, and an approved signer-derived mainnet SP/SM identity.
- Do not use or capitalize the unresolved address, and do not treat a non-dry request as an operational path.

**Last Updated**: 2026-07-22

