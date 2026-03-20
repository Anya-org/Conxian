# Treasury Oracle: Sovereign Runway & Yield Execution

## 1. Objective
Automated management of protocol runway and yield-generation logic.

## 2. Rules
- **Yield is Liquid**: Only native yield can be used for operational expenses.
- **Principal is Sovereign**: Locked principal must remain in hardware-enclosed multisigs (TEE/StrongBox).
- **ZAR/Native Monitoring**: Tracking fiat burn against sBTC/STX yield.

## 2.5 LSEG MCP Integration
Every yield rebalance is cross-referenced against LSEG institutional data to ensure FASB compliance and prevent oracle manipulation.

## 3. State Layer
- **Source**: Supabase (`runway_metrics` table)
- **Status**: PENDING SYNC
