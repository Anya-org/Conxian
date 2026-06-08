# Remaining Universal Support Research

## Purpose

Track the remaining research work needed before broad multichain-universal implementation can proceed cleanly across Nexus, Gateway, and control-plane surfaces.

## Remaining research items

### 1. Tier 1 chain families
Decide the first three adapter families for initial execution.

Candidate families:
- EVM
- Bitcoin / UTXO
- Cosmos / IBC
- Solana / SVM
- Move
- Substrate

### 2. Cross-chain event bus ownership
Decide whether Nexus should also own the cross-chain event bus, or remain limited to state, proof, ordering, and trust classification.

### 3. Approved bridge and messaging systems by trust tier
Define which bridge and messaging systems are approved and how each maps to trust tiers.

### 4. Allowed signer backends by chain family
Define which signer backends are allowed for production by family.

## Why these are the remaining gaps

These questions remain open in the current Nexus/Gateway architecture and directly affect implementation order, scope boundaries, and production trust posture.

## Current tracked issues

- `conxian-business` #735 — Tier 1 chain families
- `conxian-business` #736 — cross-chain event bus ownership
- `conxian-business` #737 — approved bridge and messaging systems by trust tier
- `conxian-business` #738 — allowed signer backends for production by family

## Working rule

No new broad multichain implementation expansion should outrun these four decisions.

## Sequence

1. resolve Tier 1 chain families
2. resolve event-bus ownership
3. resolve approved bridge/messaging systems
4. resolve signer backend policy by family
