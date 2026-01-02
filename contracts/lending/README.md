# Lending Module

## Overview

The Lending Module provides the core infrastructure for decentralized lending and borrowing within the Conxian Protocol. It is designed as a secure, multi-asset system for managing collateral, algorithmic interest rates, and orderly liquidations.

## Architecture: Logic-Rich Facade and Specialized Managers

The Lending Module is architected around a **logic-rich facade**. The `comprehensive-lending-system.clar` contract serves as the primary controller, acting as the secure, unified entry point for all lending and borrowing operations.

Unlike a pure facade, this contract contains significant business logic. It is responsible for enforcing health factor checks and integrating with the protocol-wide circuit breaker, serving as the primary policy enforcement point for the module. While it orchestrates the core user actions, it delegates specialized tasks to the manager contracts below.

### Control Flow Diagram

```
[User] -> [comprehensive-lending-system.clar] (Logic-Rich Facade & Controller)
    |
    |-- (supply, borrow logic) --> [lending-manager.clar] (Core Logic)
    |-- (health-factor logic) ---^
    |-- (circuit-breaker logic) --^
    |
    |-- (calculate-interest) --> [interest-rate-model.clar]
    |-- (liquidate-loan) --> [liquidation-manager.clar]
    |-- (mint-position) --> [lending-position-nft.clar]
```

## Core Contracts

### Logic-Rich Facade

-   **`comprehensive-lending-system.clar`**: The primary **controller** for the lending module. It enforces business logic such as health factor checks and circuit breaker state, while delegating core operations like supply, borrow, and repay to the `lending-manager`.

### Manager Contracts

-   **`lending-manager.clar`**: The core logic contract for the lending module. It manages all user operations, including deposits, loans, and collateral management.
-   **`interest-rate-model.clar`**: A specialized contract that calculates borrowing interest rates based on market conditions, primarily the utilization rate of a given asset pool.
-   **`liquidation-manager.clar`**: A dedicated contract responsible for managing the entire liquidation process for under-collateralized loans, ensuring the solvency of the protocol.
-   **`lending-position-nft.clar`**: An NFT contract that represents user positions in the lending protocol as unique SIP-009 NFTs. This enhances the composability and transferability of lending and borrowing positions.

## Status

**Under Review**: The contracts in this module are currently under review and are not yet considered production-ready. The core functionality is implemented, including a conservative `get-health-factor` check and optional guardrails (`borrow-checked` and `withdraw-checked`). These metrics are also wired into the Conxian Operations Engine for monitoring, but parameters and cross-module tests are still being hardened.
