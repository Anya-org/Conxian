# Conxian Intent Solver Gateway

## Intent Schema (v1)

The Intent Layer allows users on any chain (Arbitrum, Ethereum, Bitcoin) to express financial desires that are settled natively on Stacks by Conxian Solvers.

### 1. Cross-Chain Swap Intent
```typescript
interface SwapIntent {
  intentId: string; // 32-byte hex string
  sourceChain: "ARBITRUM" | "ETHEREUM" | "BITCOIN";
  sourceUser: string;
  tokenIn: string; // Source chain token address
  tokenOut: string; // Stacks token principal (e.g., .cxd-token)
  amountIn: string; // BigInt string
  minAmountOut: string;
  deadline: number; // Stacks block height
  solverFee: string;
}
```

### 2. State Proof Structure
```typescript
interface StateProof {
  proofType: "SPV" | "ZKP" | "ATTESTATION";
  payload: Buffer; // Raw proof bytes
  signature: Buffer; // Solver/Oracle signature
}
```

## BME Integration
Solvers who successfully execute intents are registered as "Activity Markers" in the `bme-engine.clar`. They receive a portion of the epoch minting proportional to the volume they settle.

## Hardware Security
All Intent payloads are designed to be deterministic and minimal, allowing for transparent signing on Android TEE (StrongBox) devices within the Conxius Wallet.

## x402 Payment Protocol
The gateway implements the x402 Payment-Required standard for industrial API access. Requests to `/v1/industrial/payment` without a valid `payment-signature` or `x-payment` header will receive a 402 response with requirements.

## Diataxis Alignment
### Overview
The Conxian Intent Solver Gateway is an Express-based service that bridges off-chain institutional intents (ISO 20022, ERP OData) with on-chain Stacks settlement.

### Architecture
The gateway uses a middleware-driven architecture for webhook verification and x402 payment enforcement, with specialized parsers for financial message standards.

### Core Contracts
Integrates with `intent-solver-gateway.clar` and `bme-engine.clar` for settlement and reward distribution.

### Integration Examples
Use `curl -H "payment-signature: <base64>"` to submit a paid intent to the `/v1/industrial/payment` endpoint.

### Testing
Run `npm test` to execute the integration suite covering ISO 20022 parsing and x402 handshakes.

### Status
Active development. x402 industrial intent alignment (CON-451) is implemented and verified in simulation.
