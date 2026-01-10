# Conxian Protocol Architecture

This document provides a comprehensive overview of the Conxian Protocol's architecture, including its core design
patterns, component breakdown, and security model.

**Last Updated**: January 2026

## 1. Architectural Principles

The Conxian Protocol is engineered with a modern, modular architecture designed to meet the demands of both retail
and institutional DeFi. Our architectural philosophy is centered on three core principles:

- **Security**: Prioritizing the safety of user funds through battle-tested, clear, and auditable patterns.
- **Maintainability**: Ensuring the long-term health and scalability of the protocol by separating concerns and
  creating a clean, understandable codebase.
- **Extensibility**: Building a flexible foundation that allows for the seamless addition of new features and modules
  without compromising the stability of the core system.
- **Bitcoin-Native**: Leveraging Stacks' Bitcoin anchoring for security and finality, with a particular focus on
  sBTC integration.

## 2. The Facade Pattern

The Conxian Protocol is a strict and consistent implementation of the **Facade Pattern**. This pattern governs the
structure and interaction of all core modules within the system.

### 2.1 How It Works

For each major piece of functionality (e.g., Core, DEX, Lending), there is a single, on-chain entry point contract
known as a **facade**.

- **User Interaction**: All user-facing calls and all interactions from other contracts are directed exclusively to
  these facade contracts.
- **Delegated Logic**: Facade contracts contain minimal business logic. Their primary responsibility is to perform
  input validation and securely delegate work to specialized, single-responsibility **manager contracts**.
- **Trait-Driven Interfaces**: Connections between facades and manager contracts are defined by standardized
  **traits**, ensuring predictable and secure communication.

### 2.2 Control Flow Example (Core Module)

```text
[User] -> [dimensional-engine.clar] (Facade)
    |
    |-- (open-position via dimensional-trait) --> [position-manager.clar]
    |-- (deposit-funds via collateral-manager-trait) --> [collateral-manager.clar]
    |-- (check-position-health via risk-manager-trait) --> [risk-manager.clar]
```

### 2.3 Benefits

- **Enhanced Security**: Reduced attack surface; audits can focus on well-defined facades.
- **Improved Maintainability**: Separation of concerns makes the system easier to debug and upgrade.
- **Increased Clarity**: Provides a clear logical map of the system.

## 3. The Protocol Coordinator: `conxian-protocol.clar`

The Protocol Coordinator is the central nervous system of the protocol.

- **Emergency Pause**: Implements a global `emergency-paused` flag.
- **Contract Registry**: Maintains a registry of authorized contracts.
- **Protocol-Wide Configuration**: Manages global parameters (fee rates, collateral ratios).

All module facades check the `is-protocol-paused` status from the Coordinator before executing state-changing logic.

## 4. High-Level System Diagram

```text
+----------------------------------------------------------------------------------+
|                                Conxian Protocol                                  |
|                                                                                  |
|    +--------------------------------------------------------------------------+  |
|    |                        Protocol Coordinator                              |  |
|    |                       (conxian-protocol.clar)                              |  |
|    +----------------------------------^----------------------------------------+  |
|                                       |                                          |
|    +-----------------+                |                 +-----------------+      |
|    |   Core Module   |----------------+-----------------|   DEX Module    |      |
|    |    (Facade)     |                |                 |    (Facade)     |      |
|    +-------+---------+      +---------+--------+        +--------+--------+      |
|            |              |  Lending Module  |                 |               |
|            |              |     (Facade)     |                 |               |
|    +-------v---------+      +------------------+        +--------v--------+      |
|    | Manager         |                                  | Manager         |      |
|    | Contracts       |      +---------------------+     | Contracts       |      |
|    +-----------------+      |  Governance Module  |     +-----------------+      |
|                             |       (Facade)      |                            |
|    +----------------------+ +----------+----------+     +----------------------+ |
|    |  Enterprise Module   |            |               |  Manager Contracts   | |
|    |  (Facade - Target)   |            |               +----------------------+ |
|    +----------+-----------+ +----------v----------+                            |
|               |            | Manager Contracts   |                            |
|    +----------v-----------+ +---------------------+                            |
|    | Manager Contracts    |                                                  |
|    +----------------------+                                                  |
|                                                                                  |
+----------------------------------------------------------------------------------+
```

## 5. Core Contract Modules

The protocol is organized into specialized modules within the `contracts` directory.

### Core Modules

- **`core`**: Manages the core logic of the protocol. It includes the `dimensional-engine.clar` facade for user interactions and the `conxian-protocol.clar` contract, which acts as the central protocol coordinator, managing a system-wide emergency pause and a registry of authorized contracts.
- **`dex`**: A decentralized exchange module. The current implementation provides a basic single-pool swap router (`swap-router.clar`). The target design includes a feature-complete, multi-hop router, which is not yet implemented.
- **`governance`**: Proposal and voting system, including the `conxian-operations-engine.clar` (Automated Operations Seat).
- **`lending`**: A placeholder for a future multi-asset lending and borrowing system. This module is not yet implemented.

### Supporting Modules

- **`access`**: Role-based access control.
- **`audit-registry`**: Security and audit data registry.
- **`automation`**: Keeper and task automation.
- **`enterprise`**: Institutional frameworks (Compliance, Advanced Orders).
- **`oracle`**: Price feed aggregation.
- **`sbtc`**: Native sBTC integration (BTC Adapter, DLC Manager).
- **`security`**: Circuit breakers, MEV protection.
- **`tokens`**: Native tokens (CXD, CXS, CXLP, CXTR, CXVG).
- **`traits`**: Modular trait system (15 core traits).
- **`vaults`**: Asset management vaults.

## 6. Security Architecture

- **Circuit Breakers**: Emergency pause mechanism for extreme conditions.
- **MEV Protection**: Batch auctions and commit-reveal schemes.
- **Access Controls**: Role-based permissions for sensitive functions.
- **Invariant Monitoring**: Automated monitoring of key protocol health metrics.
- **Loan & Liquidity Protection**: NFT-based insurance and health-factor monitoring.

## 7. Nakamoto Compliance (Architecture Goals)

- **Faster Block Times**: Logic adapted for 5-second blocks (avoiding short-term `block-height` dependencies).
- **Native sBTC**: Full integration with the decentralized sBTC bridge.
- **Trustless Bitcoin State**: Usage of `clarity-bitcoin` for on-chain verification.

For deployment plans, refer to `Clarinet.toml` and `deployments/`.
