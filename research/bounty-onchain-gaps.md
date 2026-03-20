# Bounty & On-Chain Gap Analysis (Strategos Framework)

## 1. Bounty Automation Gap
Currently, there is no specialized `bounty.clar` contract to handle automated bounty escrow, staking, and release.

### Technical Specification (Proposed)
- **Contract**: `bounty.clar`
- **Asset**: sBTC (principal settlement asset).
- **Stake**: 10% mandatory stake from hunter.
- **Auto-Approval**: 48-hour time-lock after submission. If no rejection from the "Ethos Guardian", funds release.
- **Protocol Fee**: 100 bps (1%) stripped to treasury.

## 2. Agent Registry (ERC-8004 Equivalent)
Existing `kyc-registry.clar` is too basic for an autonomous agent economy. We need a registry that tracks reputation and "Cart Mandates".

### Technical Specification (Proposed)
- **Contract**: `agent-registry.clar`
- **Identity**: Linked to BNS or a dedicated `agent-id` (uint).
- **Cart Mandate**: Cryptographic intent proof (linked to x402).
- **Reputation**: Dynamic score based on completed bounties and uptime.

## 3. x402 / x402x Integration
The gateway needs a handler for HTTP 402 payments to allow machine-to-machine micro-payments.

### Technical Specification (Proposed)
- **Gateway Endpoint**: `POST /api/v1/ai/x402-execute`
- **Logic**: Receives a `CartMandate` and a payment request. Verifies against `agent-registry.clar` and triggers on-chain settlement.
- **Settlement**: Uses sBTC via `conxian-finance`.

## 4. On-Chain Treasury Automation
Yield rebalancing currently requires a "Keeper" or manual trigger. It should be autonomous based on "Intents".

### Technical Specification (Proposed)
- **Contract**: `treasury-automation.clar`
- **Logic**: Implements "Intent-Based Execution". Rebalances when yield exceeds a certain threshold, using LSEG institutional data for verification.

## 5. ZKML & TEE Integration
Missing the RISC Zero / Gemini verifier in the gateway for high-integrity AI output verification.

### Proposed Solution
- **Rust Verifier**: `src/verifiers/zkml.rs` implementing RISC Zero proof verification.
- **Attestation**: Update `zkc.rs` to include RISC Zero journal verification.
