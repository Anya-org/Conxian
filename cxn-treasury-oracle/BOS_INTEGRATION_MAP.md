# BOS Integration Map: OpenClaw Autonomous Engine

## 1. Objective
Map the OpenClaw autonomous engine within the `cxn-treasury-oracle` to the state transitions of the Business Operations System (BOS).

## 2. State-Action Mapping (BOS_STATE_MACHINE.json)
| BOS State | OpenClaw Action Trigger | Hardware-Enclosed Execution |
| :--- | :--- | :--- |
| **CLIENT_MODE** | `REBALANCE_TREASURY` | TEE-side sBTC yield rebalancing against LSEG pricing. |
| **DEBT_ISSUANCE** | `INIT_DLC_CONTRACT` | Constructing and signing the DLC contract for the Bitcoin Bond. |
| **DEBT_ISSUANCE** | `SETTLE_COUPON_IN_SBTC` | Automated 144-block Stacks finality coupon distribution. |
| **SHARDED_EXECUTION** | `COMMIT_STATE_TO_TABLELAND` | Regulatory-shielded state persistence via the `supabase_state_bridge`. |

## 3. Trigger Mechanisms
- **Internal Triggers**: OpenClaw continuously monitors the `runway_metrics` table via the Supabase MCP bridge.
- **External Triggers**: `conxian-nexus` sends a `NEW_BITCOIN_BLOCK` event through the MCP Unix Domain Socket.
- **Authority Triggers**: `cxn-strategy-nexus` issues a signed `IntentMandate` to override rebalancing logic for M&A events.

## 4. Guardrails & 144-Block Time-Lock
- **Pre-Execution Check**: OpenClaw must verify the `LSEG_MCP_AUDIT.md` constraint: (Nexus pricing within 50bps of LSEG institutional data).
- **Time-Lock**: Every state change to the `DEBT_ISSUANCE` state requires a 144-block Bitcoin finality confirmation before it is marked as `COMMITTED` in the `BOS_STATE_MACHINE.json`.
- **Failure Protocol**: If the 50bps threshold is breached, OpenClaw reverts to `SHARDED_EXECUTION` mode and alerts the `cxn-arch-guardian`.

## 5. Audit Trace
- All state transitions from `CLIENT_MODE` to `DEBT_ISSUANCE` are logged to the `conxian-treasury-oracle.dwn` as part of the `WEB5_IDENTITY_AUDIT.md` protocol.
