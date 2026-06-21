# Maintainer Payout Runbook (CON-167)

## Overview
This runbook defines the exact checks and steps required by Conxian maintainers to enable and execute bounty payouts after the mainnet launch.

## Pre-Activation Checklist
Before enabling payout-ready mode, verify the following:
1. [ ] **Mainnet Deployment**: ConxianCSF is fully deployed on Stacks mainnet (verified via `conxian-protocol.get-protocol-status`).
2. [ ] **ALEX Funding**: The source of funds from the ALEX launch path is active and the treasury contract (`cxd-treasury.clar`) shows accrued claims.
3. [ ] **Wallet Control**: Maintainer control over the execution wallet (dynamic principal or successor) is confirmed.
4. [ ] **Rollback Ready**: A backup plan exists to disable payouts if a post-deploy protocol vulnerability is detected.

## Payout Execution Workflow

### 1. Submission Review
- Verify implementation artifact matches Linear issue requirements.
- Confirm all CI checks (test, lint, standards) pass for the submission branch.
- Audit for "Secret Egress" or security vulnerabilities.

### 2. Approval Gating
- At least two maintainer sign-offs required for payouts exceeding u1000 (\~1000 CXD/STX equivalent).
- Map the submission to the `Done` status in Linear.

### 3. Disbursement
- Execute transfer from the authorized treasury/vault to the contributor address.
- Record the `native_tx_hash` in the Linear issue.

## Rollback Path
If payout mode must be disabled:
1. Call `set-service-paused true` on the payout-related contracts (if implemented) or use the `enhanced-circuit-breaker`.
2. Document the incident in the `Recovery Registry` (PRD Section 12).

---
**Status**: Restricted (Maintainer-Only)
**Reference**: CON-167, CON-230
