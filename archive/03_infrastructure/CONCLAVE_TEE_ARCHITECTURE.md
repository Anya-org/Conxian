# Conclave Android SDK: Agentic TEE & StrongBox Architecture (2026)

## 1. Objective
To enforce "Zero Secret Egress" for autonomous AI agents by strictly isolating private key access within flagship Android hardware (StrongBox/TEE).

## 2. Agentic Hardware Isolation
The Conxius-wallet elevates security by separating the AI agent logic from the cryptographic signing layer.
- **Agent Environment**: AI agents (governed by the local Kotlin MCP Server) operate within the standard Android application environment. They generate transaction intents and construct unsigned payloads.
- **Hardware-Enclosed Signing**: Unsigned payloads are sent to the **StrongBoxManager**. The StrongBox enclave (or TEE fallback) acts as the final arbiter.
- **Zero Secret Egress**: Private keys never leave the hardware enclave. Signing occurs entirely within the physically isolated CPU/memory of the StrongBox, preventing extraction even during application-layer logic drift or prompt injection.

## 3. Protocol Guardrails: AP2 & StrongBox
Before a transaction is signed, the StrongBox verifies the payload against the **AP2 Verifiable Mandate**.
- **Mandate Check**: The enclave ensures the transaction amount, recipient, and asset type align with the cryptographically signed human mandate stored in the secure element.
- **Prompt Injection Mitigation**: Because the signing decision is made within the hardware enclave based on immutable mandates, a compromised LLM cannot autonomously "hallucinate" a transaction that drains the wallet.

## 4. MCP Server Integration
The wallet embeds a native **Kotlin Model Context Protocol (MCP)** server.
- **Localized Context**: Provides the AI agent with a type-safe interface to query wallet state and trigger authorized tools.
- **Security Barrier**: The MCP server serves as the controlled entry point, ensuring the AI only interacts with predefined, sovereign capabilities.

---
[Return to Root README](../../README.md) | [Strategic Alignment](../ALIGNMENT.md)
