---
title: Comprehensive Strategic Advisory Report
layout: page
permalink: /docs/strategic-advisory-report
---

# Comprehensive Strategic Advisory Report

**Date:** 2026-02-18
**Target:** Conxius Wallet Engineering & Product Team
**Subject:** Strategic Review of Business Logic, Architecture, and Roadmap

---

## 1. Executive Summary

Conxius Wallet has successfully transitioned from a prototype to a **Beta-ready Sovereign Interface**. The codebase adheres strictly to the "No Mock" policy, with clear gates preventing the use of fake data for financial operations.

However, the product is currently in a **"Infrastructure-Blocked"** state. While the Android client code is robust (production-ready signing, storage, and protocol logic), the necessary backend services (Proxies and Smart Contracts) are missing from the live environment.

**Strategic Verdict:** STOP building new client features. START deploying infrastructure.

---

## 2. Business & Design Alignment Review

### ✅ Strong Alignment

- **Sovereignty First:** The `SecureEnclavePlugin` (Java) and `signer.ts` correctly enforce on-device key management. No secrets leave the device.
- **Regulatory Defense:** The architecture successfully avoids "custodial" classification by offloading all regulated flows to partners (Transak, VALR, Changelly) via direct API/SDK integrations.
- **Revenue Model:** The `swap.ts` and `onramp` logic correctly integrates affiliate markers (e.g., THORChain memos), ensuring monetization is baked into the protocol layer.

### ⚠️ Critical Gaps (The "Hollow Shell" Risk)

- **The "Experimental" UX Trap:** Users seeing "Experimental" flags on major features (Bridge, Swap) may perceive the wallet as broken rather than secure.
- **Missing Feedback Loops:** We have no visibility into *failed* infrastructure calls in the wild (e.g., if the Changelly proxy goes down).
- **Test Coverage Mismatch:** We have 100% unit test passing, but **0% E2E coverage** for complex flows like "Bridge -> Swap -> Broadcast".

---

## 3. Infrastructure-First Roadmap (Immediate Actions)

We must pivot from "App Development" to "Platform Operations".

### Phase 1: The "Real Rails" Sprint (Weeks 1-2)

**Goal:** Unblock Swaps and Bridging on Mainnet.

1. **Deploy Changelly Proxy:**
    - Use the scaffolded `infrastructure/gcp/changelly-proxy`.
    - **Action:** `gcloud run deploy` (as documented in `docs/GCP_INFRASTRUCTURE.md`).
    - **Result:** Unblocks `swap.ts` / `createChangellyTransaction`.

2. **Deploy Bisq Node:**
    - Provision the GCE instance.
    - **Action:** Secure the gRPC tunnel.
    - **Result:** Unblocks Decentralized Exchange features.

3. **Wormhole Contract Deployment:**
    - We cannot use the public Wormhole generic relayers for custom NTT logic if we want "Sovereign Proofs".
    - **Action:** Deploy `TokenManager` and `Transceiver` contracts to Ethereum, Arbitrum, and Base.
    - **Result:** Unblocks `ntt.ts` / `executeBridge`.

### Phase 2: User Safety & Trust (Weeks 3-4)

**Goal:** Make the app safe for grandmother-level users.

1. **Implement Play Integrity (Attestation):**
    - The native plugin exists (`DeviceIntegrityPlugin.java`) but needs the GCP backend hook.
    - **Why:** Prevents the app from running on rooted/compromised devices where the Keystore might be vulnerable.

2. **E2E Testing Suite:**
    - Write Playwright tests that run against *Testnet* infrastructure.
    - **Why:** Unit tests don't catch API schema changes or network timeouts.

---

## 4. Codebase Recommendations

### Refactor `NTTBridge.tsx` UX

Current state shows a "technical" view of the bridge.

- **Recommendation:** Move to a "Outcome-Based" UI. Instead of "Source -> Target", ask "What do you want to achieve?" (e.g., "Move BTC to Defi").
- **Fix:** The progress poller in `NTTBridge.tsx` is good, but should persist state across app restarts (store pending tx hashes in `localStorage`).

### Hardening `signer.ts`

- **Observation:** The signer is solid, but `signBip322Message` is complex.
- **Recommendation:** Add a specific "Sign Login Message" UI component that parses the message clearly for the user, rather than just showing a raw string.

### Feature Flag Cleanup

- Once infrastructure is live, we must systematically remove `_EXPERIMENTAL` flags.
- **Risk:** Leaving flags in `production` builds can lead to accidental enabling of mock paths if logic is inverted.
- **Fix:** Remove the mock code paths entirely in the next major refactor, rather than just gating them.

---

## 5. Final Word

You have built a Ferrari engine (The Conclave) and put it in a beautiful chassis (The UI). But you haven't put gas in the tank (Infrastructure).

**Do not write more React components.** Go to Google Cloud Console and deploy the backend rails. The code is ready; the network is waiting.
