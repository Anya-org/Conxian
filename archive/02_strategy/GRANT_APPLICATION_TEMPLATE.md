---
title: Grant Application Template
layout: page
permalink: /docs/grant-template
---

# Conxius Wallet: Grant Application Template (Stacks & Wormhole)

## 1. Project Overview

**Project Name:** Conxius Wallet
**Entity:** Conxian
**One-Liner:** A "Bitcoin-First" mobile gateway providing TEE-secured, multi-layer sovereignty for the full Bitcoin ecosystem.

**The Problem:** Users are fragmented across custodial bridges and disparate apps for Stacks (sBTC), Bitcoin L1, and EVM-compatible Bitcoin L2s. There is no unified mobile interface that offers hardware-grade security for cross-chain movement.

**The Solution:** Conxius integrates **Stacks sBTC** and **Wormhole NTT** into a single Android Enclave (The Conclave). This allows users to bridge, swap, and sign transactions across the entire stack with zero secret egress and unified gas abstraction.

---

## 2. Technical Strengths & Innovation

*   **Native Enclave Core:** We utilize Android **StrongBox** to ensure private keys are never exposed to the application layer.
*   **Wormhole NTT Transceiver:** We have implemented a sovereign transceiver that allows for "Native Token Transfers," maintaining the native properties of assets like sBTC when moving across chains.
*   **sBTC Native Integration:** Deep support for the Stacks Nakamoto release, including native peg-in/out scripting in `signer.ts`.
*   **Gas Abstraction:** Enabling users to pay for cross-chain bridging fees in sBTC/BTC, removing the barrier of entry for non-EVM users.

---

## 3. Specific Grant Initiatives

### Initiative A: The Stacks sBTC On-Ramp Hub
*   **Objective:** Make Conxius the primary mobile interface for sBTC.
*   **Milestones:**
    1. Integration of Stacks Clarity 4.0 deposit functions.
    2. Real-time Hiro API indexing for sBTC balances.
    3. "Stacks Sovereignty" marketing campaign to onboard 5k active users.

### Initiative B: The Wormhole Sovereign Bridge (NTT)
*   **Objective:** Deploy and maintain the first mobile-first NTT bridge for Bitcoin L2 assets.
*   **Milestones:**
    1. Deployment of Conxius NTT Manager contracts on BOB and Base.
    2. Implementation of the "sBTC-as-Gas" Relayer service.
    3. Integration of Wormhole VAA verification directly into the on-device ZK-Verifier (M10).

---

## 4. Ecosystem Impact

*   **Stacks Growth:** By lowering the barrier to entry for sBTC, we drive TVL and transaction volume to the Stacks network.
*   **Wormhole Volume:** Our gas abstraction model and 0.1% convenience fee structure provide a sustainable flow of cross-chain volume through the Wormhole Guardian network.
*   **Security Standard:** We set a new benchmark for "Mobile Sovereignty," encouraging other developers to use the Conclave SDK for secure Bitcoin signing.

---

## 5. Team & Track Record

The Conxian team consists of experts in Android TEE security, Bitcoin scripting, and cross-chain architecture. We have successfully completed Milestones M1-M3 and are currently executing the Level 2 Operational Roadmap.

---
[Return to Root README](../README.md) | [Strategic Alignment](../ALIGNMENT.md)
