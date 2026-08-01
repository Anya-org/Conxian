# Conxian Protocol: Agent Directives (July 31, 2026 — Production Readiness Hardened)

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
- **Clarity Version**: Clarity 4 with each contract's active `Clarinet.toml` epoch authoritative for generated plans. The default remains Epoch 3.0; `proof-of-reserves` explicitly requires Epoch 3.3 for `to-consensus-buff?`. Use `stacks-block-time` and `burn-block-height`.
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
<!-- BEGIN GENERATED KNOWLEDGE-BASE FACTS -->
- **Contract inventory**: 246 physical `contracts/**/*.clar` files and 247 active `Clarinet.toml` contract entries. The intentional `math-lib-concentrated` alias shares `contracts/math/concentrated-math.clar` with `concentrated-math`.
- **Test inventory**: 114 `*.test.ts`/`*.spec.ts` source files under `tests/`.
- **Production release plans**: 220 contract publishes in 12 publish batches and 13 total batches, including 26 wiring/call transactions, in each checked-in testnet and mainnet plan.
- **CLP V2 release inclusion**: `concentrated-math-v2` and `concentrated-liquidity-pool-v2` are present in the active manifest and both production release plans.
<!-- END GENERATED KNOWLEDGE-BASE FACTS -->
- **Clarinet configs**: `Clarinet.toml` is active; `Clarinet.complete.toml` is retained as a legacy artifact.
- **Key tokens**: CXD (stablecoin), CXLP (LP), CXVG (governance) — consolidated from 6 to 3 tokens per Sprint 2026-07
- **Key NFTs**: position-nft and bridge-nft (SIP-009 compliant), enhanced-governance-nft (soulbound)

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

### Concentrated Liquidity V2 Boundary

- `contracts/math/concentrated-math-v2.clar` is the V2 math source of truth. It uses a fixed `1e12` sqrt-price scale and a bounded linear tick grid, not Uniswap's logarithmic ticks.
- `contracts/dex/concentrated-liquidity-pool-v2.clar` is the V2 custody, execution, range-position, fee, and exact accounting source of truth. Canonical range positions are non-transferable records, and exact-input swaps are bounded.
- Legacy `concentrated-liquidity-pool` and transferable CXLP semantics remain separate compatibility surfaces. `liquidity-manager` and `swap-router` expose separately named V2 entrypoints rather than changing legacy behavior.
- Protocol-fee release remains fail-closed until governance approves collector policy and an exact, authenticated ingress/custody path.
- Reference: [`docs/CLP_V2_EXECUTABLE_MODEL.md`](docs/CLP_V2_EXECUTABLE_MODEL.md), [`contracts/dex/README.md`](contracts/dex/README.md), and [`contracts/math/README.md`](contracts/math/README.md).

## 8. Deployment Pipeline (July 2026 Sprint)

### Current workflow safety state (verified July 26, 2026)

Both `.github/workflows/deploy-testnet.yml` and `.github/workflows/deploy-mainnet.yml` are **preflight/plan-only**. They validate checked-in plans and produce plan-only artifacts; neither workflow signs, broadcasts, or invokes an on-chain deployment command.

Issue #531 supplied the preflight, plan-validation, and evidence-verification control foundation; it did not add an authorized live broadcaster or establish deployment proof. Non-dry attempts remain blocked before signing/broadcast absent an approved signer-derived mainnet SP/SM identity, an authorized receipt-producing broadcaster/execution path, complete plan-bound receipts and readbacks, and resolution of still-open policy or implementation gates such as #527–#530. Unresolved plan identities must not be used or capitalized, and workflow success or plan artifacts are not deployment proof.

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
- All release contracts: `clarity-version: 4`, manifest-authoritative per-contract `epoch`, `anchor-block-only: true`. Current generated plans retain Epoch 3.0 except `proof-of-reserves`, which is Epoch 3.3.

### CI Workflows
- **Validate** (PR + push): `clarinet check` → `run-tests.sh` → `coverage`
- **Native manifest evidence**: on July 26, 2026, the PR #583 native Clarinet job checked all 242 active manifest entries with Clarinet 3.21.0 ([run evidence](https://github.com/Conxian/Conxian/actions/runs/30199636138/job/89787240720)).
- **Dated post-merge evidence**: on July 26, 2026, protocol CI at merge commit `2351aa279e586ebf9bf54f8b6c1dad80ef0dbe05` reported 99 passed/8 skipped test files and 509 passed/59 skipped tests ([run evidence](https://github.com/Conxian/Conxian/actions/runs/30200013711)). These totals are historical run evidence, not a timeless suite-size guarantee.
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

### ~~P2-2: Native Clarinet Validation Unavailable~~ -- FIXED IN CI
- Native Clarinet 3.21.0 CI validates the active manifest. Local availability remains environment-dependent; use CI evidence rather than assuming a workstation binary is installed.

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

## 12. Deployment Prerequisites and Blockers -- CURRENT STATUS (July 31, 2026)

Live deployment prerequisites are not complete. Issue #531 supplied the preflight, plan-validation, and evidence-verification control foundation; it did not add an authorized live broadcaster or establish deployment proof. Both deployment workflows remain preflight/plan-only, and non-dry attempts are blocked before signing/broadcast absent an approved signer-derived mainnet SP/SM identity, an authorized receipt-producing broadcaster/execution path, complete plan-bound receipts and readbacks, and resolution of still-open policy or implementation gates such as #527–#530.

### Session 46 Production Audit Findings
- **Mainnet deployer identity**: `ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P` is a simnet-only testnet address. Cross-referenced in `docs/MAINNET_READINESS_MARCH_2026.md`. Requires legal entity establishment before SP address can be generated.
- **Deployment plans**: 224 contracts across 12 batches in mainnet/testnet plans. 8 contracts added in PR #609.
- **CODEOWNERS**: Domain-based review gates active. GitHub teams need population.
- **Clarinet binary**: Removed from git. Install locally or in CI.
- **Testnet mnemonic**: Documented as simnet-only in `settings/Testnet.toml`. The address holds no value on any live network.
- **Staged branch**: Synced with main (was 25+ commits behind).

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
- cxs-token.clar stub implementation (P2-3)

## CI Status (July 31, 2026 — Production Readiness Hardened)
- Native Clarinet 3.21.0 CI has checked all 247 active `Clarinet.toml` entries; use the linked run above as the durable evidence.
- Test inventories are source counts, not execution guarantees. Record changing pass/skip totals only as dated run evidence.
- Runtime error detection active via `run-tests.sh`: allowlists 4 known benign contracts, fails on new errors.
- **Session 47**: Bootstrap noise eliminated — 4 contracts (conxian-protocol, dex-factory, office-manager, mock-token) removed from `contractsToInit` in `setup-test-env.ts` since they lack `initialize()` functions. The `run-tests.sh` allowlist is retained as defense-in-depth.
- Deploy workflows (testnet + mainnet) validate plans and produce preflight artifacts only; non-dry attempts are blocked before signing/broadcast.
- **NEW**: `verify-deployment-evidence.yml` (PR #608) — standalone Hiro API evidence verification workflow.
- **NEW**: `scripts/validate-deployment-plan.rb` (PR #608) — Ruby semantic plan validator.
- **NEW**: `scripts/deployment/verify-evidence.ts` v1.1.0 (PR #608) — fail-closed evidence verifier, 19 failure classifications.
- **NEW**: `.github/CODEOWNERS` (PR #609) — domain-based review gates.
- **FIXED**: Clarinet binary removed from git (PR #609). Install locally or via CI setup.
- **FIXED**: 8 contracts added to all deployment plans (PR #609).
- `staged` branch synced with `main` on both `Conxian/Conxian` and `conxian-business` (Session 46).

### Session 46 PR Summary
| PR | Repo | Description |
|----|------|-------------|
| #608 | Conxian/Conxian | Deployment receipt verification pipeline |
| #609 | Conxian/Conxian | Production readiness: CODEOWNERS, binary cleanup, deploy plans |
| #975 | conxian-business | Submodule pin after receipt verification |
| #976 | conxian-business | Submodule pin after production hardening |

### Session 47 CI/CD Fixes (July 31–Aug 1, 2026)
| PR | Repo | Description |
|----|------|-------------|
| #615 | Conxian/Conxian | ZKML quarantine guard: 49→0 test failures, documentation bypass detection, real-repo false positive fix, dlc-manager stub test fix, bootstrap noise elimination |
| #980 | Conxian/conxian-business | CI/CD fixes: deepseek-triage guard, ZKML submodule bumps, conxian-market submodule bump |
| #1211 | Conxian/conxius-platform | pnpm.overrides.next 15.5.18→16.2.12 version sync |
| — | Conxian/conxian-market | CI: skip absolute URLs in doc link checker (pushed to main)

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
    "prompt": "Read AGENTS.md and verify generated repository facts with npm run verify:knowledge-base. Run npm run validate:docs. If GitHub access is available, inspect the live open-issue set and report label gaps without copying a static issue table into AGENTS.md. Report any misalignments found.",
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
| `docs-validate.yml` | PR + push to main for relevant paths | Test and run local docs/knowledge validators, check external links, and validate required state files |
| `session-tracker.yml` | Workflow completion | Track session outcomes in DOCUMENTATION_STATE.md |

---

## 14. Session Alignment Protocol (Per-Session Induction)

### Every Session Checklist

1. **Pull latest**: `git fetch origin && git log --oneline -1 origin/main`
2. **Verify repository facts**: Run `npm run verify:knowledge-base`; use `npm run update:knowledge-base` only when the delimited generated block needs refresh.
3. **Sync state**: Update DOCUMENTATION_STATE.md with session results
4. **Validate docs**: Run `npm run validate:docs`.
5. **Verify live issues**: If authenticated GitHub access is available, use `gh issue list --repo Conxian/Conxian --state open`; do not maintain a static issue table here.
6. **Align docs**: If contract changes were made, update the corresponding README.md.

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

## 15. Live Issue and Knowledge Verification

- Do not treat historical session issue tables as current truth. Query live issues with `gh issue list --repo Conxian/Conxian --state open` when authenticated access is available.
- Run `npm run verify:knowledge-base` for deterministic contract, manifest, test-source, release-plan, and CLP V2 inclusion facts.
- Run `npm run validate:docs` for local documentation targets and knowledge JSON validity.
- `scripts/kb-sync.sh --dry-run` is a compatibility entrypoint for these read-only checks. It does not update docs, commit, push, label issues, or mutate GitHub.
- Deployment workflows remain preflight/plan-only; issue state, CI success, and checked-in plans are not deployment proof.

