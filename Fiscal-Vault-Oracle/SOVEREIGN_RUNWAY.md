# Treasury Oracle: Sovereign Runway & Yield Execution

## 1. Objective
Automated management of protocol runway and yield-generation logic, strictly governed by the **Strategos Mandate (docs/STRATEGOS_MANDATE.md)**.

## 2. Core Constraints (Strategos Executor Forge)
- **Yield is Liquid**: Only native yield can be used for operational expenses.
- **Principal is Sovereign**: Locked principal must remain in hardware-enclosed multisigs (TEE/StrongBox).
- **ZAR/Native Monitoring**: Tracking fiat burn against sBTC/STX yield for SARB/SARS compliance.
- **Non-Dilutive Capital**: All capital raising must utilize **Bitcoin DLC Bonds** or yield-bearing instruments. No equity. (Strategos Capital Forge).

## 3. LSEG MCP Integration (Strategos Veracity)
Every yield rebalance is cross-referenced against **LSEG institutional data** via the LSEG MCP to ensure FASB compliance and prevent oracle manipulation.

## 4. OpenClaw TEE Sandbox (Strategos Frontier)
- **Requirement**: Any off-chain yield calculation or risk assessment **MUST** run in a hardware-attested enclave.
- **Implementation**: The **OpenClaw/TEE sandbox routing layer** (Gap SANDBOX-001) provides secure, private state management for institutional treasury execution.

## 5. State Layer & Metrics
- **Source**: Supabase (`runway_metrics` table).
- **Status**: PENDING SYNC (Phase 2).
- **Finality**: All treasury settlements must anchor to **Stacks (L2)** with **sBTC**.
