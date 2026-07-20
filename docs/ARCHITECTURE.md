# Conxian Protocol Architecture

## 1. Design Philosophy: SAXaaP
Conxian is built on the **Sovereign Autonomous X-as-a-Protocol** framework.
- **Hexagonal Architecture**: Separation of concerns between core logic (Engines), state management (Managers), and external interfaces (Facades).
- **Principal Injection**: Dynamic dependency management to resolve circularity and enable upgradability.
- **Nakamoto-First**: Temporal logic anchored to Bitcoin block heights and Stacks block times.
- **BIP Compliance**: Built with support for BIP-341 (Taproot), BIP-342 (Tapscript), and BIP-174 (PSBT) for cross-chain settlement and advanced scripting.

## 2. System Layers

### 2.1. Registry Layer (`contracts/core`)
The "Brain" of the protocol.
- `conxian-protocol.clar`: Central module registry and pause control.
- `conxian-access.clar`: RBAC with Passkey support.

### 2.2. Executive Layer (`contracts/core`, `contracts/dex`, `contracts/lending`)
The "Arms" of the protocol.
- `dimensional-engine.clar`: Orchestrates leveraged trading.
- `swap-router.clar`: Optimizes DEX routing.
- `lending-manager.clar`: Manages money markets.

### 2.3. Agent Layer (`contracts/agents`)
The "Senses" and "Nerves" of the protocol.
- `agent-risk.clar` (AYE): Predictive PID-based risk monitoring.
- `agent-treasury.clar`: Autonomous fiscal policy execution (The Fiscal Dam).

### 2.4. Asset Layer (`contracts/tokens`, `contracts/treasury`)
The "Blood" and "Vaults" of the protocol.
- `cxd-token.clar`: Native utility/governance token.
- `revenue-distributor.clar`: Real-time fee distribution.

### 2.5. Commercial Integration Layer (`contracts/integrations`)
The controlled boundary for metered external usage.
- `integration-registry.clar`: Registers integrations, configures billing,
  assigns the trusted reporter, and rotates stored key commitments.
- `integration-fee-collector.clar`: Records replay-protected usage, maintains
  per-period ledgers, and settles STX fees from the configured payer.
- Billing periods use `burn-block-height / 4320`; monthly settlement requires a
  closed period. Raw API keys stay off-chain and only SHA-256 hashes are stored.

The settlement path is `payer -> integration-fee-collector ->
revenue-distributor -> swap-router` and retains the existing BME/CXIP-013
economics. The collector invokes the existing `distribute-stx` entrypoint
under contract context; no distributor-specific setter or second collector
entrypoint is introduced.

## 3. Communication Patterns
- **Internal**: Trait-driven cross-contract calls using relative literals (`.contract-name`) for simulation and Principal Injection for production.
- **External**: Facade contracts provide simplified, gas-efficient entry points for UIs and third-party integrations.
- **Commercial Usage**: A configured reporter records usage on behalf of an
  integration; payer authorization is required for exact settlement. Payer-
  signed usage attestations and generic FT settlement are future extensions.

## 4. Revenue & Economics
The protocol utilizes **The Fiscal Dam V4** (CXIP-013) to manage its 6-way revenue split, adjusting dynamically based on the Global Collateral Ratio (GCR) and system health scores.
