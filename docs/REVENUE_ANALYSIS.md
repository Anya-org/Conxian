# Revenue Flow & Dynamic Intelligence Analysis (Feb 2026)

## 1. Executive Summary
The Conxian Protocol implements a sophisticated, cybernetic revenue management system known as "The Fiscal Dam V4" (CXIP-013). This system utilizes autonomous agents to assess risk and performance, dynamically adjusting the distribution of protocol income to ensure long-term solvency and growth.

## 2. Revenue Generation Mechanisms
Protocol revenue is currently sourced from these contract-supported channels:
- **DEX Operations**: Swap fees collected via `swap-router.clar`. Fees are dynamically capped at 100 bps (1.0%) to mitigate LVR (Loss Versus Rebalancing).
- **Lending Markets**: A 10% reserve factor is applied to interest paid by borrowers in `lending-manager.clar`.
- **Integration Fees**: Registered integrations can accrue STX fees through `integration-fee-collector.clar` using per-use or monthly billing.
- **Service Subscriptions**: The STX-only enterprise subscription MVP uses an
  explicit prepaid plan route with exact payment amounts and no automatic
  renewal. It is separate from integration-fee policy and has its own
  subscriber/consumer authorization boundary.

### Integration Fee Flow (STX-first)
`integration-registry.clar` stores integration configuration and SHA-256 API-key
commitments; raw API keys are authenticated off-chain and never enter the
contracts. A configured reporter records replay-protected usage IDs. The
collector tracks usage and fees by integration and burn-block period, then
accepts an exact payer settlement only after the monthly period closes when
monthly billing is selected.

Settled STX moves through the existing `revenue-distributor.clar`
`distribute-stx` route under collector contract context and terminates in the
`cxd-treasury` Fiscal Dam accounting buckets. It does not end at
`swap-router`. This is a 100% protocol route with no partner split, so the
existing CXIP-013 economics remain authoritative. Generic FT settlement is
deferred to a future two-step deposit-and-route design, and payer-signed usage
attestations are a future trust-boundary hardening step.

### Enterprise subscription route
Enterprise payments use the canonical gross-STX sequence:

```text
subscriber -> enterprise-subscription -> revenue-automation
           -> revenue-distributor -> cxd-treasury
```

The treasury receipt snapshots the policy version and all six integer
allocations. Payment IDs are globally unique across the subscription route;
usage IDs are replay-protected per paid period. Bucket recipients are not
preconfigured, and buyback remains only a governed STX allocation until a
separate native-STX adapter exists.

### Registration fees — roadmap only

Registration fees are **not currently a contract-supported revenue source**.
Issue [#504](https://github.com/Conxian/Conxian/issues/504) remains a roadmap
item. The bounded Phase 3 work adds only the read-only
`compliance-manager.is-registration-compliant` gate; it does not add a fee
amount, escrow manager, refund lifecycle, activation path, or revenue route.
The gate requires a fresh `compliance-manager` record plus an existing,
minimum-tier, non-sanctioned record from the authoritative `kyc-registry`.
It does not treat the legacy manager `sanctions-checked` boolean as registry
evidence; `compliance-hooks.verify-kyc` therefore remains a tier/update hook,
not a sanctions attestation.

The issue's earlier bounty/operations wording is not an approved split. The
repository policy in [`CXIP-013.md`](../CXIP-013.md) currently says registration
fees use 100% vault recycling. That conflict remains explicitly deferred until
an approved registration-fee policy exists.

## 3. Dynamic Intelligence: The AYE Agent (`agent-risk.clar`)
The "AYE" Risk Agent serves as the protocol's sensory organ, tracking:
- **Global Collateral Ratio (GCR)**: The ratio of total system collateral to total debt.
- **Performance Metrics**: MoM TVL growth and bounty completion rates.
- **External Risk Factors**: Liquidity depth, hash-rate volatility, and Bitcoin mempool congestion.
- **PID Controller**: Dynamically adjusts stability fees to maintain the CXD price peg.

## 4. The Fiscal Dam V4 (`agent-treasury.clar`)
Revenue is routed based on system state transitions:
- **CRISIS (GCR < 110%)**: 100% allocation to the Insurance Vault.
- **STABILITY (110% < GCR < 150%)**: CXIP-013 Performance-Adjusted Baseline.
  - *Standard Baseline*: 45% Treasury, 30% Bounty, 15% LP, 5% Grant, 5% Buy-back.
  - *Performance Shift*: +5% to Bounty (from Treasury) if TVL growth > 12% or Bounty Rate > 95%.
- **ABUNDANCE (GCR > 150%)**: 80% LP Incentives, 10% Treasury, 10% Insurance.

## 5. Execution & Enforcement (`revenue-distributor.clar`)
The distributor ensures that every unit of STX or FT revenue is split according to the active policy.
- **Diverted Claims**: If the LP share falls below the 15% target due to policy adjustments, the system records "diverted claims" in `cxd-treasury.clar` for future compensation during Abundance phases.

## 6. Operational Enhancements & Recommendations
1. **Granular Debt Tracking**: Incorporate protocol-wide debt-to-equity ratios into `agent-risk.clar` for more nuanced GCR calculations.
2. **Volatility Triggers**: Implement automated "Flash Rebalancing" triggers in `agent-treasury.clar` to respond to extreme market volatility within a single block.
3. **Transparency Dashboard**: Expose `get-cybernetic-intel` data to a public-facing UI for real-time protocol health monitoring.
4. **Doc-Code Alignment**: Update token READMEs to reflect that voting power logic is centralized in `cxvg-token.clar`, not `cxd-token.clar`.
