# Interlayer Routing: Native Token Transfers (NTT)

## 1. Executive Summary
Conxian utilizes Wormhole's **Native Token Transfers (NTT)** and the **Conclave SDK** to achieve seamless multichain routing. This architecture ensures that assets move between Bitcoin L1, Stacks, and other NTT-enabled chains without the security risks of traditional wrapped assets.

## 2. Technical Implementation
- **Hardware-Anchored**: Signatures for cross-chain movement are generated inside the hardware enclave.
- **Deterministic**: Funds only move if technical truth is verified on both source and destination layers.
- **Atomic Service Channels**: Utilizing TEE-assisted adaptor signatures (A402) to ensure end-to-end settlement atomicity.

## 3. Strategic Advantage
By embedding routing logic directly into the hardware-enclosed signer, Conxian eliminates the need for centralized bridging intermediaries. This reduces the attack surface and ensures that all value movement remains under the absolute control of the sovereign user.

---
© 2026 Conxian. Sovereign Autonomous Business.
[Return to Root README](../README.md) | [Strategic Alignment](../ALIGNMENT.md)
