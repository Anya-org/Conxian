---
title: UX Flow Final
layout: page
permalink: /docs/ux-flow
---

# UX Flow Finalization: Sovereign Handshake for NTT Transfers

This document outlines the definitive user experience for Native Token Transfers (NTT) within the Conxius Wallet. The primary goal is to achieve a "Sovereign Handshake," where a complex cross-chain operation is reduced to a single, authoritative user action (biometric/PIN authentication), followed by a clear, informative waiting period.

## The "Green Path" User Journey

**Objective:** Transfer sBTC from Stacks to the user's ETH address on Rootstock.

**Assumptions:**
- The user has already selected the source and destination assets and entered the amount.
- The wallet has fetched the necessary quotes for bridge fees and potential gas abstraction swaps.

---

### **Step 1: The Single, Unified Authorization**

1.  **Action:** The user reviews the transfer details on a final confirmation screen. This screen MUST display:
    *   Source and Destination (e.g., "From Stacks", "To Rootstock").
    *   Asset and Amount (e.g., "0.5 sBTC").
    *   **Estimated Total Cost:** This includes the Wormhole bridge fee AND the estimated destination gas fee (in the native asset, e.g., ETH).
    *   **Gas Abstraction (Optional):** If the user lacks the destination gas token (ETH), a toggle or checkbox will be presented: "Auto-swap 0.001 sBTC to cover ETH gas." This is enabled by default if a gas deficit is detected.
    *   **Estimated Time:** A clear, human-readable estimate (e.g., "Estimated Time: 15-30 minutes").

2.  **User Interaction:** The user taps "Confirm & Bridge".

3.  **Conclave Action:** A single biometric or PIN prompt appears. This **one** authorization approves a transaction batch:
    *   **Transaction 1 (Source):** The sBTC "burn" transaction on the Stacks network.
    *   **Transaction 2 (Gas Swap - Conditional):** If gas abstraction is enabled, the swap transaction (e.g., sBTC to ETH) is pre-authorized.
    *   **Transaction 3 (Destination - Pre-authorized):** The "redeem" transaction on Rootstock is pre-authorized, waiting for the VAA.

---

### **Step 2: The Communicated Wait**

**Objective:** Keep the user informed and confident while the technical processes execute. The UI must now transition to a persistent, non-blocking status tracker.

1.  **Immediate Feedback:** Upon successful Conclave authorization, the UI navigates to a "Transfer in Progress" screen. This is NOT a modal that blocks the app; the user can navigate away and this tracker will persist on the dashboard or in a dedicated "Activity" tab.

2.  **Visual Timeline:** The status tracker will display a visual timeline with clear, check-marked stages:

    *   **[In Progress] 1. Source Confirmation:** "Waiting for your transaction to be confirmed on the Stacks network..."
        *   **Technical Detail:** The app is monitoring the Stacks chain for the inclusion of the burn transaction. A link to the transaction on a Stacks explorer is provided.
        *   **User Message:** "Patience, Sovereign. The Bitcoin machine is etching your transaction into history."

    *   **[Waiting] 2. Wormhole VAA Generation:** "Waiting for Wormhole Guardians to generate the transfer approval (VAA)..."
        *   **Technical Detail:** The app is now polling the Wormhole Guardian network for the VAA based on the source transaction hash.
        *   **User Message:** "The Guardians are witnessing your transfer. A cross-chain message is being prepared."

    *   **[Waiting] 3. Destination Redemption:** "Redeeming your sBTC on the Rootstock network..."
        *   **Technical Detail:** The VAA has been received. The app is now broadcasting the pre-authorized "redeem" transaction on Rootstock.
        *   **User Message:** "Finalizing the bridge. Your assets are arriving on Rootstock."

3.  **Completion:**

    *   All steps are check-marked.
    *   A final "Complete" status is shown with a link to the destination transaction on a Rootstock explorer.
    *   A native OS notification is triggered: "Your transfer of 0.5 sBTC to Rootstock is complete."

---

### **Friction & Edge Cases:**

*   **Stuck Transaction:** If the source transaction is not confirmed after a reasonable time (e.g., 1 hour), the UI will show a "Stalled" status with an option to "Try to accelerate" (if the network supports it) or "Contact Support."
*   **VAA Not Generated:** If the VAA is not generated after a long period, the UI will indicate this and provide guidance.
*   **App Closed:** If the user closes the app, the tracking process will continue in the background. When the app is re-opened, the status tracker will reflect the latest state.

---
[Return to Root README](../README.md) | [Strategic Alignment](../ALIGNMENT.md)
