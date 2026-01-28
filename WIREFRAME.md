# Conxian Finance Protocol - System Wireframes

This document provides visual representations of the Conxian Protocol's core systems, architecture, and user journeys.

## 1. Core Architecture (Multi-Dimensional Facade)

The Conxian Protocol uses a Facade Pattern to separate user interactions from complex backend logic. All positions are represented as **Dimensional Risk Tokens (DRT)**.

```mermaid
graph TD
    User((User/Enterprise)) --> DE{Dimensional Engine<br/>Facade}
    DE --> PM[Position Manager]
    DE --> CM[Collateral Manager]
    DE --> RM[Risk Manager]

    subgraph "Dimensional Risk Assets"
        PM --> DRT[Dimensional Risk Token<br/>SIP-009 NFT]
    end

    subgraph "Monetization"
        User --> EPE[Economic Policy Engine]
        EPE --> RD[Revenue Distributor]
        RD --> SV[Staking Vault - 60%]
        RD --> DT[Dev Treasury - 20%]
        RD --> IV[Insurance Vault - 20%]
    end

    subgraph "Risk & Oracle"
        RM --> OA[Oracle Aggregator]
        RM --> CB[Circuit Breaker]
    end
```

## 2. Revenue Lifecycle (60/20/20 Split)

Every 1 STX subscription fee follows an autonomous distribution path.

```mermaid
sequenceDiagram
    participant U as User
    participant EPE as Economic Policy Engine
    participant RD as Revenue Distributor
    participant V as Vaults (Staking/Dev/Ins)

    U->>EPE: subscribe(1 STX)
    EPE->>RD: stx-transfer(1 STX)
    EPE->>RD: distribute-stx(1 STX)
    Note over RD: 60/20/20 Calculation
    RD->>V: 0.6 STX -> Staking
    RD->>V: 0.2 STX -> Dev
    RD->>V: 0.2 STX -> Insurance
    RD-->>U: Subscription Active
```

## 3. Autonomous "Office Worker" Liquidation Loop

The CRO (Agent Risk) monitors system solvency and pays workers for executing liquidations.

```mermaid
graph LR
    K[Keeper/Worker] -- 1. check-work-needed --> AR[Agent Risk - CRO]
    AR -- 2. scan positions --> Core[Dimensional Core]
    K -- 3. do-work(position-id) --> AR
    AR -- 4. liquidate-position --> Core
    Core -- 5. burn DRT --> NFT[Position NFT]
    AR -- 6. payout(5 uSTX) --> OM[Office Manager]
    OM -- 7. transfer reward --> K
```

## 4. Enterprise Advanced Order Flow (TWAP)

Large institutional orders are broken down into time-weighted intervals.

```mermaid
sequenceDiagram
    participant E as Enterprise Client
    participant AOM as Advanced Order Manager Leg
    participant DEX as DEX Router
    participant K as Keeper (Office Worker)

    E->>AOM: place-twap-order(1000 STX, 10 intervals)
    Note over AOM: Escrow 1000 STX
    loop Every N Blocks
        K->>AOM: execute-twap-leg(order-id)
        AOM->>DEX: swap(100 STX)
        AOM->>E: Transfer Output
    end
    AOM-->>E: Order Completed
```

## 5. UI/UX Dashboard Wireframe (Conceptual)

The UI (housed in `conxian_ui`) reflects the "Dimensional" nature of the protocol.

| Navigation | Dimensional Dashboard | System Health |
| :--- | :--- | :--- |
| **Portfolio** | **Active Positions (DRTs)** | **APY**: 12.5% |
| **Trade** | [Position #42] | **Utilization**: 65% |
| **Lending** | Leverage: 5x \| Risk: Low | **Solvency**: 150% |
| **Governance** | [Position #45] | **Nakamoto Status**: Finalized |
| **Settings** | Leverage: 20x \| Risk: HIGH | **Insurance Fund**: 1M STX |

---
*Note: This wireframe is synchronized with the PRD and the current contract implementation.*
