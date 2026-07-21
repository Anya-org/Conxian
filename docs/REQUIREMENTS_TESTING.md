# Requirements (Testing & Verification)

## 1. Unit Test Cases (Core Primitives)

### 1.1. Fiscal Policy (Adaptive Yield Engine)

- **TEST_REV_01**: Verify that the AYE initially targets a 60/20/20 split across Staking, Dev, and Insurance vaults.
- **TEST_REV_02**: Verify that `agent-treasury` utilizing PID control smoothly rebalances yields (max 1% shift per block) during risk state transitions.
- **TEST_REV_03**: Verify that total shares must always sum to 10,000 (100%).
- **TEST_REV_04**: Verify that "Accrued Claims" are correctly recorded in `cxd-treasury.clar` when staker dividends are diverted to the Insurance Fund.

### 1.2. Governance (Community & Strategic Voting Deferred)

- **TEST_GOV_01**: Verify that `submit-proposal` in `proposal-engine.clar` requires the sender to hold an `enhanced-governance-nft` seat.
- **TEST_GOV_02**: **Deferred** — Reputation-weighted voting through `community-voting-engine.clar` is not active; coverage remains pending an architecture/API design.
- **TEST_GOV_03**: **Deferred** — The community Strategic Council voting/compliance path is not active; coverage remains pending an architecture/API design.

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
- **TEST_GOV_RES_02**: Verify that the `reputation-engine` correctly decays voting weight for inactive "Board" members over a 52,560 block (1 year) period.

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

- [ ] `stacks-block-time` used for all temporal logic (Vesting, Voting).
- [ ] `contract-hash?` used for module verification in `conxian-protocol.clar`.
- [ ] `Clarinet.toml` epoch set to `"3.0"` and `clarity-version` set to `2` (stable).

## 3. Definition of Done (DoD)

- [x] Code passes `clarinet check`.
- [x] Code passes full `npm test` suite.
- [x] Documentation synchronized with implementation in `PRD.md`.
- [x] Changelog updated with version 0.3.0 changes.
