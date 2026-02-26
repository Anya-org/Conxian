# Revenue Flow & Dynamic Intelligence Analysis (Feb 2026)

## 1. Executive Summary
The Conxian Protocol implements a sophisticated, cybernetic revenue management system known as "The Fiscal Dam V4" (CXIP-013). This system utilizes autonomous agents to assess risk and performance, dynamically adjusting the distribution of protocol income to ensure long-term solvency and growth.

## 2. Revenue Generation Mechanisms
Protocol revenue is currently sourced from three primary channels:
- **DEX Operations**: Swap fees collected via `swap-router.clar`. Fees are dynamically capped at 100 bps (1.0%) to mitigate LVR (Loss Versus Rebalancing).
- **Lending Markets**: A 10% reserve factor is applied to interest paid by borrowers in `lending-manager.clar`.
- **Service Subscriptions**: Advanced monetary features require a subscription fee processed by `economic-policy-engine.clar`.

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
