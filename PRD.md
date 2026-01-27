# Conxian Finance Protocol - Product Requirements Document

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

```text
/contracts/traits/ - All trait definitions centralized here
/contracts/[module]/[contract].clar - Individual contracts
/tests/ - Comprehensive test suite
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

### 3.3. Sovereign Autonomous Business (SAXAAP) Model

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

### 4.2. SAXAAP Business Features

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
  - $C_{base}$ is the base cost of a contract call.
  - $C_{map\_read}$ is the cost of reading from the `vesting-schedules` map.
  - $C_{arithmetic}$ is the cost of the vesting calculation.
  - $C_{transfer}$ is the cost of the `stx-transfer?` call.
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

### 4.4. Integration Requirements

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
- **DEX Factory**: `contracts/dex/dex-factory.clar` implemented with multi-pool type support.
- **Multi-Hop Router V3**: `contracts/dex/multi-hop-router-v3.clar` implemented with atomic path execution.
- **MEV Protection**: `contracts/security/mev-protector.clar` enhanced with commit-reveal validation and a batch auction system.
- **Math Libraries**: `contracts/math/math-lib-concentrated.clar` implemented with geometric series math (Uniswap V3 style).
- **Oracle System**: `contracts/dex/oracle-aggregator-v2.clar` enhanced with TWAP, manipulation detection, and circuit breaker integration.
- **Yield Optimizer**: `contracts/yield/yield-optimizer.clar` enhanced with strategy selection, risk scoring, performance tracking, and auto-compounding capabilities.
- **Enterprise and Compliance**: `contracts/enterprise/enterprise-api.clar` and `contracts/compliance/compliance-hooks.clar` created to support institutional clients.
- **Performance and Migration**: `contracts/performance/performance-optimizer.clar`, `contracts/migration/legacy-adapter.clar`, and `contracts/migration/migration-manager.clar` created to support performance monitoring and data migration.
- **Testing**: Added unit tests for concentrated liquidity in `tests/dex/concentrated-liquidity.test.ts`.

### Resolved Issues

- **Test Environment**: Fixed a race condition in `tests/setup-test-env.ts` by replacing the `beforeAll` hook with a `globalSetup` file (`tests/global-setup.ts`) to ensure `initSimnet()` completes before tests run.
- **Compilation Fixes**: Resolved circular dependencies and missing entries in `Clarinet.toml`.
- **Trait Alignment**: Corrected `office-job-trait` implementation in `agent-treasury` and `agent-risk`.
- **Syntax Errors**: Fixed `fold` argument order in `admin-facade` and contract calls in `proposal-executor`.
- **Version Compatibility**: Updated Clarity versions for `dex-factory-v2` and `math-lib-concentrated`.
- **Partial Test Environment Fix**: Removed a conflicting legacy test setup file (`tests/vitest.setup.ts`) and corrected syntax errors related to authorization checks in core contracts (`admin-facade.clar`, `conxian-protocol.clar`). **Note:** The test suite remains non-functional, crashing with a parser error (`Tried to close list which isn't open`) during initialization. This prevented full verification of the fixes. Further investigation into the `Clarinet.toml` configuration and contract loading order is required.
- **Test Environment Stability**: Confirmed the Vitest runner is functional by creating a `tests/sanity.test.ts`. The root cause of the test suite failure is a `CircularReference` error in the `Clarinet.toml` dependency graph, which tooling was unable to resolve.
- **`Clarinet.toml` `CircularReference` Fix**: Manually remediated the `Clarinet.toml` file to break a circular dependency loop between `dimensional-engine`, `position-manager`, and `risk-manager`. This resolved the test suite's initialization crash.

### Pending Action Items

- **Testing**: Expand test coverage for new components.
- **Deployment**: Verify all contracts on testnet.

## 12. Recovery Registry (BOLT ⚡ Initiative)

This section logs all files isolated during the Level 0 Root Stabilization phase. The goal is to create a clear record of stabilization actions and prevent knowledge decay.

| File Path | Reason for Isolation | Required Fix |
| :--- | :--- | :--- |
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
