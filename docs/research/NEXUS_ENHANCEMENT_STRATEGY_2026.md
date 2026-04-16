# Nexus & Gateway Enhancement Strategy (April 2026)

## 1. Competitive Benchmarking

| System | Key Strength | Nexus/Gateway Gap | Enhancement Vector |
| :--- | :--- | :--- | :--- |
| **Glassnode** | Deep on-chain analytics & metrics depth. | Higher-level financial abstractions. | Add "Sovereign Yield Index" and "TAM Capture" metrics. |
| **Oracle Autonomous** | Zero-ops maintenance and self-healing. | Manual reorg handling and sync monitoring. | Implement "Autonomous Sync Repair" and health-checks. |
| **Lava Network** | Decentralized RPC with incentives. | Reliance on Hiro/Public RPC endpoints. | Implement Multi-RPC Aggregator with latency-based selection. |
| **Space and Time** | Proof-carrying SQL (ZK-SQL). | relational data is currently verified only by Nexus. | Integrate Tableland/Kwil for decentralized RELATIONAL truth. |

## 2. Enhancement Roadmap (Sovereign-First)

### A. Decentralized RPC Architecture (CON-463)
- **Problem**: Current systems rely on single RPC providers (Hiro for Stacks, Public nodes for Bitcoin).
- **Enhancement**: Implement an RPC Provider Pool in `conxian-gateway` with:
  - Failover logic.
  - State consistency checks (verify same tip across multiple providers).
  - Support for decentralized RPC networks (Lava, Pocket).

### B. Sovereign Persistence Layer (CON-69 / CON-337)
- **Problem**: Transactional state is currently bound to hosted PostgreSQL (Neon).
- **Enhancement**: Upgrade `KwilAdapter` and `TablelandAdapter` from stubs to functional implementations:
  - Commit state roots to Tableland for public verifiability.
  - Use Kwil for decentralized relational state (Job Cards, settlement logs).

### C. Decentralized Telemetry (CON-473)
- **Problem**: System telemetry is centralized.
- **Enhancement**: Full integration of Nostr for signed, uncensorable event propagation between agents and gateways.

## 3. Implementation Plan
1. **Gateway**: Implement `RpcAggregator` for Stacks/Bitcoin.
2. **Nexus**: Finalize `KwilAdapter` for Block/State-Root persistence.
3. **Common**: Aligned x402 mandates with BitVM2 state roots for trustless settlement.

---
© 2026 Conxian-Labs (Pty) Ltd.
