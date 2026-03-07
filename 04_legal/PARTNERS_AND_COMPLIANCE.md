---
title: Partners & Compliance
layout: page
permalink: /partners
---

# Approved Partners & Compliance Stack

**Objective:** Enable financial features by integrating regulated third-party APIs while maintaining non-custodial sovereignty.

## 1. Fiat On-Ramps (Buying Crypto)
* **Provider:** **Transak**
* **Status:** APPROVED
* **Compliance Role:** Acts as the Merchant of Record. Handles KYC, Fraud Checks, and Chargebacks.
* **Integration:** Android SDK.

## 2. Institutional Bridge (ZAR)
* **Provider:** **VALR**
* **Status:** APPROVED STRATEGIC PARTNER
* **Compliance Role:** Licensed SA Financial Services Provider (FSP). Holds user ZAR custody.
* **Integration:** VALR Pay API.

## 3. Sovereign Rails (Swaps & Infrastructure)
* **Provider:** **Changelly**
* **Status:** APPROVED
* **Compliance Role:** Counterparty for trades. Handles AML screening.
* **Infrastructure Pivot (M12):** Conxian operates a **Technical Relay Proxy** for Changelly to ensure uptime and privacy. This proxy does not hold or possess the ability to redirect funds.

## 4. Institutional Interface (B2B)
* **Entity:** **Conxian Gateway**
* **Role:** A portal for corporate treasury and launchpad services.
* **Compliance Role:** Pure software interface. All signing is delegated to the user's mobile Enclave (The Conclave).

## 5. Lightning Network (LSP)
* **Provider:** **Breez (Greenlight)**
* **Status:** APPROVED
* **Compliance Role:** Technology provider. Keys stay in the user's Conclave.
* **Note:** We do NOT act as the routing node (LSP) to avoid Money Transmitter licensing.

## 6. Developer Rules of Engagement (Strict Adherence)
1.  **Never Touch Fiat:** Do not build any feature that accepts card payments directly to Conxian accounts.
2.  **No Shadow Ledgers:** Never record a user's balance in our own database. Always fetch live data from the blockchain or the Partner API.
3.  **UI Labeling:** When a user enters a partner flow (e.g., Buying BTC), display a toast/banner: *"Powered by [Partner Name]. You are leaving Conxius to complete this transaction."*
4.  **Non-Custodial Proxying:** Any proxy operated by Conxian must be verified to be a "Zero-Touch" relay that cannot modify transaction destinations.

---
[Return to Root README](../README.md) | [Strategic Alignment](../ALIGNMENT.md)
