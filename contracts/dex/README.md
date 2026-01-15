---
layout: default
title: DEX Module
permalink: /modules/dex/
---

# DEX Module

## Overview

The DEX Module provides a highly efficient and capital-aware decentralized exchange. It is architected to be flexible and extensible, supporting multiple pool types and optimized trading routes. The module separates the concerns of trade execution, pool creation, and liquidity management into distinct, specialized contracts.

## Architecture: Simple Execution Facade

The current implementation of the DEX module uses a simple execution facade, `swap-router.clar`, which provides a single entry point for swap operations. This contract directly interacts with liquidity pools to execute trades.

### Control Flow Diagram

```
[User] -> [swap-router.clar] (Execution Facade)
    |
    |-- (swap) --> [concentrated-liquidity-pool.clar]
```

## Core Contracts

### Execution Facade

-   **`swap-router.clar`**: The **facade** for trade execution. It provides a basic interface for performing swaps within a single liquidity pool. The current implementation only supports swaps with `concentrated-liquidity-pool.clar`.

### Pool Implementation

-   **`concentrated-liquidity-pool.clar`**: The primary AMM for volatile asset pairs, allowing for greater capital efficiency by enabling liquidity providers to concentrate their capital within specific price ranges.

### Aspirational Architecture (Not Implemented)

The protocol's target design, as described in the whitepaper, includes a `multi-hop-router-v3.clar` with advanced routing capabilities and support for multiple pool types (stable-swap, weighted). The `multi-hop-router-v3.clar` file is currently a placeholder, and this functionality is not yet implemented.

## Public Functions (`swap-router.clar`)

-   `exact-input-single`: Executes a swap for an exact input amount within a single `concentrated-liquidity-pool`.

## Status

**Under Review**: The contracts in this module are currently undergoing a comprehensive review. While the core swapping functionality in `swap-router.clar` is stable, the surrounding factory and registry contracts are being refined to ensure full alignment with the protocol's modular architecture. These contracts are not yet considered production-ready.
