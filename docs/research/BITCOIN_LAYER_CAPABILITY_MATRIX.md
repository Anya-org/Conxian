# Bitcoin Layer Capability Matrix

## Purpose

This document defines what native support should mean for Conxian when targeting Bitcoin mainnet and Bitcoin-connected layers. The goal is not to flatten all networks into one generic abstraction, but to normalize the developer-facing capability model where that is useful while preserving layer-specific safety, verification, and execution semantics.

## Strategic framing

Conxian should help builders support:

- Bitcoin mainnet as the base settlement layer
- Lightning as the payment-channel and invoice layer
- Stacks as the Bitcoin-anchored smart contract layer
- Rootstock as the Bitcoin-linked EVM layer
- Liquid as the pegged asset and issuance layer

Conxian should compete on:

- capability normalization
- secure signing and device trust
- integration quality
- documentation and reference implementations
- mainnet-safe developer experience

Conxian should not compete on:

- rebuilding all upstream SDK functionality
- becoming a retail financial service
- cloning upstream wallets or node products

## Canonical capability verbs

The following verbs should become the shared capability model across Conxian repos:

- observe
- derive
- build
- sign
- broadcast
- verify
- settle
- bridge
- recover
- simulate

Not every layer supports every verb in the same way. The point is to provide a common interface vocabulary, not identical implementation.

## Capability matrix

| Layer | Observe | Derive | Build | Sign | Broadcast | Verify | Settle | Bridge | Recover | Simulate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Bitcoin mainnet | Required | Required | Required | Required | Required | Required | Required | Optional | Required | Required |
| Lightning | Required | Limited | Required | Required | Required | Required | Required | Optional | Required | Useful |
| Stacks | Required | Required | Required | Required | Required | Required | Required | Required for sBTC-oriented flows | Required | Required |
| Rootstock | Required | Required | Required | Required | Required | Required | Required | Required | Useful | Required |
| Liquid | Required | Required | Required | Required | Required | Required | Required | Required | Useful | Useful |

## Layer-specific interpretation

### 1. Bitcoin mainnet

Native support means:

- descriptor-aware wallet support
- UTXO discovery and transaction observation
- PSBT construction, analysis, signing, and finalization
- fee estimation and confirmation tracking
- reorg-aware confirmation handling
- hardware and offline signing compatibility
- raw transaction decode and verification helpers

Implementation expectations:

- `observe`: address, descriptor, UTXO, mempool, block, transaction state
- `derive`: address derivation from descriptors or wallet policy
- `build`: coin selection, outputs, fees, locktime, change policy
- `sign`: software, hardware, enclave, and offline signing paths
- `broadcast`: RPC or provider-backed transaction propagation
- `verify`: transaction structure, fee sanity, confirmation depth, script intent
- `settle`: finality thresholds configurable by use case
- `recover`: watch-only import, descriptor restoration, signer reassociation
- `simulate`: fee and UTXO planning, PSBT inspection, dry-run validation

### 2. Lightning

Native support means:

- invoice generation and decoding
- settled-invoice monitoring
- payment attempts and payment-state observation
- channel-state and liquidity awareness
- route hints and private channel support where needed
- on-chain funding relationship awareness

Implementation expectations:

- `observe`: node/channel/payment/invoice state
- `build`: invoice, payment request, channel funding intent
- `sign`: signer support where channel operations or on-chain funding require it
- `broadcast`: RPC-backed command execution and on-chain funding transactions
- `verify`: invoice parameters, destination, amount, expiry, settlement state
- `settle`: invoice settled, payment completed, channel confirmation state
- `recover`: invoice state recovery, node/channel state re-sync, signer recovery
- `simulate`: liquidity and routing pre-checks where feasible

### 3. Stacks

Native support means:

- transaction creation, signing, and broadcast
- contract call support
- post-conditions as a first-class safety primitive
- wallet-mediated confirmation flows
- sponsored transactions where needed
- Bitcoin anchoring awareness
- sBTC-related interaction support where relevant

Implementation expectations:

- `observe`: account state, transaction state, contract events, anchor-related status
- `derive`: address and account support for supported key paths
- `build`: transfers, contract calls, deploys, sponsored transactions
- `sign`: software, wallet, hardware, and secure execution flows
- `broadcast`: API-backed or node-backed submission
- `verify`: post-conditions, function args, contract target, anchor assumptions
- `settle`: chain acceptance plus Bitcoin-anchored finality awareness when needed
- `bridge`: sBTC-oriented asset movement and cross-layer proofs where required
- `recover`: account and signer restoration, pending transaction introspection
- `simulate`: call estimation, post-condition validation, dry-run contract interaction

### 4. Rootstock

Native support means:

- EVM-compatible RPC support
- contract deployment and invocation
- wallet compatibility
- Bitcoin-linked onboarding or bridge assumptions handled explicitly

Implementation expectations:

- `observe`: account, contract, logs, transaction state
- `derive`: supported account/key handling for connected wallets
- `build`: EVM transaction construction and contract interaction
- `sign`: wallet, enclave, or external signer support
- `broadcast`: JSON-RPC transaction submission
- `verify`: calldata, destination, gas policy, chain identity
- `settle`: confirmation policy by risk tolerance
- `bridge`: Bitcoin-linked bridge and asset flow support
- `recover`: signer and account reattachment, nonce/state recovery
- `simulate`: gas estimation, call simulation, transaction previews

### 5. Liquid

Native support means:

- LBTC and issued asset support
- peg-in and peg-out awareness
- federation-model awareness in verification and messaging
- asset transfer and issuance support where intended

Implementation expectations:

- `observe`: asset balances, issued asset metadata, peg state, transaction state
- `derive`: address derivation and asset-aware receiving flows
- `build`: LBTC and asset transactions
- `sign`: compatible wallet and secure signer support
- `broadcast`: provider or node-backed submission
- `verify`: asset identity, transaction intent, peg assumptions
- `settle`: federation-based confirmation policy
- `bridge`: peg and asset movement workflows
- `recover`: signer/account restoration and asset inventory re-linking
- `simulate`: asset movement and fee previews where feasible

## Cross-layer requirements

These should apply across all supported layers:

### Signing

Conxian should expose a signer model that supports:

- software signing
- hardware signing
- enclave-backed signing
- watch-only mode
- partially signed workflows
- delegated or policy-constrained signing

### Verification

Verification should not stop at technical validity. It should include:

- destination verification
- asset or layer identity verification
- amount and fee sanity checks
- policy conformance
- environment and network identity checks
- pre-broadcast user or system safety gates

### Recovery

Recovery should be treated as a first-class capability:

- signer reassociation
- watch-only restoration
- descriptor or account restoration
- pending transaction introspection
- event stream or state resynchronization

### Simulation

Simulation should become part of the developer experience:

- transaction preview
- fee preview
- policy preview
- likely settlement path
- mainnet-readiness prechecks

## Prioritization

### Phase 1

- Bitcoin mainnet
- Lightning
- Stacks

### Phase 2

- Rootstock
- Liquid

### Phase 3

- additional Bitcoin-connected layers via adapter model

## Implications for Conxian repos

- `lib-conxian-core`
  - define canonical capability interfaces and shared transaction safety models
- `conxius-enclave-sdk`
  - implement secure signer backends and device trust controls
- `conxian-gateway`
  - host per-layer adapters and provider integration boundaries
- `conxius-platform`
  - provide local, testnet, and mainnet integration harnesses
- `conxius-wallet`
  - act as a reference client, not the center of the strategy

## Definition of done for native layer support

A layer should not be called natively supported until Conxian can provide:

- supported signer path
- build and broadcast path
- observation path
- verification guardrails
- recovery path
- simulation or preview path
- environment-aware documentation and examples

## Summary

Native support should mean:

- mainnet-capable
- signer-safe
- verification-aware
- recovery-aware
- layer-specific where needed
- normalized where useful

Conxian should help builders support Bitcoin and its layers without pretending those layers are all the same.