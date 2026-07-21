# Requirements (Testing & Verification)

## 1. Unit Test Cases (Core Primitives)

### 1.1. Fiscal Policy (Adaptive Yield Engine)

- **TEST_REV_01**: Verify that the AYE initially targets a 60/20/20 split across Staking, Dev, and Insurance vaults.
- **TEST_REV_02**: Verify that `agent-treasury` utilizing PID control smoothly rebalances yields (max 1% shift per block) during risk state transitions.
- **TEST_REV_03**: Verify that total shares must always sum to 10,000 (100%).
- **TEST_REV_04**: Verify that "Accrued Claims" are correctly recorded in `cxd-treasury.clar` when staker dividends are diverted to the Insurance Fund.

### 1.2. Governance (Dual-Council)

- **TEST_GOV_01**: Verify that `submit-proposal` in `proposal-engine.clar` requires the sender to hold an `enhanced-governance-nft` seat.
- **TEST_GOV_02**: Verify that `community-voting-engine.clar` snapshots nonzero aggregate CXVG supply at proposal creation, accepts only nonzero escrowed CXVG votes, stores one immutable vote per principal, and accounts for yes/no deposited totals. The denominator is not a per-wallet balance snapshot: tokens acquired after creation may vote only within the fixed aggregate escrow cap.
- **TEST_GOV_03**: Verify that non-compliant proposers and voters (as reported by the routed regulatory adapter) are rejected, and that missing or mismatched operational-treasury routes fail closed. Fresh simnet bootstrap wiring and testnet/mainnet plans must register the canonical `cxvg-token` and `regulatory-adapter` routes after publication.
- **TEST_GOV_04**: Verify future start blocks, positive bounded durations, `[start-block, end-block)` enforcement, per-proposal quorum and approval thresholds including exact equality, strict tie failure, permissionless one-time finalization, and one-time stake claims for both passed and failed proposals. A finalized claim remains live when the current token route rotates because the proposal stores the original token principal.
- **TEST_GOV_05**: Verify unknown proposal IDs, duplicate votes, zero amounts, zero supply, over-bound snapshots, snapshot-cap violations, wrong token/compliance traits, adapter errors versus negative compliance, insufficient-balance transfer failures, premature finalization, and double claims return deterministic errors without changing escrow state.
- **TEST_GOV_06**: Verify that the published maximum safe supply bounds finalization arithmetic without rounding governance thresholds; exact-bound and above-bound snapshots are covered by tests.
- **TEST_GOV_07**: Reputation weighting and arbitrary action execution are explicitly deferred. The current voting engine uses raw escrowed CXVG only and never calls `reputation-engine.clar` or executes proposal payloads.

### 1.3. Autonomous Agents (Staff)

- **TEST_AGENT_01**: (Agent-Risk 2.0) Verify that `assess-system-risk` correctly calculates composite scores from liquidity depth and hashrate volatility.
- **TEST_AGENT_02**: (Agent-Treasury) Verify that the PID controller integral windup protection prevents bps overflow during long-term rebalancing.
- **TEST_AGENT_03**: Verify that the "Staff" scanner loop in `check-work-needed` resets correctly after reaching the end of the position map.
- **TEST_AGENT_04**: Verify that only authorized "Staff" roles can trigger high-value operational actions in `ops-engine.clar`.

## 2. Investment-Grade Stress Tests (The "Stress Test" Suite)

### 2.1. Solvency & Liquidity

- **TEST_SOLV_01**: Simulate a 50% Bitcoin price crash and verify that `agent-risk` liquidates all under-collateralized positions before the Insurance Fund is triggered.
- **TEST_SOLV_02**: Verify that the `revenue-distributor` correctly halts distributions if the Insurance Fund falls below a predefined "Critical Reserve" threshold.

### 2.2. Governance Resilience

- **TEST_GOV_RES_01**: Verify that a malicious "Staff" agent cannot pause the protocol without Strategic Council (Board) approval for longer than a 144-block "Emergency Tenure."
- **TEST_GOV_RES_02**: Future-only requirement. Reputation weighting and decay are not integrated into `community-voting-engine.clar`; do not treat this as a current voting-engine acceptance test until a trustworthy reputation source and weighting policy are approved.

## 3. Compliance Checklist (Release Prep)

### 2.1. Structural Standards

- [ ] All public functions have `@desc` documentation.
- [ ] Constants use `UPPER_CASE` and variables use `kebab-case`.
- [ ] No `lambda` keywords present (Clarity 2 compatibility).

### 2.2. Regulatory Standards

- [ ] `regulatory-adapter` contains latest "Clean-Hands" whitelist.
- [ ] All Strategic Council entry points have `check-compliance` assertions.
- [ ] Circuit breaker integrated into all high-value transfer functions.

### 2.3. Nakamoto/Clarity 4 Standards

- [ ] `stacks-block-height` used for community voting windows; other temporal modules document their own approved clock.
- [ ] `contract-hash?` used for module verification in `conxian-protocol.clar`.
- [ ] Touched `Clarinet.toml` entries use Clarity 4 and an epoch supported by the repository toolchain.

## 3. Definition of Done (DoD)

- [x] Code passes `clarinet check`.
- [x] Code passes full `npm test` suite.
- [x] Documentation synchronized with implementation in `PRD.md`.
- [x] Changelog updated with version 0.3.0 changes.
