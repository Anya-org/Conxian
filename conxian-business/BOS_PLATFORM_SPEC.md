# BOS Platform Specification: Business-as-a-Platform (BaaP)
**Version:** v2.1 (Platform Era - Alignment with Top-Tier Systems)
**Status:** IMPLEMENTATION READY

## 1. Vision
The Conxian Sovereign BOS is evolving from a single-tenant operational tool into a **Business-as-a-Platform (BaaP)**. This allows 3rd party businesses to deploy, run, and govern autonomous operations using the Conxian Sovereign stack, inheriting the efficiency of Oracle Autonomous and the extensibility of SAP Clean Core, but with Bitcoin-native sovereignty.

## 2. Multi-Tenancy: Jurisdictional Sharding
To maintain sovereignty and security across multiple tenants, the BOS implements **Jurisdictional Sharding**:

- **Sovereign Elastic Pools**: Shared compute resources (Akash) with strictly isolated state shards.
- **Namespace Isolation**: Each tenant is assigned a unique namespace (e.g., Kwil namespace or BNS name) for state anchoring.
- **Context Isolation**: Strategy Nexus (EXCO) uses the `AsyncLocalStorage` (Node.js) or `ContextVar` (Python) pattern for per-tenant session isolation, ensuring zero data leakage between concurrent business processes.
- **Resource Governance**: Tenants define their own "Sovereign Guardrails" (144-block timelocks, multi-sig thresholds) independent of the Conxian parent.

## 3. Sovereign Node Architecture (BiaB)
A "Sovereign Node" is a containerized "Business-in-a-Box" deployment instantiated from a declarative **BOS Blueprint**:
- **Strategy Nexus**: The core intelligence and orchestration agent (Orchestrator).
- **Fiscal Vault**: Secure treasury and yield management (Executor).
- **Nakamoto Guardian**: Automated compliance and policy enforcement (Guardian/Attestor).
- **Sovereign Ops**: Labor coordination and industrial ERP bridge (Execution).

### Deployment Stack
- **Compute**: Akash Network - Managed via standard SDL templates.
- **Storage**: Kwil (Relational) + Tableland (State Roots).
- **Identity**: DID (Decentralized Identifier) anchored to Bitcoin/Stacks.
- **Interface**: MCP (Model Context Protocol) v1.0.

## 4. Standardized MCP Interfaces
All BaaP-compliant nodes MUST expose the standardized MCP toolset. This enables "Agentic Interoperability" where one business's agent can request services from another business's agent via secure MCP handshakes.

### Canonical MCP Tools:
- `bos_get_mandate_status(mandate_id)`: Checks the status of an x402 payment/settlement mandate.
- `bos_trigger_settlement(payload)`: Initiates a Bitcoin-native settlement for an approved invoice.
- `bos_verify_compliance(document_hash)`: Returns an attestation from the Nakamoto Guardian.

## 5. Portability & Transferability (Sovereign Blueprints)
- **Zero Lock-in**: All authoritative state is on-chain or in decentralized storage.
- **Logic Portability**: Skills and agents are defined in portable Markdown/YAML/Python (e.g., CrewAI `Agent` and `Task` definitions).
- **Governance Portability**: The SAB can transition to a DAO or a different trust model without rebuilding the system.
- **Ease of Use**: "Sovereign Blueprints" allow one-click setup for common business models (e.g., Supply Chain Lab, Fintech Hub).

---
*Maintained by the Sovereign Orchestrator. Linked to CON-474.*
