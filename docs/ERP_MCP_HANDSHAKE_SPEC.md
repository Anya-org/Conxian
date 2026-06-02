# ERP-to-Bitcoin Handshake Specification (MCP)

**Date**: March 26, 2026
**Protocols**: OData v4, x402 Intent Mandate, MCP
**Target Systems**: SAP S/4HANA (Release 26A), Oracle Cloud ERP

## Implementation References (CON-494)
- `conxian-gateway` PR #88 (`26da57559f79ff5e4d77962676c87d5d39d4965a`): literal `402 Payment Required` parsing and x402 filter enforcement.
- `conxian-nexus` PR #67 (`c4c1a800fec656cdfc2a86482a0b5c904da8af79`): production ERP attestation verification for signed mandates.

## 1. Overview
The MCP (Model Context Protocol) server acts as a secure bridge between enterprise AI agents (like SAP Joule) and the Conxian Sovereign Stack. It allows the ERP to authorize high-value "Intent Mandates" that are cryptographically signed by Conxius.

## 2. The Authorization Flow
1. **Trigger**: An SAP Joule agent identifies a needed action (e.g., "Rebalance Opex Vault").
2. **Intent Generation**: The ERP generates an OData v4 payload representing the work order.
3. **MCP Tool Call**: The SAP Joule agent calls the `authorize_intent` tool on the Conxian MCP server.
4. **Mandate Wrapping**: The MCP server wraps the OData payload into an `x402Request`.
5. **Enclave Signature**: The MCP server triggers a notification to the Conxius Wallet (Secure Enclave) for a biometric signature.
6. **Settlement**: Once signed, the intent is submitted to the Stacks/Bitcoin L2 for execution via the Gateway.

## 3. MCP Server Tool Definition (Rust)

```rust
/// Authorize an ERP-generated intent for sovereign execution.
#[mcp_tool]
async fn authorize_intent(
    system: String, // "SAP" | "ORACLE"
    payload: Value,  // OData v4 Payload
    priority: u8,
) -> Result<X402Response, ConxianError> {
    // 1. Translate OData to x402
    let mandate = translate_odata_to_x402(payload)?;

    // 2. Request Enclave Attestation
    let attestation = request_mobile_enclave_signature(mandate.hash())?;

    // 3. Submit to Gateway
    gateway_client.submit_mandate(mandate, attestation).await
}
```

## 4. x402 Intent Mandate Structure
- **Origin**: ERP System ID (e.g., SAP-PROD-01)
- **Nonce**: Sequential identifier for replay protection.
- **Action**: Enum of protocol operations (REBALANCE, DISBURSE, SETTLE).
- **Attestation**: Hardware-anchored root of trust from the Conxius Secure Enclave.

---
🛡️ **ERP-READY. HARDWARE-SECURED.**
