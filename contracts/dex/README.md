---
layout: default
title: DEX Module
permalink: /modules/dex/
---

# DEX Module

## Overview

The DEX Module provides a highly efficient and capital-aware decentralized exchange. It is architected to be flexible and extensible, supporting multiple pool types and optimized trading routes. The module separates the concerns of trade execution, pool creation, and liquidity management into distinct, specialized contracts.

## Architecture: Multi-Hop Router

The current implementation of the DEX module uses an advanced execution facade, `multi-hop-router-v3.clar`, which provides a single entry point for complex swap operations. This contract can interact with multiple liquidity pools to execute trades across a predefined path.

### Control Flow Diagram

```mermaid
graph TD
    A[User] -- swap-exact-tokens-for-tokens --> B{multi-hop-router-v3.clar};
    B -- 1. swap --> C[Pool 1];
    B -- 2. swap --> D[Pool 2];
    B -- 3. swap --> E[Pool 3];
```

## Core Contracts

### Execution Facade

-   **`multi-hop-router-v3.clar`**: The **facade** for trade execution. It provides an interface for performing swaps across multiple liquidity pools in a single atomic transaction.

### Pool Implementation

-   **`concentrated-liquidity-pool.clar`**: The primary AMM for volatile asset pairs, allowing for greater capital efficiency by enabling liquidity providers to concentrate their capital within specific price ranges.
-   **`stable-swap-pool.clar`**: An AMM optimized for stablecoin swaps, using a different curve to minimize slippage.
-   **`weighted-swap-pool.clar`**: An AMM that allows for pools with more than two assets and custom weightings.

### Factories and Registries

-   **`dex-factory-v2.clar`**: A factory contract for creating new liquidity pools.
-   **`pool-registry.clar`**: A registry of all active liquidity pools.

## Public Functions (`multi-hop-router-v3.clar`)

-   `swap-exact-tokens-for-tokens(amount-in uint, amount-out-min uint, pools (list 4 <swap-pool-trait>), tokens (list 5 <sip-010-trait>))`: Executes a multi-hop swap for an exact input amount.

## Status

**Under Review**: The contracts in this module are currently undergoing a comprehensive review. While the core swapping functionality in `multi-hop-router-v3.clar` is stable, the surrounding factory and registry contracts are being refined to ensure full alignment with the protocol's modular architecture. These contracts are not yet considered production-ready.
