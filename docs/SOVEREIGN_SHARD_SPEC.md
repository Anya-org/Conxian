# Conxian Sovereign Shard Specification (ATS v4.7)

## 1. Objective
Enable external businesses (ETH/SOL/EVM) to "rent" a Conxian route for AI-agentic commerce while ensuring all settlement terminates in Bitcoin-native sBTC.

## 2. Onboarding Workflow
1. **Shard Initialization**: Business deploys a local Sovereign Shard (Containerized Gateway).
2. **Mandate Registration**: External agents register x402 Cart Mandates with the Shard.
3. **Tax Extraction**: The Shard automatically sweeps the 100bps (1%) protocol fee via the Clarity `revenue-automation` contract.
   - Fee conversion (into treasury denomination assets via ALEX) is keeper-driven and documented in `docs/PROTOCOL_FEE_SWEEP_RUNBOOK.md`.
4. **TEE Attestation**: All transactions must be signed by a hardware enclave (StrongBox/TEE) verified by the lib-conclave-sdk.

## 3. Technical Requirements
- **SDK**: `lib-conclave-sdk` (pinned via the `conxian-business` submodule)
- **Protocol**: x402 / AP2
- **Settlement**: Stacks (sBTC) or Bitcoin L1 (via DLC)
- **Fee**: 100 bps (Hardcoded in Clarity)

## 4. Compliance Sharding
State is committed to Tableland (Decentralized State Machine) to bypass localized SARB Exchange Control regulations.
