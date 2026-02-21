# Conxian Protocol: Agent Directives (Feb 2026)

## 1. System Build Ethos

- **Sovereign Autonomy**: All core logic must be autonomous. Avoid manual admin interventions.
- **Nakamoto Alignment**: Use `burn-block-height` (Bitcoin tenure) for slow-path strategy and `block-height` (Stacks tenure) for fast-path reflexes.
- **Defensive Engineering**: NO `unwrap-panic` in public functions or critical logic. Use `try!`, `match`, or `unwrap!` with explicit errors.
- **CXIP-013 Compliance**: All revenue must flow through the 6-way Fiscal Dam V4.
- **Root-to-Leaf Integrity**: Centralize decision logic in Risk/Treasury agents; keep Core engines as pure executive layers.

## 2. Technical Standards

- **Clarity Version**: Clarity 4 (Epoch 3.1 - Production Standard). Use `block-height` and `burn-block-height`.
- **SIP Standards**: Strict adherence to SIP-010 (FT) and SIP-009 (NFT). Transfer functions MUST handle optional memos.
- **Principal Injection**: **Mandatory standard.** Avoid hardcoding contract literals. Use `data-vars` for external contract principals to support modularity and resolve circular dependencies in tests.

## 3. Operational Directives

- **Dual-Clock Heartbeat**: The `trigger-epoch-update` in `ops-engine.clar` is the protocol's heartbeat. Ensure it is efficient and incentivized.
- **Predictive Risk**: `risk-manager.clar` consolidates liquidation decisions, factoring in `agent-risk` cybernetic scores.
- **Financial Accuracy**: Always normalize asset decimals (e.g., STX u6 to CXD u8) when calculating TVL or protocol-wide metrics.

## 4. Troubleshooting

- **Circular Dependencies**: If tests fail with `CircularReference`, verify that all contracts use the "Principal Injection" pattern via public setters.
- **Minter Roles**: Ensure `.ops-engine` is an authorized minter in `cxd-token.clar` for keeper rewards.
- **Authorization**: Verify `.risk-manager` is authorized to call `liquidate-position` in `dimensional-core.clar`.

## 5. Testing Protocols

- **Root-to-Leaf**: Always verify system integration starting from the `ops-engine` heartbeat.
- **Leaf-to-Root**: Ensure individual manager contracts are unit-tested before integration.
- **Principal Injection Mocking**: Use public setters to inject mock contracts or traits for specialized testing segments.

---
*Updated by Chappies (Feb 21, 2026)*
*Phase 11 Compliance Verified*
