# Economics: Sustainable and Profitable DeFi (Stacks)

## Objectives

- Lower operating cost (gas + ops) vs EVM norms
- Sustainable revenue with minimal rent-seeking
- Aligned incentives for users, LPs, and protocol DAO

## Fee Model

- Deposit fee: 0–30 bps (default 30 bps; dynamic via governance)
- Withdraw fee: 0–10 bps (default 10 bps)
- Performance fee (optional, later): 5–10% only on realized strategy yields (not principal)
- Fees accrue to protocol reserve with transparent events

Rationale: small bps fees provide a predictable, low-friction UX and stable protocol income without relying on inflationary token emissions.

## Cost Controls

- Favor simple, linear operations; avoid loops over user sets
- Minimize map writes; aggregate updates where possible
- Read-only queries for most views/pricing
- Batch parameter updates; timelock to prevent frequent churn

## Treasury & Runway

- Protocol reserve denominated in the base asset (e.g., sBTC or stable)
- DAO-controlled withdrawals with rate limits (per-period caps)
- Transparent reporting of inflows/outflows via events

## Token Strategy (Optional)

- If issuing a token, avoid high emissions; couple distribution to fee revenue
- Use buyback-and-make or fee-sharing with stakers only from realized revenue

## Differentiation via Bitcoin Layers

- Accept BTC-derivatives (e.g., sBTC) as primary collateral
- Leverage Stacks settlement (Bitcoin anchoring) for strong finality ties
- Prefer BTC-native integrations and strategies as they mature

## Risk Management

- Per-user and global caps to guard early growth phases
- Emergency pause and timelock for parameter changes
- Clear invariant tests in Clarinet; external audits prior to mainnet

## KPIs

- Net protocol revenue (fees) / TVL (bps)
- User cost-to-use: median gas/tx and effective bps vs competitors
- Reserve runway in months at current burn
- Retention: repeat depositors and time-weighted balances
