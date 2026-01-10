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
    |-- (submit-proposal & cast-vote logic) --> [proposal-registry.clar] (Stores Data & Votes)
    |-- (execute-proposal logic) --> [proposal-executor.clar] (Executes Payload)
    |
[Metrics] -> [conxian-operations-engine.clar] -> [proposal-engine.clar] (Automated Vote)
```

## Core Contracts

### Logic-Rich Facade

-   **`proposal-engine.clar`**: The primary **controller** for the governance module. It provides a unified interface for creating proposals, casting votes, and executing the outcomes. It enforces the core business logic of the governance process and delegates specialized tasks like data storage and vote counting to the manager contracts.

### Manager Contracts

-   **`proposal-registry.clar`**: A specialized contract responsible for both storing proposal data and recording all votes cast against them.
-   **`proposal-executor.clar`**: A dedicated contract for executing general governance proposals after they have passed.
-   **`upgrade-controller.clar`**: A specialized, high-security contract for managing the execution of sensitive protocol upgrades. This contract is independent of the main proposal engine and incorporates additional safety features like timelocks.

### Automated Governance Agent

-   **`conxian-operations-engine.clar`**: An automated agent that holds a formal seat in the DAO. It consumes on-chain metrics from core protocol modules, aggregates them into policy-constrained votes, and participates in governance by calling the `proposal-engine.clar`.

### Supporting Contracts

-   **`enhanced-governance-nft.clar`**: Implements the NFT-based council and role system. It is the source of a voter's "raw" voting power, based on which council seats they hold.
-   **`reputation-engine.clar`**: A supporting contract that adjusts a voter's raw power based on their activity and historical participation. The `proposal-engine.clar` queries this contract to get a "weighted" voting power, which is used to calculate the final vote.

## Status

**Under Review**: The contracts in this module are currently undergoing a comprehensive review. While the core governance functionality is implemented, the contracts are not yet considered production-ready and are being hardened to ensure full security and alignment with the protocol's architecture.
