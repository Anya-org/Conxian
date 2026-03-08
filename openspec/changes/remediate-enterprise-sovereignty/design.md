# Design: Enterprise Sovereignty Architecture (March 2026)

## 1. Multi-Business Structure
The ecosystem is organized into four standalone businesses, each with dedicated logic and state management.

### 1.1 Conxius (B2C Access)
- **Role**: Sovereign Android Vault for mobile users.
- **Components**: Android TEE/StrongBox signing, Kotlin-based MCP server.
- **State**: Independent BIP-322 verified logins.

### 1.2 Conxian Sovereign Finance (CSF) (B2B/B2C Finance)
- **Role**: Bitcoin-Native Settlement Protocol.
- **Components**: 21+ Clarity modules, CXIP-013 Revenue distribution.
- **State**: Stacks L1 / sBTC v1.0.

### 1.3 Conxian Fusion (B2B Connectivity)
- **Role**: Institutional Gateway & ERP Bridge.
- **Components**: Rust Actix-web Gateway, "The Engine" (Deterministic Sync).
- **State**: ERP/TMS Webhooks, stateless translation.

### 1.4 Conxian Nexus (B2B State)
- **Role**: Trustless State & Risk Oracle.
- **Components**: Merkle State Proofs, Glass Node Telemetry.
- **State**: Single source of truth for blockchain height and risk metrics.

## 2. Asset Specification (ARTs & sBTC)
### 2.1 Asset-Referenced Tokens (ARTs)
- **Standard**: SIP-010 (Fungible) or SIP-009 (Non-fungible) with TEE-attested reserves.
- **Requirement**: 1:1 backing verified via Nexus-First State Model.

### 2.2 sBTC Implementation
- **Standard**: Nakamoto-ready bridge monitoring.
- **Requirement**: Asynchronous mint/burn tracking via Conxian Nexus.

## 3. Submodule & Module hierarchy
The `Conxian/contracts/` directory is the authoritative mapping for submodules.

- **Access Management**: `access/`, `identity/`, `audit-registry/`.
- **Core Logistics**: `core/`, `config/`, `constants/`, `errors/`.
- **DeFi Modules**: `dex/`, `lending/`, `vaults/`, `yield/`.
- **Agentic Logic**: `agents/`, `automation/`, `monitoring/`.
- **Treasury Operations**: `treasury/`, `revenue-distributor.clar`.
- **Infrastructure Integrations**: `cross-chain/`, `interoperability/`, `integrations/`, `sbtc/`.

## 4. Integration Logic: The Engine
- **Pattern**: Event-driven with exponential backoff.
- **Standard**: ISO 20022 XML egress for ERP compatibility.
- **Audit**: Mathematically Verifiable Compliance Reports (MVCR) generated in TEE.
