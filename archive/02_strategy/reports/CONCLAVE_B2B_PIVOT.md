# Strategy Proposal: Conclave SDK B2B Pivot & M12 "Real Rails" Proxy Deployment

## 1. Executive Summary

This document formalizes the strategic execution of Phase 5 (Level 3: Sovereign Scaling). We are extracting the hardware-grade security features of the `conxius-wallet` into a standalone, white-label **Conclave SDK** for B2B licensing. Concurrently, we are executing the **M12 "Real Rails"** milestone by deploying sovereign, self-hosted proxies to eliminate third-party API dependencies.

## 2. Package: The Conclave SDK (B2B Pivot)

The `conxius-wallet` has successfully isolated TEE (Trusted Execution Environment) and StrongBox capabilities. We will package this into `conclave-sdk-android` and `conclave-sdk-ios`.

### B2B Value Proposition

- **Target Audience:** Bitcoin L2s (BOB, B2, Mezo), Neobanks, and Corporate Treasuries.
- **Offering:** "Hardware-grade security as a Service." It allows institutions to use standard mobile devices as highly secure, mathematically verifiable signing devices (Citadels) for their corporate multi-sig quorums.
- **Licensing Model:** $2.5k - $15k/month based on MAU and required attestation layers.

## 3. M12: "Real Rails" Sovereign Infrastructure

Currently, the ecosystem relies on public APIs (e.g., Changelly, Bisq public nodes, Wormhole APIs) which introduces rate limits, privacy leaks, and margin extraction by middlemen.

### Execution Plan

1. **Bisq Sovereign Node:** Deploy a dedicated Bisq daemon adjacent to the `conxian-gateway`. The gateway will route all decentralized trades through this internal node.
2. **Changelly Direct Proxy:** Deploy a serverless proxy (GCP Cloud Run) that securely holds the `CHANGELLY_API_KEY` and routes swaps via gRPC from the gateway, keeping the API hidden from the client entirely.
3. **Wormhole NTT Relayer:** Run an in-house relayer to process cross-chain asset transfers without relying on public relayers that charge high variable fees.

## 4. Alignment with Conxian Ethos

- **Censorship Resistance:** By running our own proxies, we remove API providers' ability to censor our users' transactions.
- **Minimize Trust in Humans:** The Conclave SDK leverages Android's StrongBox, shifting trust from human OPSEC entirely to verifiable hardware and mathematics.
- **Observability:** All proxy traffic will be routed through the `conxian-gateway` to expose Prometheus metrics, allowing for continuous risk monitoring by the Nexus Risk Oracle.
