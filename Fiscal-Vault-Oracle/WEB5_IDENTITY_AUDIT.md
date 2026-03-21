# Web5 Identity & Audit Protocol for OpenClaw

## 1. Decentralized Identifier (DID) Architecture
- **DID Method**: `did:ion` (Sidetree on Bitcoin L1).
- **DID Identity**: The unique public key generated within the `cxn-treasury-oracle` TEE (Secure Enclave).
- **Authentication**: All MCP requests sent by the OpenClaw engine must include a cryptographically signed `Authorization: DID-Enclave <signature>` header.
- **Authority**: The DID is authorized via a Stacks-native `IntentMandate` signed by the `cxn-strategy-nexus` (CEO).

## 2. Decentralized Web Node (DWN) Audit Layer
- **Destination**: A private Conxian DWN instance (`conxian-treasury-oracle.dwn`).
- **Audit Logs**:
    - **Decision Logs**: A complete trace of the OpenClaw agent's reasoning process for each treasury rebalance.
    - **Logic Histories**: A record of all internal state transitions within the `BOS_STATE_MACHINE.json`.
    - **Transaction Intents**: Pre-signed Bitcoin/Stacks transaction payloads before they are submitted to the `conxian-nexus`.
- **Encryption**: All data written to the DWN is encrypted using the `cxn-arch-guardian`'s public key, ensuring only authorized auditors can view the full history.

## 3. M&A Due Diligence & Cryptographic Transparency
- **Objective**: Eliminate key-man discounts by providing 100% programmatic proof of all treasury actions.
- **ZK-Proofs**: Periodically, the DWN generates a Zero-Knowledge Proof (ZKP) of the treasury's FASB compliance and yield accuracy.
- **Verification**: Potential acquirers can verify the ZKP against the `BITCOIN_BOND_DLC.json` outcomes without accessing the underlying private PII.
- **Immutability**: Every DWN write is hashed and the root hash is anchored to the Bitcoin L1 every 144 blocks via the `transparency_custodian.py`.
