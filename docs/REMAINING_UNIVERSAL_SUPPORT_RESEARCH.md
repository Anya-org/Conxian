# Remaining Universal Support Research

## Purpose

Track the remaining research work needed before broad multichain-universal implementation can proceed cleanly across Nexus, Gateway, and control-plane surfaces.

## Research items — ALL RESOLVED (2026-06-13)

All four foundational research questions have been closed. This document is retained as a decision record.

### 1. Tier 1 chain families ✅ RESOLVED (#735, closed 2026-06-12)

**Decision:** Three Tier 1 families selected for initial execution:

| Family | Chains |
|---|---|
| Bitcoin/UTXO | Bitcoin, Stacks, Liquid, Babylon, BOB |
| EVM | Ethereum, Base, Arbitrum, Optimism, Polygon |
| Cosmos/IBC | Cosmos Hub, Osmosis, Celestia |

**Rationale:**
- Bitcoin/UTXO: Core to Conxian sovereignty
- EVM: Highest TVL and developer activity
- Cosmos/IBC: Interoperability standard for non-EVM chains

### 2. Cross-chain event bus ownership ✅ RESOLVED (#736, closed 2026-06-08)

**Decision:** Nexus does **not** own the cross-chain event bus runtime.

- **Nexus owns:** Canonical event semantics — ingestion normalization, event identity, ordering, finality/reorg handling, proof/state materialization, trust classification, canonical routing.
- **Gateway owns:** Event bus runtime, pub/sub, fan-out, delivery guarantees, subscriber management.
- This separation keeps Nexus stateless/provable and Gateway operational.

### 3. Approved bridge and messaging systems by trust tier ✅ RESOLVED (#737, closed 2026-06-10)

**Decision:** Canonicalized in `docs/architecture/APPROVED_BRIDGE_AND_MESSAGING_SYSTEMS_BY_TRUST_TIER.md`.

- Trust-tier matrix defined
- Constraints and forbidden patterns documented
- Gateway and Nexus implementation implications captured

### 4. Allowed signer backends by chain family ✅ RESOLVED (#738, closed 2026-06-13)

**Decision:** Per-chain-family signer backend policy defined for production.

- Signing remains outside Nexus and Gateway (wallet/enclave/HSM boundaries)
- Trust-tier enforcement per family
- Production signer backend matrix documented

## Status: COMPLETE

All tracked research issues are resolved. No remaining blockers for multichain-universal implementation.

## Resolved tracked issues

- `conxian-business` #735 — Tier 1 chain families ✅
- `conxian-business` #736 — cross-chain event bus ownership ✅
- `conxian-business` #737 — approved bridge and messaging systems by trust tier ✅
- `conxian-business` #738 — allowed signer backends for production by family ✅
