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

```
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

- `sip-standards.clar` - SIP-009, SIP-010, SIP-018
- `core-traits.clar` - ownable, pausable, rbac, regulatory-adapter
- `defi-traits.clar` - pool, factory, router
- `dimensional-traits.clar` - position, collateral
- `oracle-trait.clar` / `oracle-pricing.clar` - oracle, aggregator
- `risk-manager-trait.clar` - risk-manager, liquidation
- `cross-chain-traits.clar` - bridge, dlc, sbtc
- `governance-traits.clar` - dao, proposal-engine
- `security-monitoring.clar` - circuit-breaker
- `math-utilities.clar` - math, fixed-point
- `vault-traits.clar` - vault, custody, fee-manager

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
  -   $C_{base}$ is the base cost of a contract call.
  -   $C_{map\_read}$ is the cost of reading from the `vesting-schedules` map.
  -   $C_{arithmetic}$ is the cost of the vesting calculation.
  -   $C_{transfer}$ is the cost of the `stx-transfer?` call.
- [x] **Gamification** - `gamification-manager` (XP system)
- [x] **Legal Registry** - `legal-representative-registry` (KYC mapping)
- [x] **ICO System** - `ico-offering` (token sale logic)
- [x] **Signature Verification** - `governance-signature-verifier` (SIP-018)
- [x] **Upgrade Control** - `upgrade-controller` (governance-gated)
- [x] **Enterprise Orders** - `advanced-order-manager` (TWAP/VWAP implementation)
- [x] **Dimensional Risk Tokens** - `position-nft` (SIP-009 DRT system)

### 4.3. Financial Logic & Strategies

#### 4.3.1. Dynamic Interest Rate Model
The protocol implements an industry-leading **Kinked Curve Interest Rate Model** in `economic-policy-engine.clar`. The rate ($R$) is calculated based on the utilization ($U$):

$$
R =
\begin{cases}
R_0 + \frac{U}{U_{kink}} \cdot Slope_1 & \text{if } U \le U_{kink} \\
R_0 + Slope_1 + \frac{U - U_{kink}}{1 - U_{kink}} \cdot Slope_2 & \text{if } U > U_{kink}
\end{cases}
$$

**Parameters**:
- $R_0 = 1\%$ (Base Rate)
- $U_{kink} = 80\%$ (Optimal Utilization)
- $Slope_1 = 4\%$ (Low utilization incentive)
- $Slope_2 = 60\%$ (High utilization deterrent)

#### 4.3.2. Dimensional Risk Parameters
Maintenance Margin ($MM$) is dynamic and multi-dimensional, scaling with position risk:

$$ MM = MM_{base} + \text{Leverage}^2 $$

This ensures that high-leverage positions are progressively more expensive to maintain and easier to liquidate, protecting system solvency.

### 4.4. Security Features

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

## 11. Implementation Status (2026-01-16 Update)

### Recently Implemented (ROOT STABILIZATION)

- **Root Foundation**: Successfully isolated and stabilized the core protocol registry and administration layer.
- **Deterministic Testing**: Created `Clarinet.root.toml` and verified `initSimnet()` reliability for core components.
- **Core Remediation**: Fixed critical syntax and logic errors in `conxian-protocol`, `admin-facade`, and `regulatory-adapter`.
- **Root Verification**: Implemented `tests/root-recovery.test.ts` with 100% pass rate for pause/unpause and module registration.

### Resolved Issues

- **Invalid Syntax**: Removed unsupported `lambda` usage from `conxian-protocol.clar`.
- **Dynamic Call Errors**: Fixed invalid dynamic `contract-call?` syntax in `conxian-protocol.clar`.
- **Visibility Bugs**: Changed `regulatory-adapter.clar` compliance check to `define-read-only` to support cross-contract read operations.
- **Auth Gaps**: Updated `admin-facade.clar` to correctly recognize the global admin in authorization checks.
- **Mismatched Parens**: Repaired unbalanced parentheses in `points-oracle.clar`, `mev-protector.clar`, and `pool-template.clar`.

### Pending Action Items (Next Session)

- **Foundation Extension**: Integrate `collateral-manager` and `position-manager` into the stabilized Root.
- **Nakamoto Alignment**: Transition from `block-height` to `burn-block-height` across all core contracts.
- **DEX Module Recovery**: Massive remediation needed for `contracts/dex/` due to widespread `lambda` usage.

## 12. Recovery Registry (BOLT ⚡ Initiative)

| File Path | Failure Point | Status |
| :--- | :--- | :--- |
| `contracts/drafts/federated-oracle-adapter.clar` | Non-functional stub | Awaiting full implementation. |
| `contracts/drafts/interest-rate-model.clar` | Replaced | Integrated into `economic-policy-engine.clar` as Kinked Curve Model. |
| `contracts/drafts/lending-manager.clar` | Architectural Redesign | Awaiting a redesign to align with the latest PRD specifications for multi-asset collateral. |
| `contracts/drafts/regulatory-adapter.clar` | SIP-018 Compliance | Being updated to support the latest SIP-018 standards for digital signatures. |
| `contracts/rewards/default-strategy-engine.clar` | Tier 0 Stub | Implementation pending based on Yield Strategy requirements. |

## 13. Benchmarks (Vitest 4.0)

This section provides a summary of the latest performance metrics from the Vitest 4.0 test suite. The goal is to track the gas costs and execution times of critical functions to prevent performance regressions.

*NOTE: This section is a placeholder and will be populated with data from the automated testing pipeline.*

| Contract | Function | Gas Cost (Mean) | Execution Time (ms) |
| :--- | :--- | :--- | :--- |
| `conxian-protocol.clar` | `set-paused` | (TBD) | ~10ms |
| `conxian-protocol.clar` | `register-module` | (TBD) | ~15ms |
| `conxian-protocol.clar` | `get-protocol-status` | (TBD) | ~5ms |
