# Conxian Sovereign System Evolution Report (v1.0)

**Date**: April 10, 2026
**Status**: Strategic Advisory
**Classification**: Public (Sovereign-First)

## 1. Executive Summary

This report outlines the transition path for the Conxian ecosystem from its "Web2-Assisted Bootstrap" phase to a "Full-Stack Sovereign Bitcoin-Native Solution." To fulfill the system ethos—Decentralized, Sovereign, Bitcoin-native, Dimensionally Aligned, and Autonomous—all non-native dependencies (Neon, Supabase, Linear, Render, Vercel, GitHub) must be treated as temporary scaffolds and systematically replaced by Bitcoin-aligned alternatives.

## 2. The Conxian Ethos Alignment

| Principle | Requirement | Target State |
| :--- | :--- | :--- |
| **Decentralized** | No single point of failure or censorship. | P2P protocols (Nostr, Radicle) and DeCloud (Akash). |
| **Sovereign** | Full control over state, logic, and infrastructure. | Self-hostable, open-source binaries; no SaaS dependencies for correctness. |
| **Bitcoin Native** | Settlement and security anchored in BTC. | Stacks L2, sBTC, DLCs, and BitVM2 state roots. |
| **Dimensionally Aligned** | Work labor coordination matches industrial intent. | CJCS v2.0.1 JSON-LD and ERP-to-Bitcoin handshakes. |
| **Autonomous** | Self-executing, incentive-aligned agents. | AI agents with x402 mandates and on-chain reputation. |

## 3. Current System Inventory & Sovereignty Gaps

| Web2 Dependency | Role | Risk | Sovereign Alternative |
| :--- | :--- | :--- | :--- |
| **Neon (PostgreSQL)** | Transactional State | Centralized database authority; hosting risk. | **Kwil** (Relational SQL on-chain). |
| **Supabase** | Analytics & BOS State | Vendor lock-in; data siloing; non-native proofs. | **Tableland** (Audit) / **Space and Time** (Analytics). |
| **Linear** | Task Coordination | Centralized workflow; secret egress risk (ZSE). | **Radicle Issues** / **Sovereign Ops Orchestrator**. |
| **Render / Vercel** | Hosting & CI/CD | Platform censorship; centralized entry points. | **Akash Network** (Compute) / **IPFS** (Static). |
| **GitHub** | Code Hosting | Centralized source of truth; account risk. | **Radicle** (P2P Code Collaboration). |
| **Google Gemini** | AI Inference | Proprietary models; privacy risk. | **Self-hosted LLMs** (via Akash/Golem) / **Nostr NWC**. |

## 4. Target Architecture: The Full Bitcoin Stack

### Layer 1: Bitcoin (The Bedrock)
- **Settlement**: Native BTC and sBTC (SIP-034).
- **Security**: PoX (Proof of Transfer) and BitVM2 State Root verification.
- **Finance**: Discreet Log Contracts (DLCs) for non-custodial lending/bonds.

### Layer 2: Stacks (The Logic)
- **Execution**: Clarity Smart Contracts (CSF).
- **Assets**: sBTC, BNS (Identity), and SIP-010 tokens.
- **Coordination**: Nakamoto microblocks for < 5s finality.

### Persistence Layer (The Memory)
- **Kwil**: Primary relational datastore for high-frequency transactional state (MMR nodes, peaks).
- **Tableland**: Publicly verifiable audit mirror for MEV and governance state roots.
- **Arweave**: Permanent storage for heavy documentation and historical audit logs.

### Compute & Hosting (The Muscle)
- **Akash Network**: Decentralized cloud for running Nexus nodes, Gateway engines, and UI surfaces.
- **Enclaves (TEE)**: Hardware-backed signing via lib-conclave-sdk (StrongBox).

### Identity & Messaging (The Connection)
- **Nostr**: The universal transport layer for Agentic Intents (NIP-47 NWC).
- **Web5/DIDs**: Decentralized identifiers for sovereign participants.

## 5. Migration Roadmap: The 2026 Sovereign Clean Break

### Phase 1: Relational State Handoff (Active)
- **Action**: Cutover Nexus transactional state from Neon to Kwil.
- **Status**: KwilAdapter implemented (v0.5.0); pilot schema verified.

### Phase 2: Compute Sovereignty (Q2 2026)
- **Action**: Migrate Gateway and UI hosting from Google Cloud/Render to Akash Network.
- **Prerequisite**: Containerization of all components (Nexus, Gateway, UI).

### Phase 3: Coordination Migration (Q3 2026)
- **Action**: Replace Linear tasks with Radicle-native issues or a custom Sovereign Ops Dashboard.
- **ZSE Hardening**: Remove all external links from repo stubs; point to sovereign coordination layer.

### Phase 4: AI & Identity Alignment (Q4 2026)
- **Action**: Integrate local LLM inference for the Conxius Wallet (Satoshi Auditor).
- **Action**: Full implementation of Web5 DIDs anchored to Stacks BNS.

## 6. Repository Review & Advice

### 6.1. General Advice for All Repos
- **Strict ZSE Compliance**: Ensure no secrets or operational logic leak into public repos. Use the canonical ZSE stub template.
- **Dependency Reduction**: Minimize "SaaS-native" libraries. Favor portable, standard protocols (REST/gRPC over proprietary SDKs).
- **Containerization**: Every repo must have a production-ready Dockerfile and Akash SDL (deploy.yaml).

### 6.2. Specific Repo Guidance
- **conxian-nexus**: Prioritize the "Fail-Closed" Kwil migration. Ensure the MMR state can be rebuilt solely from L1 events.
- **conxian-gateway**: Implement the x402x payment handler to allow Bitcoin-native machine-to-machine commerce.
- **conxius-wallet**: Decouple the "Satoshi Auditor" from Google GenAI; provide an option for local model execution or Nostr-based AI requests.
- **conxian-ui**: Remove Render-specific build scripts; transition to a standard Vite/Next.js static export for IPFS/Akash hosting.

---
🛡️ **THE FUTURE IS SOVEREIGN. THE STACK IS BITCOIN.**

## 7. Individual Repository Remediation Advice

### 7.1. Decentralization-Critical (P0)

#### [Conxian (CSF Protocol)](../Conxian)
- **Status**: Mainnet Pending.
- **Advice**: Ensure `bounty.clar` and `agent-registry.clar` are prioritized to enable autonomous agent economies. Verify that no hardcoded testnet principals remain in the deployment plans.

#### [conxian-nexus](../conxian-nexus)
- **Status**: Mainnet Pending.
- **Advice**: Finalize the cutover to `KwilAdapter` for all transactional state. Implement a "Self-Healing" mode where the node automatically reconciles against on-chain checkpoints every 144 blocks.

#### [conxian-gateway](../conxian-gateway)
- **Status**: Mainnet Pending.
- **Advice**: Transition from Google Cloud Run to Akash Network. Add support for x402x micro-payments to enable machine-to-machine coordination.

#### [conxius-wallet](../conxius-wallet)
- **Status**: Mainnet Pending.
- **Advice**: Move AI logic to a "Sovereign-First" model. Allow users to point to their own local LLM endpoint or a decentralized inference provider. Hardcode support for Nostr NIP-47 (NWC) for all remote actions.

### 7.2. Governance & EXCO (P0)

#### [Fiscal-Vault-Oracle](../Fiscal-Vault-Oracle)
- **Status**: Active (Stubbed).
- **Advice**: Move the "Treasury MCP" logic from Linear to a sovereign, encrypted coordination layer. Implement the DLC Bond principal drawdown logic as a fully automated on-chain flow.

#### [Nakamoto-Guardian](../Nakamoto-Guardian)
- **Status**: Active (Stubbed).
- **Advice**: Automate the "Anti-Fragility Loop" to run as a GitHub Action (and eventually an Akash Worker) that scans the entire portfolio for ethos drift.

#### [Sovereign-Ops-Orchestrator](../Sovereign-Ops-Orchestrator)
- **Status**: Active (Stubbed).
- **Advice**: Build a decentralized "Ops Dashboard" that consumes state directly from Kwil and Tableland, removing the need for Render-hosted visualizations.

### 7.3. User Surface & Shared Runtime (P1/P2)

#### [conxian-ui](../conxian-ui)
- **Status**: Incubating.
- **Advice**: Align with the "Sovereign UI" standard: strictly static, IPFS-ready, and provider-agnostic. Remove all references to `api.testnet.hiro.so` and replace with a dynamic `CXN_GATEWAY_URL` that can point to a local or sovereign Gateway.

#### [showcase-dapp](../showcase-dapp)
- **Status**: Incubating.
- **Advice**: Use this as the "Sovereignty Sandbox." Test new decentralized hosting (Akash/IPFS) and storage (Kwil) here before rolling out to P0 repos.

### Phase 5: Business-as-a-Platform (BaaP) (Q1 2027)
- **Action**: Formalize the "Business-in-a-Box" template for 3rd party labs.
- **Action**: Implement Jurisdictional Sharding for tenant isolation on Akash/Kwil.
- **Status**: Researching (CON-474).
