# STRATEGOS MANDATE: CONSTRAINTS & ETHOS CHECKPOINTS (v1.1.0)

## 1. Core Ethos Checkpoints (Mandatory)
Every architectural change and PR must be audited against these 5 non-negotiable checkpoints:

1.  **No Custom Models**: All intelligence must be sourced via existing decentralized protocols (e.g., **Bittensor**, **Akash**, **Ritual**) or institutional MCPs (**LSEG**). We do not train proprietary LLMs; we orchestrate sovereign intelligence.
2.  **Non-Dilutive Capital**: Equity is legacy. All capital raising must utilize **Bitcoin DLC Bonds** or yield-bearing instruments. If debt is issued, it must be programmatically settled via `cxn-treasury-oracle`.
3.  **TEE First**: Any off-chain compute (Gateway, Oracle, Nexus) **MUST** run in a hardware-attested enclave (Intel SGX, AWS Nitro, GCP TEE). Code must include logic to verify its own attestation hash before processing state changes.
4.  **Bitcoin Finality**: All payments settle on **Stacks (L2)** with **sBTC**. Machine-to-machine (M2M) settlement **MUST** use the **x402 protocol** anchored to Stacks.
5.  **Audit-Ready Architecture**: Code must be clean, modular, and suitable for continuous security auditing. Minimal dependencies, strict naming conventions (**cxn-** prefix), and full internal documentation are required.

## 2. Global Reserve & Compliance Ethos
As of ATS v4.8.0, all Conxian operations must be **Global Reserve Bank compliant**:
- **ISO 20022 Native**: All institutional payment egress must support ISO 20022 XML standards (`pacs.008`).
- **Jurisdictional Sharding**: State logic must be sharded to respect SARB, MiCA, and BIS/IMF global frameworks.
- **LEI/DID Mapping**: Every treasury entity must map their Legal Entity Identifier (LEI) to a Sovereign DID (ERC-8004).

## 3. Strategos Roles (21-Agent Matrix)

### Guardian Cohort (Security & Sovereignty)
*   **Attestation**: ZKML/TEE oversight. Enforcement of Zero Secret Egress (ZSE).
    *   *Lead Component*: `conxian-gateway/zkc.rs`, `lib-conclave-sdk`.
*   **Sovereignty**: Global regulatory compliance and jurisdictional sharding (SARB/SARS/BIS).
    *   *Lead Component*: `cxn-strategy-nexus/docs/SARB_MARCH_2026_MANDATE.md`.
*   **Resilience**: Emergency response and decentralized kill switches (Circuit Breaker).
    *   *Lead Component*: `Conxian/contracts/security/circuit-breaker.clar`.
*   **Veracity**: Oracle failover and price integrity (LSEG/Chainlink).
    *   *Lead Component*: `conxian-nexus/src/oracle`.

### Strategos Forum (Growth & Alliances)
*   **Alliances**: Institutional BD and real-time M&A velocity.
    *   *Lead Component*: `cxn-strategy-nexus/REALTIME_M&A_VELOCITY.md`.
*   **Network Effects**: Product-Led Growth (PLG) and sovereign referrals.
    *   *Lead Component*: `conxius-wallet`.
*   **Forge**: Developer Experience (DX), SDKs, and adoption.
    *   *Lead Component*: `lib-conxian-core`.
*   **Integrations**: DePIN and protocol partnerships (Akash/Bittensor).
    *   *Lead Component*: `cxn-treasury-oracle/BOS_INTEGRATION_MAP.md`.

### Executor Forge (Execution & Liquidity)
*   **Liquidity Forge**: sBTC yield optimization and treasury routing.
    *   *Lead Component*: `Conxian/contracts/yield/yield-optimizer.clar`.
*   **Compute Forge**: DePIN arbitrage and sovereign node procurement.
    *   *Lead Component*: `cxn-ops-engine/DEPLOYMENT_EFFICIENCY.md`.
*   **Route Forge**: Secure API abstraction and TEE-sandboxed routing.
    *   *Lead Component*: `conxian-gateway/internal/api/routes.rs`.
*   **Payment Forge**: x402/x402x M2M settlement and **ISO 20022 XML egress**.
    *   *Lead Component*: **MISSING** (Gap ID: EXEC-ISO-0402).
*   **Capital Forge**: Bitcoin DLC Bonds and non-dilutive debt lifecycle.
    *   *Lead Component*: `cxn-treasury-oracle/BITCOIN_BOND_DLC.json`.
*   **Bridge Forge**: Cross-chain hardening (EVM/Solana/Cosmos).
    *   *Lead Component*: `Conxian/contracts/cross-chain/bridge-nft.clar`.

### Oracle Chamber (Intelligence & Identity)
*   **Synthesis**: Market intelligence and exit readiness (ZK-Data Room).
    *   *Lead Component*: `cxn-strategy-nexus/docs/ZK_DATA_ROOM_SCHEMA.md`.
*   **Horizon**: Macro liquidity cycles and sovereign runway.
    *   *Lead Component*: `cxn-treasury-oracle/SOVEREIGN_RUNWAY.md`.
*   **Frontier**: Emerging tech research (ZKML, new TEE architectures).
    *   *Lead Component*: `cxn-treasury-oracle/OPENCLAW_TEE_SPEC.md`.
*   **Signal**: On-chain metrics and adoption curves.
    *   *Lead Component*: `conxian-nexus/src/state`.
*   **Identity**: Agent reputation, **LEI Verification**, and ERC-8004.
    *   *Lead Component*: `cxn-treasury-oracle/WEB5_IDENTITY_AUDIT.md`.

### Cross-Cutting (Operations)
*   **Strategos Scribe**: Transparency and public hashing of audit manifests.
    *   *Lead Component*: `conxian-business/transparency_custodian.py`.
*   **Strategos Warden**: Shadow dependency scanning and nomenclature enforcement.
    *   *Lead Component*: `cxn-arch-guardian/ANTI_FRAGILITY_LOOP.md`.
*   **Ethos Guardian**: Veto power over any change violating Core Ethos Checkpoints.
    *   *Lead Component*: Manual Review / Jules (Executive Executor).
