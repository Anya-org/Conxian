<<<<<<< HEAD
# Conxian Protocol - Product Requirements Document

## 1. Executive Summary

Conxian is a **Sovereign Autonomous Business (SAB)** operating on the Stacks blockchain with Bitcoin finality via
Nakamoto consensus.
The protocol implements a full **Everything-as-a-Service (XAAS)** model, providing autonomous DeFi primitives
(DEX, Lending, Vaults), multi-council governance, and monetized services.
The system generates revenue through subscription fees, transaction fees, and protocol operations,
distributing it autonomously via smart contracts.

## 2. Core Architecture

### 2.1. Design Principles

- **Bitcoin Finality**: All protocol security derives from Bitcoin's proof-of-work
- **Censorship Resistance**: Critical actions performable by any user without privileged infrastructure
- **Credible Neutrality**: No discriminatory rules based on identity or geography
- **Minimal Trust**: Algorithmic enforcement over human discretion
- **Transparency**: Full traceability and audit-ready by default

### 2.2. Facade Pattern Architecture

```
/contracts/traits/ - All trait definitions centralized here
/contracts/[module]/[contract].clar - Individual contracts
/tests/ - Comprehensive test suite
/documentation/ - System documentation only
```

### 2.3. Module Structure

- **access/** - Role-based access control
- **core/** - Protocol core logic
- **dex/** - Decentralized exchange
- **lending/** - Lending protocols
- **vaults/** - Vault management
- **governance/** - DAO and voting
- **oracle/** - Price feeds
- **security/** - Circuit breakers and monitoring
- **traits/** - All trait definitions

## 3. Technical Specifications

### 3.1. Nakamoto Compatibility

- Use `burn-block-height` instead of `block-height`
- Integrate `clarity-bitcoin` library
- Minimum 6 Bitcoin confirmations for high-value operations
- Tenure-aware operations with `get-tenure-info?`

### 3.2. Trait System

All traits must be defined in `/contracts/traits/` with standardized naming:

- `01-sip-standards.clar` - SIP-009, SIP-010, SIP-018
- `02-core-protocol.clar` - ownable, pausable, rbac
- `03-defi-primitives.clar` - pool, factory, router
- `04-dimensional.clar` - position, collateral
- `05-oracle-pricing.clar` - oracle, aggregator
- `06-risk-management.clar` - risk-manager, liquidation
- `07-cross-chain.clar` - bridge, dlc, sbtc
- `08-governance.clar` - dao, proposal-engine
- `09-security-monitoring.clar` - circuit-breaker
- `10-math-utilities.clar` - math, fixed-point
- `11-vault-traits.clar` - vault, custody, fee-manager

### 3.3. Sovereign Autonomous Business (SAXAAS) Model

**Vision**: Conxian operates as a fully autonomous on-chain organization that:

1. **Generates Revenue**: Via subscription fees, transaction fees, and service charges
1. **Distributes Revenue**: Autonomously splits revenue (60% Staking, 20% Dev, 20% Insurance)
1. **Self-Governs**: Multi-council DAO with on-chain proposal execution
1. **Self-Operates**: Office Worker system for autonomous liquidations and treasury ops

**Current Implementation Status**:

- ✅ **Revenue Generation**: `economic-policy-engine` requires subscription (1 STX)
- ✅ **Revenue Distribution**: `revenue-distributor` implements 60/20/20 split
- ✅ **Multi-Council Governance**: 10 governance contracts (treasury, emergency, vesting, etc.)
- ✅ **Office Workers**: `office-manager`, `agent-risk`, `agent-treasury` for automation
- ✅ **Oracle Infrastructure**: 7 oracle adapters (Chainlink, Pyth, Redstone, DIA, Switchboard, Federated, TWAP)

### 3.4. Error Handling

Standardized error codes from `trait-errors.clar`:

- `u1001` - Unauthorized
- `u1002` - Insufficient funds
- `u1003` - Invalid input
- `u1004` - Contract paused
- `u1005` - Insufficient confirmations

## 4. Feature Requirements

### 4.1. Core DeFi Features

- [x] Token swaps (DEX) - `swap-manager`, `multi-hop-router-v3`
- [x] Liquidity provision - `concentrated-liquidity-pool`, `stable-swap-pool`
- [x] Lending and borrowing - `lending-manager`, `interest-rate-model`
- [x] Vault management - `sbtc-vault`, `yield-aggregator`
- [x] **Monetized Policy Engine** - `economic-policy-engine` (subscription-gated)
- [x] Oracle price feeds - 7 oracle adapters
- [x] Cross-chain bridges - Wormhole handlers (stub)

### 4.2. SAXAAS Business Features

- [x] **Revenue Distribution** - `revenue-distributor` (60/20/20 split)
- [x] **DAO Treasury** - `dao-treasury` with vault trait
- [x] **Emergency Governance** - `emergency-governance` (circuit breaker)
- [x] **Founder Vesting** - `founder-vesting` (linear unlock)
  - **Implementation**: A standalone contract that manages linear vesting schedules for multiple beneficiaries. The contract owner can add new schedules, and beneficiaries can claim their vested tokens at any time.
  - **State Transitions**:
    - `add-vesting-schedule`: Adds a new vesting schedule to the `vesting-schedules` map.
    - `claim-vested-tokens`: Calculates the vested and claimable amounts based on the current block height, transfers the tokens to the beneficiary, and updates the `claimed-amount` for that schedule.
  - **Complexity**: The contract's operations are all O(1), as they only involve direct map lookups and arithmetic operations. Gas costs are minimal and constant, regardless of the number of vesting schedules. The gas cost for a `claim-vested-tokens` call can be modeled with the following formula:
  $$ G_{claim} = C_{base} + C_{map\_read} + C_{arithmetic} + C_{transfer} $$
  Where:
  -   $C_{base}$ is the base cost of a contract call.
  -   $C_{map\_read}$ is the cost of reading from the `vesting-schedules` map.
  -   $C_{arithmetic}$ is the cost of the vesting calculation.
  -   $C_{transfer}$ is the cost of the `stx-transfer?` call.
- [x] **Gamification** - `gamification-manager` (XP system)
- [x] **Legal Registry** - `legal-representative-registry` (KYC mapping)
- [x] **ICO System** - `ico-offering` (token sale logic)
- [x] **Signature Verification** - `governance-signature-verifier` (SIP-018)
- [x] **Upgrade Control** - `upgrade-controller` (governance-gated)

### 4.3. Security Features

- [x] Circuit breaker functionality
- [x] MEV protection
- [x] Role-based access control
- [x] Upgradeable contracts
- [x] Audit registry
- [x] Compliance monitoring

### 4.3. Integration Requirements

- [x] StacksOrbit deployment tool
- [x] Hiro API integration
- [x] sBTC adapter
- [x] Clarity SDK compatibility
- [x] Testnet deployment support

## 5. Development Workflow

### 5.1. Contract Development

1. Define traits in `/contracts/traits/`
1. Implement contracts in respective modules
1. Write tests in `/tests/`
1. Run `clarinet check` for validation
1. Deploy with StacksOrbit

### 5.2. Testing Strategy

- Unit tests for each contract
- Integration tests for module interactions
- Security tests for edge cases
- Performance tests for gas optimization
- End-to-end tests for full workflows

### 5.3. Deployment Process

1. Local development with Clarinet
1. Testnet deployment verification
1. Security audit
1. Mainnet deployment
1. Post-launch monitoring

## 6. Documentation Structure

### 6.1. Required Files Only

- `README.md` - Project overview and setup
- `PRD.md` - This document
- `CHANGELOG.md` - Version history
- `CONTRIBUTING.md` - Development guidelines
- `LICENSE` - GPL-3.0 license

### 6.2. Documentation Locations

- `/contracts/traits/README.md` - Trait architecture
- `/contracts/[module]/README.md` - Module-specific docs
- `/documentation/` - System architecture only
- No redundant reports or analysis docs

## 7. Success Metrics

### 7.1. Technical Metrics

- 100% test coverage for critical functions
- <100ms average transaction confirmation
- <0.1% contract failure rate
- Zero critical security vulnerabilities

### 7.2. Adoption Metrics

- 1000+ active users
- $1M+ TVL
- 10+ integrated applications
- 100+ deployed contracts

## 8. Risk Management

### 8.1. Technical Risks

- Smart contract bugs → Comprehensive testing and audits
- Oracle manipulation → Multiple price feeds and circuit breakers
- Gas price volatility → Dynamic fee adjustment

### 8.2. Business Risks

- Regulatory changes → Compliance monitoring and adaptability
- Market volatility → Risk management and insurance
- Competition → Continuous innovation and community building

## 9. Timeline

### Phase 1: Core Infrastructure (Q1 2026)

- Complete trait system
- Deploy core contracts
- Implement security features

### Phase 2: User Applications (Q2 2026)

- Launch DEX interface
- Deploy lending protocols
- Implement governance

### Phase 3: Ecosystem Growth (Q3 2026)

- Third-party integrations
- Advanced features
- Mainnet launch

## 10. Resources

### 10.1. Development Tools

- Clarinet SDK for contract development
- StacksOrbit for deployment
- Hiro API for blockchain interaction
- Conxian UI for user interface

### 10.2. Community Resources

- GitHub repository for development
- Discord for community support
- Documentation for developers
- Tutorials for users

---

**Version**: 1.1
**Last Updated**: 2026-01-16
**License**: GPL-3.0

## 11. Implementation Status (2026-01-16)

### Recently Implemented

- **Concentrated Liquidity**: `contracts/dex/concentrated-liquidity-pool.clar` implemented with tick/position management.
- **DEX Factory V2**: `contracts/dex/dex-factory-v2.clar` implemented with multi-pool type support.
- **Multi-Hop Router V3**: `contracts/dex/multi-hop-router-v3.clar` implemented with atomic path execution.
- **MEV Protection**: `contracts/security/mev-protector.clar` enhanced with commit-reveal validation.
- **Enterprise**: `contracts/enterprise/institutional-account-manager.clar` created to support enterprise facade.
- **Math Libraries**: `contracts/math/math-lib-concentrated.clar` implemented with geometric series math (Uniswap V3 style).
- **Oracle System**: `contracts/dex/oracle-aggregator-v2.clar` enhanced with TWAP and manipulation detection.
- **Yield Optimizer**: `contracts/yield/yield-optimizer.clar` enhanced with strategy selection and risk scoring.
- **Testing**: Added unit tests for concentrated liquidity in `tests/dex/concentrated-liquidity.test.ts`.

### Resolved Issues

- **Compilation Fixes**: Resolved circular dependencies and missing entries in `Clarinet.toml`.
- **Trait Alignment**: Corrected `office-job-trait` implementation in `agent-treasury` and `agent-risk`.
- **Syntax Errors**: Fixed `fold` argument order in `admin-facade` and contract calls in `proposal-executor`.
- **Version Compatibility**: Updated Clarity versions for `dex-factory-v2` and `math-lib-concentrated`.

### Pending Action Items

- **Testing**: Expand test coverage for new components.
- **Deployment**: Verify all contracts on testnet.

## 12. Recovery Registry (BOLT ⚡ Initiative)

This section logs all files isolated during the Level 0 Root Stabilization phase. The goal is to create a clear record of stabilization actions and prevent knowledge decay.

| File Path | Reason for Isolation | Required Fix |
| :--- | :--- | :--- |
| `tests/setup-test-env.ts` | Asynchronous Race Condition | The `initSimnet()` function is not awaited by the test runner, causing the `simnet` global to be undefined when tests execute. |
| `contracts/drafts/federated-oracle-adapter.clar` | Non-functional stub | Awaiting full implementation. |
| `contracts/drafts/interest-rate-model.clar` | Pending Security Review | The contract is complete but requires a comprehensive security audit before reintegration. |
| `contracts/drafts/lending-manager.clar` | Architectural Redesign | Awaiting a redesign to align with the latest PRD specifications for multi-asset collateral. |
| `contracts/drafts/regulatory-adapter.clar` | SIP-018 Compliance | Being updated to support the latest SIP-018 standards for digital signatures. |

## 13. Benchmarks (Vitest 4.0)

This section provides a summary of the latest performance metrics from the Vitest 4.0 test suite. The goal is to track the gas costs and execution times of critical functions to prevent performance regressions.

*NOTE: This section is a placeholder and will be populated with data from the automated testing pipeline.*

| Contract | Function | Gas Cost (Mean) | Execution Time (ms) |
| :--- | :--- | :--- | :--- |
| `admin-facade.clar` | `batch-update-roles` | (TBD) | (TBD) |
| `conxian-protocol.clar` | `batch-register-modules` | (TBD) | (TBD) |
| `dimensional-engine.clar` | `open-position` | (TBD) | (TBD) |
=======
# Conxius Wallet PRD (Android-First)

## 1. Product Overview

Conxius is a sovereign, offline-first Android wallet that bridges the Bitcoin ecosystem (L1, Lightning, Stacks, Rootstock, Liquid, Nostr) with interlayer execution capabilities.

The primary differentiator is the **Native Enclave Core**: keys for all supported protocols are generated and used within a hardened boundary (Android Keystore + memory-only seed handling) and never leave the device's secure memory.

## 2. User Personas

- **The Sovereign Hodler**: Wants deep cold storage security on a mobile device. Uses Conxius as a daily driver for small-to-medium amounts, trusting the Android TEE.
- **The Interlayer Explorer**: Moves assets between Bitcoin L1 and rollups/sidechains (Stacks, Liquid, RSK). Needs a reliable bridge client that verifies attestations locally.
- **The Social Nomad**: Uses Nostr for uncensored communication and identity (NIP-06), requiring a secure signer that doesn't expose keys to web relays.
- **The Node Operator**: Connects to their own LND/Core node for privacy via the embedded Breez SDK Greenlight client or remote connection.

## 3. User Journeys

### 3.1. Onboarding (New Wallet)

- **Trigger**: First launch.
- **Flow**:
  1. Splash screen (Boot sequence).
  2. "Create Wallet" vs "Import Wallet".
  3. PIN creation (6+ digits).
  4. Seed generation (BIP-39) inside the Secure Enclave.
  5. **Critical**: User must verify backup (e.g., select words 3, 7, 12).
  6. Biometric enrollment (optional but encouraged).
  7. Dashboard loads with multi-chain view.

### 3.2. Daily Spend (BTC L1)

- **Trigger**: User wants to send BTC.
- **Flow**:
  1. Scan QR or paste address.
  2. Enter amount (Fiat/BTC toggle).
  3. Review fee (Low/Med/High).
  4. "Slide to Pay".
  5. Auth challenge (Biometric/PIN) triggers Native Enclave signing.
  6. Success screen (TxID + Explorer link).
  7. Notification when confirmed.

### 3.3. Lightning Payment (0-Gas)

- **Trigger**: User scans LNURL/BOLT11.
- **Flow**:
  1. App parses intent (Pay/Withdraw).
  2. Shows amount/description.
  3. Confirm payment.
  4. **Enclave Action**: Seed is decrypted natively and passed directly to Breez SDK memory (Zero-Leak).
  5. Instant settlement toast.

### 3.4. Sovereign Identity (Nostr & D.iD)

- **Trigger**: User logs into a Nostr client or D.iD service.
- **Flow**:
  1. "Connect Identity".
  2. **Enclave Action**: NIP-06 private key is derived on-demand from master seed (`m/44'/1237'/...`).
  3. Public Key (`npub`) is returned to UI.
  4. Events are signed natively without exposing the private key (`nsec`).

### 3.5. Multi-Chain Bridge (Liquid/Stacks/RSK)

- **Trigger**: User manages sidechain assets.
- **Flow**:
  1. Select Asset (e.g., L-BTC, STX).
  2. Enclave derives protocol-specific keys (`m/84'/1776'` for Liquid, `m/44'/5757'` for Stacks).
  3. Transaction constructed and signed natively.
  4. Broadcast to respective network.

## 4. Functional Requirements

### 4.1. Key Management (Native Enclave Core)

- **FR-KEY-01**: Master Seed must be encrypted at rest using Android Keystore AES-GCM.
- **FR-KEY-02**: Decrypted seed must reside in memory only during signing/startup and be zeroed immediately after.
- **FR-KEY-03**: Biometric authentication must be required to decrypt the master seed for high-value operations.
- **FR-KEY-04**: Support standard derivation paths:
  - Bitcoin: `m/84'/0'/0'/0/0` (Native Segwit)
  - Stacks: `m/44'/5757'/0'/0/0`
  - Rootstock (EVM): `m/44'/60'/0'/0/0`
  - Liquid: `m/84'/1776'/0'/0/0`
  - Nostr: `m/44'/1237'/0'/0/0`

### 4.2. Transactions

- **FR-TX-01**: Must support BIP-84 (Native Segwit) derivation.
- **FR-TX-02**: Must parse and validate BIP-21 URIs.
- **FR-TX-03**: Must prevent dust outputs during coin selection.
- **FR-TX-04**: Support atomic swaps and peg-ins/peg-outs where applicable.

### 4.3. Connectivity

- **FR-NET-01**: All external API calls must be user-auditable (list of endpoints).
- **FR-NET-02**: Support for Greenlight (Breez SDK) for non-custodial Lightning.

## 5. Non-Functional Requirements

### 5.1. Security

- **NFR-SEC-01**: No sensitive data in logs (seed, private keys, macaroons).
- **NFR-SEC-02**: App preview in "Recents" must be obscured (FLAG_SECURE).
- **NFR-SEC-03**: Root detection warning on startup.
- **NFR-SEC-04**: 0-Gas efficiency for Identity and Lightning Auth.

### 5.2. Reliability

- **NFR-REL-01**: App must work offline (view cached state).
- **NFR-REL-02**: Bridge state must persist across app restarts.

### 5.3. Performance

- **NFR-PERF-01**: Cold launch to Lock Screen < 1s.
- **NFR-PERF-02**: Unlock to Dashboard < 2s.
- **NFR-PERF-03**: Identity derivation < 200ms (cached).

## 6. Release Strategy

- **Alpha (Internal)**: Debug builds, mock assets.
- **Beta (Testnet)**: Public testnet builds, real crypto disabled or testnet-only.
- **Production**: Mainnet enabled, strict security review, APK signing with release keys.

## 7. Continuous Improvement

- **PRD Updates**: This document is the source of truth. Any architectural change (e.g., adding a new chain) triggers a PRD update PR.
- **Testing**: Every PR must pass `testDebugUnitTest` for Android and `npm test` for logic.
- **Verification**: Release builds are verified on physical Pixel devices before publication.
>>>>>>> 2b7ceb80d13077a5ed3f3a4228acdc870843f446
