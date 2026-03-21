# OpenClaw Sovereign Sandbox (TEE) Specification

## 1. Objective

Architect a secure, hardware-isolated execution environment for the OpenClaw autonomous engine within the `Fiscal-Vault-Oracle`.

## 2. Trusted Execution Environment (TEE) Deployment

- **Platform**: AWS Nitro Enclaves or Sovereign Bare-Metal (TPM 2.0 + Intel SGX/AMD SEV).
- **Isolation Level**: Zero raw shell access. The environment is entirely immutable after boot.
- **Attestation**: Cryptographic attestation of the enclave image (PCR quotes) must be verified by the `conxian-nexus` before the oracle is granted access to treasury keys.

## 3. Network Air-Gapping

- **Inbound**: Only authorized Model Context Protocol (MCP) RPC calls via a secure Unix Domain Socket.
- **Outbound**:
    - **Air-Gapped**: No direct public internet access.
    - **Proxy Routing**: External data requirements (e.g., LSEG pricing) are fetched by a host-side proxy and delivered via MCP `read_resource` calls.
    - **State Updates**: All state changes are committed to the `conxian-business` Supabase layer via a hardened MCP bridge.

## 4. Execution Policy (Zero-Shell)

- **Engine**: OpenClaw runs as a specialized runtime, not a general-purpose OS.
- **Binary**: The TEE image contains only the OpenClaw runtime and the treasury logic; all standard shell utilities (sh, bash, ssh) are stripped.
- **Control Flow**: Execution is strictly deterministic based on incoming MCP intents and pre-signed `IntentMandates`.

## 5. Security Audit Trail

- **Measurement**: Enclave measurement (MRENCLAVE) is recorded on the Bitcoin L1 via an OP_RETURN anchor in the `conxian-nexus` state root.
- **Transparency**: Every decision cycle is logged to a Decentralized Web Node (DWN), cryptographically signed by the enclave's unique identity key.
