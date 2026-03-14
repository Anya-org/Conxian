# Conclave SDK & Business Growth Strategy

**Date:** March 2026
**Focus:** SDK Pricing, Go-To-Market, Virality, and Dev Community Growth
**Alignment:** Bitcoin-Native, Sovereign, Community-Governed

## 1. Market Analysis: The Web3 Security SDK Landscape

To position the **Conclave SDK** effectively, we analyzed the best-in-class security, authentication, and key management SDKs in the market (Privy, Web3Auth, Turnkey, Magic).

* **Turnkey:** The closest technical competitor. They utilize server-side TEEs (Secure Enclaves) for low-latency programmable signing. They price on a **per-signature basis** with a small free tier (100 sigs/mo).
* **Privy:** Dominates consumer Web3 (e.g., Farcaster). Focuses on embedded wallets and seamless onboarding (email/social to wallet). Pricing is typically based on **Monthly Active Wallets (MAWs)** and transaction volume, with a generous free tier (50k signatures/mo) to capture early-stage startups.
* **Web3Auth:** Popularized MPC-based social logins. Pricing scales via standard SaaS tiers based on **MAUs** (Monthly Active Users).
* **Evervault:** Traditional Web2 PCI compliance, heavily API-driven with strict usage-based pricing for securing PII and card data.

### **Conxian’s Differentiator**

Competitors rely heavily on centralized MPC networks, server-side enclaves, or proprietary infrastructure. Conxian commoditizes the **user's own mobile hardware (Android StrongBox/TEE)**. We are the only provider offering **Nakamoto-Native finality**, true self-custody with zero cloud-HSM vendor lock-in, and full alignment with the cypherpunk ethos.

---

## 2. Ethos-Aligned Pricing & Monetization Model

We are adopting a **Product-Led Growth (PLG)** pricing model. The goal is maximum top-of-funnel developer adoption, followed by automated monetization at scale.

### A. The "Dev-First" Free Tier (Community Builder)

* **Free SDK Pulls:** The Conclave SDK is open-source and free to pull, inspect, and integrate.
* **Generous Quota:** Up to 50,000 signatures/verifications per month entirely free.
* **Purpose:** Eliminate integration friction. Developers should experience an instantaneous "eureka moment" within 5 minutes of downloading the SDK. This builds the developer community organically.

### B. Automated Usage-Based Growth Tier

* **Model:** Once a dApp or L2 scales past the free tier, they automatically transition to a **pay-per-signature** or **pay-per-MAW** model.
* **Web3 Native Subscriptions:** Billing is handled via automated smart contracts. Developers can fund a "gas tank" with USDC/sBTC, and usage is metered on-chain or via decentralized oracle proofs. No credit card required.

### C. Institutional SaaS (The Cash Cow)

* **Target:** Emerging Bitcoin L2s (Mezo, BOB, B2) and Fintechs.
* **Pricing:** **$2.5k to $15k+/month**.
* **Deliverables:** Dedicated sovereign proxies (M12), custom SLAs, multi-sig quorum orchestration (Musig2), and white-glove enterprise support.

### D. The B2C Retail Engine (Conxius Wallet): Tiered & ExchangeRate Pricing

To maximize global adoption while respecting local economic realities, we are implementing a **Purchasing Power Parity (ExchangeRate)** pricing model. At standard FX rates (~16 to 19 ZAR per 1 USD), a $9.99/mo subscription equates to almost R190, which heavily prices out emerging market users. By adjusting for ExchangeRate, we can capture massive volume across all demographics.

* **Tier 1: Conclave Starter ($1.00/mo)**:
    * **Target:** Emerging markets (e.g., South Africa, LATAM) and entry-level retail users (~R18 ZAR/mo).
    * **Features:** Standard Tor routing, basic 2-of-3 multi-sig, standard swap fees. Lowers the barrier to entry to convert free users into paid, loyal customers.
* **Tier 2: Conclave Pro ($9.99/mo Standard | ~$4.99/mo ExchangeRate-Adjusted)**:
    * **Target:** Power users, institutional managers, and developed markets.
    * **Features:** Unlimited multi-sig quorums, dedicated sovereign Tor circuits, zero base-fee swaps.
* **Sovereignty-Adjusted Fee (SAF):** 0.1% minimum spread on cross-chain swaps. The higher a user's sovereignty score, the lower their fees.

### E. Pricing Logic Architecture: Where Does It Live?

To maintain our "No Dark State" and "Credible Neutrality" ethos, pricing logic cannot be hidden in a centralized Web2 database. The architecture is explicitly decoupled:

1. **The Risk Oracle (`conxian-nexus`)**: Ingests real-world universal FX rates (e.g., USD, ZAR, NGN, EUR, INR, BRL) and live global ExchangeRate indices via decentralized data feeds. It provides intelligent, real-time localized pricing states to the blockchain for every region.
2. **The Smart Contract (Stacks / Bitcoin L2)**: The absolute single source of truth. Users mint a time-bound "Subscription Trait" (NFT or token balance) using stablecoins or sBTC. The contract calculates the exact cost dynamically using the Oracle's localized ExchangeRate pricing.
3. **The Router (`conxian-gateway`)**: The Rust backend purely enforces access. It reads the user's on-chain subscription state to allow or deny high-bandwidth requests, Tor orchestration, and premium API routing.
4. **The Client (`conxius-wallet` / UI)**: Strictly handles localized UX/UI display (rendering dynamic prices in the user's native fiat currency) and constructs the payment transaction for the user's hardware enclave to sign.

*Conclusion:* The **Smart Contract handles the logic**, the **Gateway enforces the rules**, and the **Client drives the experience**.

---

## 3. Go-to-Market (GTM) & Virality Strategy

Achieving viral growth requires embedding network effects directly into the product architecture.

### 3.1 Product-Led Virality (The B2B2C Flywheel)

* **"Secured by Conclave":** DApps using the free tier display a subtle "Secured by Conxian Enclave" badge. This acts as a viral marketing loop targeting end-users and other developers.
* **Cross-Pollination:** When a user creates an embedded wallet via a partner app using our SDK, that identity is portable. They are incentivized to download the flagship **Conxius Wallet** to manage their unified identity, instantly acquiring a new B2C user for $0 CAC (Customer Acquisition Cost).

### 3.2 Developer Community & Grassroots Growth

* **Open Documentation & "Time-to-Value":** Emulate Auth0 and Stripe. The SDK must have impeccable docs, copy-paste snippets, and a 1-click sandbox.
* **Bounties & Hackathons:** Sponsor Bitcoin L2 hackathons. Offer bounties for developers who build the most innovative products using the Conclave SDK.
* **Open Forums:** Foster a deeply technical community on GitHub Discussions and Discord, focusing on cryptography, TEEs, and Bitcoin scaling.

---

## 4. Sovereignty & Community Governance

Conxian is not just a software company; it is a **Sovereign Autonomous Platform**.

* **No Dark State:** All critical protocol parameters (fee rates, tier limits) will eventually be managed via open, on-chain governance traits (`.base-traits.governance-trait`).
* **Permissionless Ecosystem:** The SDK does not discriminate. Anyone can integrate it. We do not act as gatekeepers; the mathematics of the Bitcoin burn chain is the only arbiter.
* **Multi-Dimensional Growth:** As the community grows, governance token holders (devs, users, node operators) will vote on which new cryptographic primitives (e.g., ZK proofs, RGB client-side validation) the Conclave SDK should support next.

## 5. Next Actions

1. **Finalize SDK Packaging:** Extract the `conxius-wallet` StrongBox modules into a standalone, easy-to-import NPM/Rust package.
2. **Launch Developer Portal:** Deploy a minimal viable developer dashboard for API key generation and usage tracking.
3. **Draft LOIs:** Begin outreach to 5 target Bitcoin L2s offering them early access to the Institutional Tier.
