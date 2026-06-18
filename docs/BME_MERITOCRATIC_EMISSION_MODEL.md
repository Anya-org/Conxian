# CXIP-013 Addendum: Meritocratic Emission Logic

## 1. Objective
Define the deterministic criteria for CXD emission under the Burn-Mint Equilibrium (BME) model.

## 2. Activity Markers (Leaf)
Emissions are calculated based on verifiable on-chain events:

| Activity | Metric | Verification Contract |
|----------|--------|-----------------------|
| **DEX Liquidity** | SqrtPrice * Tick | `concentrated-liquidity-pool.clar` |
| **Lending Volume** | MarketUtilization | `lending-manager.clar` |
| **Bounty Settlement**| JobCardCompletion | `bme-engine.clar` |
| **Governance** | VotingPower * Tenure | `proposal-engine.clar` |

## 3. Burn Trigger (Root)
Protocol revenue collected in STX, sBTC, or other assets is automatically routed to the `revenue-distributor.clar` which executes:
1. **Swap-to-CXD**: Using the `swap-router.clar` to buy back CXD from the open market.
2. **Burn**: Sending CXD to the `0x00...00` dead address.

## 4. Equilibrium Formula
System Health (H) = Σ(Burn) / Σ(Mint).
- If H > 1: Protocol is deflationary (Healthy).
- If H < 0.8: Protocol is inflationary (Defensive mode triggered, emission rates throttled by 20%).

## 5. Implementation Status
The `bme-engine.clar` (v1.2.0) has been verified to handle the minting hooks, and the `revenue-distributor.clar` successfully routes 100% of fees for buy-back and burn as of April 2026.
