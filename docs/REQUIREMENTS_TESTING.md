# Requirements (Testing & Verification)

## 1. Unit Test Cases (Core Primitives)

### 1.1. Fiscal Policy (Revenue Distributor)
- **TEST_REV_01**: Verify that a 10,000 uSTX deposit is split exactly 6000/2000/2000 across Staking, Dev, and Insurance vaults.
- **TEST_REV_02**: Verify that only the Admin (currently) or the Strategic Council (target) can modify allocation percentages in `allocation-policy.clar`.
- **TEST_REV_03**: Verify that total shares must always sum to 10,000 (100%).

### 1.2. Governance (Dual-Council)
- **TEST_GOV_01**: Verify that `submit-proposal` in `proposal-engine.clar` requires the sender to hold an `enhanced-governance-nft` seat.
- **TEST_GOV_02**: Verify that `vote` in `community-voting-engine.clar` correctly applies reputation weighting from `reputation-engine.clar`.
- **TEST_GOV_03**: Verify that non-compliant users (blacklisted in `regulatory-adapter.clar`) cannot vote in the Strategic Council.

### 1.3. Autonomous Agents (Staff)
- **TEST_AGENT_01**: Verify that `agent-risk` can correctly identify a position below maintenance margin.
- **TEST_AGENT_02**: Verify that the `office-manager` pays the agent the correct uSTX "salary" upon successful liquidation.

## 2. Compliance Checklist (Release Prep)

### 2.1. Structural Standards
- [ ] All public functions have `@desc` documentation.
- [ ] Constants use `UPPER_CASE` and variables use `kebab-case`.
- [ ] No `lambda` keywords present (Clarity 2 compatibility).

### 2.2. Regulatory Standards
- [ ] `regulatory-adapter` contains latest "Clean-Hands" whitelist.
- [ ] All Strategic Council entry points have `check-compliance` assertions.
- [ ] Circuit breaker integrated into all high-value transfer functions.

### 2.3. Nakamoto/Clarity 4 Standards
- [ ] `burn-block-height` used for all temporal logic (Vesting, Voting).
- [ ] `get-block-info?` used for tenure-aware timestamps.
- [ ] `Clarinet.toml` epoch set to `"3.0"`.

## 3. Definition of Done (DoD)
- [x] Code passes `clarinet check`.
- [x] Code passes full `npm test` suite.
- [x] Documentation synchronized with implementation in `PRD.md`.
- [x] Changelog updated with version 0.3.0 changes.
