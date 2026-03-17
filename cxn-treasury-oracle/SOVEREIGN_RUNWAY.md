# Treasury Oracle: Sovereign Runway & Yield Execution

## 1. Objective
Automated management of protocol runway and yield-generation logic.

## 2. Rules
- **Yield is Liquid**: Only native yield can be used for operational expenses.
- **Principal is Sovereign**: Locked principal must remain in hardware-enclosed multisigs (TEE/StrongBox).
- **ZAR/Native Monitoring**: Tracking fiat burn against sBTC/STX yield.

## 3. State Layer
- **Source**: Supabase (`runway_metrics` table)
- **Status**: PENDING SYNC
