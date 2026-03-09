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
