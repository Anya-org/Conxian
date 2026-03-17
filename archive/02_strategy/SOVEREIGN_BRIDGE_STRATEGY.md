---
title: Sovereign Bridge & Interoperability Strategy
layout: page
permalink: /docs/sovereign-bridge-strategy
---

# Sovereign Bridge & Interoperability Strategy

**Date:** 2026-02-18
**Status:** DRAFT
**Context:** Research findings on Wormhole availability and native ethos-aligned bridging mechanisms.

---

## 1. Executive Summary

To maintain our "Sovereign by Design" ethos, Conxius cannot rely on custodial bridges or opaque "wrapped" assets. Our interoperability strategy uses a **Sovereign-First Hybrid Model**:

1. **Native Bitcoin Support** (Mandated): All transfers between Bitcoin L1 and all Bitcoin L2s (and beyond) utilize native, trust-minimized bridges or atomic swaps. NTT is NOT the primary method for Bitcoin-to-Bitcoin (or Bitcoin-to-L2) transfers.
2. **Trustless Atomic Swaps** (Accelerator): Use **Boltz** for fast, non-custodial entry/exit to Liquid and Lightning.
3. **Wormhole NTT** (Cross-Chain Satellites): Reserved for non-Bitcoin networks (e.g., Ethereum, Chainlink, etc.). We deploy and own the **NTT Contracts** for these satellite ecosystems.

---

## 2. Wormhole Service Availability

**The Question:** "Are there any available Wormhole services we can rely on?"

**The Answer:** Yes, but **you are the service provider.**

* **What is Available:** The **Wormhole Guardian Network** (19 validators) is live and public. They *will* attest to your messages if emitted correctly.
* **What is Missing:** There is no "Public Generic Relayer" that automatically knows about your specific Conxius NTT token.
* **Requirement:** We must deploy **Native Token Transfer (NTT)** contracts to our target chains (Ethereum, Arbitrum, Base).
  * **Manager Contract:** Handles mint/burn/lock logic ($O(1)$ state mapping).
  * **Transceiver Contract:** Emits messages to the Guardians.
* **Stacks Principal Hashing:** To support Stacks' long contract names within Wormhole's 32-byte address limit, we hash the principal (e.g., `sbtc-token`) using SHA-256.
* **Relayer Strategy:** We cannot rely on the "Standard Relayer" for custom NTT logic without configuration. We should run a lightweight **Specialized Relayer** (serverless function) that observes our NTT events and submits the VAA to the destination chain.

**Ethos Check:**

* ✅ **Trustless:** We verify Guardian signatures on-chain.
* ✅ **Sovereign:** We own the token contracts; Wormhole is just the messenger.

---

## 3. Native Ethos-Aligned Mechanisms

We prioritize mechanisms that derive security from Bitcoin or minimize trust.

### A. Stacks (sBTC)

* **Mechanism:** Decentralized Two-Way Peg (Nakamoto Release).
* **Status:** **LIVE** (Deposits enabled Dec 2024, Withdrawals March 2025).
* **Peg-In (BTC -> sBTC):**
  * User sends BTC to a specific script hash on Bitcoin L1.
  * Stackers (validators) observe the tx and mint sBTC.
* **Ethos Alignment:** ⭐⭐⭐⭐⭐ (Bitcoin-secured, no federation).
* **Action:** Implement `signer.ts` support for the specific sBTC deposit script format.

### B. Rootstock (RBTC)

* **Mechanism:** **PowPeg** (Proof-of-Work Peg).
* **Trust Model:** Federated (PowHSM) but secured by Bitcoin merge-mining.
* **Peg-In (BTC -> RBTC):**
  * User sends BTC to the PowPeg Federation Address.
  * Requires ~100 confirmations (approx. 16 hours) for safety.
* **Ethos Alignment:** ⭐⭐⭐⭐ (Merge-mined security, hardware enforcement).
* **Action:** Use native bridge for large amounts; use Swaps (see below) for speed.

### C. Liquid (L-BTC)

* **Mechanism:** Federated Peg (Liquid Federation).
* **Trust Model:** Federated (15 functionaries).
* **Native Peg-In:** Slow (102 confirmations required).
* **Ethos Alignment:** ⭐⭐⭐ (Federated, but supports Confidential Transactions).
* **Alternative:** **Boltz Submarine Swaps**.

---

## 4. The "Boltz" Accelerator (Recommended)

Native pegs (Liquid, RSK) are often slow (100+ confirmations).
To solve UX without sacrificing sovereignty, we should integrate **Boltz**.

* **What is it?** A non-custodial exchange for Submarine Swaps (Atomic Swaps).
* **Supported Pairs:**
  * Bitcoin (L1) <-> Lightning
  * Bitcoin (L1) <-> Liquid (L-BTC)
* **How it works:**
  * Uses **HTLCs** (Hash Time-Locked Contracts).
  * "If you send me BTC, I reveal the secret to claim L-BTC."
  * If the swap fails, the user **refunds themselves** via their local key.
* **Why use it:**
  * **Speed:** Instant vs 16 hours.
  * **Ethos:** Trustless. If Boltz disappears, funds are not lost.
* **Action:** Integrate Boltz API for Liquid and Lightning "Fast Path".

---

## 5. Strategic Roadmap Update

| Layer | Primary Method (Large Value) | Fast Method (Daily Use) | Infra Required |
|-------|------------------------------|-------------------------|----------------|
| **Stacks** | **sBTC Native Peg** | N/A (Waiting for Bitflow/Alex) | Bitcoin Node (Index) |
| **Liquid** | **Boltz Atomic Swap** | **Boltz Atomic Swap** | Boltz API Client |
| **RSK** | **PowPeg** | Sovryn FastBTC | None (Direct Contract) |
| **Bitcoin L2s (EVM)** | **Native Bridge (L1-L2)** | **Native Bridge (L1-L2)** | Bridge Smart Contracts |
| **Non-BTC (EVM)** | **Wormhole NTT** | **Wormhole NTT** | Standard Portal Contracts |

**Next Step:**

1.  **Refactor `ntt.ts`** to use Standard Token Bridge SDK. [COMPLETED]
2.  **Implement Native Token Transfer (NTT) Transceiver** module for sovereign bridging. [COMPLETED]
3.  **Integrate Boltz SDK** (to unlock Liquid/Lightning). [IN PROGRESS]
4.  **Implement sBTC Scripting** (to unlock Stacks). [COMPLETED]
    - *Requirement:* Define `define-public` Clarity 4.0 functions for `deposit-sbtc` and `withdraw-sbtc` in the Stacks bridge contract.

---

## 6. Bridge Economics & Gas Abstraction

To ensure the best UX for the "Digital Citadelist," the Conxius NTT Bridge implements a **Sovereign Gas Abstraction** model.

### A. The 0.1% Convenience Fee
* **Value:** A 0.1% fee is charged on NTT transfers (BTC -> sBTC, sBTC -> L-BTC, etc.).
* **Justification:** This fee covers the maintenance of the NTT Transceiver infrastructure and the automated relayer fleet.
* **Implementation:** The fee is deducted by the NTT Manager contract on the source chain during the `burn` or `lock` phase.

### B. Gas Abstraction (The "sBTC-as-Gas" Model)
* **Mechanism:** When a user bridges assets to an EVM chain (e.g., BOB or Ethereum), they are prompted to pay for the destination gas in their source asset (e.g., sBTC).
* **Architecture:**
    1. Conxius calculates the required gas on the destination.
    2. User signs an NTT transfer that includes an extra "Gas Payment" amount.
    3. A **Conxian Relayer** (or authorized Solver) receives the NTT message and the Gas Payment.
    4. The Relayer submits the VAA to the destination chain, paying the gas in ETH/Native token.
* **Ethos Alignment:** Eliminates the "Gas Token Requirement" bottleneck, making Bitcoin layers feel like a single, unified network.

---
[Return to Root README](../README.md) | [Strategic Alignment](../ALIGNMENT.md)
