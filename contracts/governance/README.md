# Governance Module

## Overview

The Governance Module provides the framework for decentralized decision-making and protocol upgrades. It is designed to be secure, transparent, and flexible, enabling the community to propose, vote on, and execute changes. The module also features the **Conxian Operations Engine**, an automated on-chain agent that participates in governance.

## Architecture: Logic-Rich Facade and Specialized Managers

The Governance Module is architected around a **logic-rich facade**. The `proposal-engine.clar` contract serves as the primary controller, acting as the secure, unified entry point for all governance actions.

Unlike a pure facade, the `proposal-engine.clar` contains significant business logic. It is responsible for enforcing the core rules of the governance process, such as validating proposal timings, checking voting eligibility, and managing the overall state of a proposal. While it orchestrates the process, it delegates specialized tasks to the manager contracts below.

### Control Flow Diagram

```
[User/DAO] -> [proposal-engine.clar] (Logic-Rich Facade & Controller)
    |
    |-- (submit-proposal logic) --> [proposal-registry.clar] (Stores Data)
    |-- (cast-vote logic) --> [voting.clar] (Records Vote)
    |-- (execute-proposal logic) --> [proposal-executor.clar] (Executes Payload)
    |
[Metrics] -> [conxian-operations-engine.clar] -> [proposal-engine.clar] (Automated Vote)
```

## Core Contracts

### Logic-Rich Facade

-   **`proposal-engine.clar`**: The primary **controller** for the governance module. It provides a unified interface for creating proposals, casting votes, and executing the outcomes. It enforces the core business logic of the governance process and delegates specialized tasks like data storage and vote counting to the manager contracts.

### Manager Contracts

-   **`proposal-registry.clar`**: A specialized contract for storing and managing all governance proposals, ensuring data integrity from creation to execution.
-   **`voting.clar`**: Manages the entire voting process, including recording votes, calculating results, and enforcing voting rules.
-   **`proposal-executor.clar`**: A dedicated contract for executing general governance proposals after they have passed.
-   **`upgrade-controller.clar`**: A dedicated contract for managing the execution of sensitive protocol upgrades, incorporating security features like timelocks and multi-signature requirements.

### Automated Governance Agent

-   **`conxian-operations-engine.clar`**: An automated agent that holds a formal seat in the DAO. It consumes on-chain metrics from core protocol modules, aggregates them into policy-constrained votes, and participates in governance by calling the `proposal-engine.clar`.

### Supporting Contracts

-   **`enhanced-governance-nft.clar`**: Implements the NFT-based council and role system, allowing for sophisticated, on-chain representation of governance powers and responsibilities.

## Status

**Under Review**: The contracts in this module are currently undergoing a comprehensive review. While the core governance functionality is implemented, the contracts are not yet considered production-ready and are being hardened to ensure full security and alignment with the protocol's architecture.
