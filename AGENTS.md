# Conxian Protocol: Agent Directives (Feb 2026)

## 1. System Build Ethos
- **Sovereign Autonomy**: All core logic must be autonomous. Avoid manual admin interventions.
- **Nakamoto Alignment**: Use `burn-block-height` for slow-path strategy and `block-height` for fast-path reflexes.
- **Defensive Engineering**: NO `unwrap-panic` in public functions or critical logic. Use `try!`, `match`, or `unwrap!` with explicit errors.
- **CXIP-013 Compliance**: All revenue must flow through the 6-way Fiscal Dam V4.

## 2. Technical Standards
- **Clarity Version**: Maintain Compatibility Mode (Clarity 2/3) for stable simulation. Pre-wire for Clarity 4 features as commented "Vision" code.
- **SIP Standards**: Strict adherence to SIP-010 (FT) and SIP-009 (NFT). Transfer functions MUST handle optional memos.
- **Temporal Logic**: Prefer `burn-block-height` for any logic involving value accrual or locking to align with Bitcoin tenure.

## 3. Operational Directives
- **Dual-Clock Heartbeat**: The `trigger-epoch-update` in `ops-engine.clar` is the protocol's heartbeat. Ensure it is efficient and incentivized.
- **Predictive Risk**: `agent-risk.clar` must use the PID controller to proactively manage GCR and stability fees.
- **Traceability**: Every state change MUST emit a structured event with a timestamp.

## 4. Troubleshooting
- If tests fail in Simnet, check block height thresholds for fast/slow paths.
- Ensure `.ops-engine` is an authorized minter in `cxd-token.clar` for keeper rewards.
- Verify `.agent-treasury` is authorized for rebalancing in `cxd-treasury.clar`.
