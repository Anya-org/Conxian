# ADR-006: Universal Chain Interoperability Standards

## 1. Context
Conxian requires a deterministic and secure method to orchestrate liquidity and state across multiple blockchain families (EVM, Bitcoin/UTXO, Cosmos/IBC).

## 2. Research Findings

### 2.1. Interoperability Patterns
- **LayerZero V2 (Endpoint-Peer Model)**: Provides an immutable, censorship-resistant messaging layer. Suitable for "Light" state synchronization and cross-chain governance signals.
- **Axelar (Amplifier/Verifier Model)**: Offers a dynamic verifier set and hub-and-spoke routing. Ideal for large-scale liquidity bridging and complex multi-hop transactions.
- **Nexus Network**: Provides ZK-verifiable off-chain compute. This is identified as the canonical "Operational Office" layer for the SAB Staff.

### 2.2. Trust Models
- **Tier 1 (Strict)**: Requires synchronous finality or sovereign proof verification. Used for core treasury and insurance flows.
- **Tier 2 (Optimistic)**: Utilizes challenge periods. Used for non-critical yield routing and meritocratic emission tracking.

## 3. Implementation Proposal
- Implement a **Universal Routing Layer** in the Conxian Gateway that abstracts the underlying interoperability provider (LayerZero/Axelar) from the protocol logic.
- Standardize on **SIP-018** for message signing across all chains to ensure a unified compliance and identity posture.

## 4. Risks
- **Oracle Correlated Failure**: Cross-chain prices must be verified across at least 3 distinct providers (e.g., Pyth, Redstone, Chainlink).
- **Bridge Liquidity Fragmentation**: Managed via the **Cybernetic Fiscal Dam** which can autonomously divert yield to recapitalize thin bridges.
