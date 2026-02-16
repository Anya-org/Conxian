---
layout: default
title: Token Module
permalink: /modules/tokens/
---

# Token Module

## Overview

The Token Module manages the lifecycle and economics of the Conxian ecosystem's specialized assets. It implements a **5-token system** mapped to specialized governance councils.

## Core Assets

1. **CXD (Conxian Dividend)**: The primary revenue-bearing token. Receives 60% of protocol revenue. Used for staking.
2. **CXVG (Conxian Voting & Governance)**: Strategic council token for Annual General Meetings (AGM). Enforces "Clean-Hands" compliance.
3. **CXS (Conxian Staking)**: Specialized for staking and yield parameter governance.
4. **CXTR (Conxian Treasury)**: Specialized for capital allocation and treasury management.
5. **CXLP (Conxian Liquidity Position)**: Represents liquidity positions in the DEX, implemented as SIP-009 NFTs.

## Core Contracts

### SIP-010 Tokens (Fungible)

-   **`cxd-token.clar`**: The dividend token. Implements supply caps and emission controls. **Authorized Minters**: Must include `.ops-engine` to enable automated keeper rewards via `trigger-epoch-update`.
-   **`cxvg-token.clar`**: The strategic governance token. Integrated with the `regulatory-adapter`.
-   **`cxs-token.clar`**: Staking governance token.
-   **`cxtr-token.clar`**: Treasury governance token.
-   **`cxlp-token.clar`**: Liquidity pool fungible token.

### SIP-009 Tokens (Non-Fungible)

-   **`cxlp-position-nft.clar`**: NFT representing a specific user's liquidity position and accumulated fees in concentrated liquidity pools.

### Orchestration

-   **`token-system-coordinator.clar`**: Ensures consistency across the 5-token ecosystem and manages multi-token operations.

## Integration Examples

### Checking CXD Balance
```clarity
(contract-call? .cxd-token get-balance tx-sender)
```

### Checking Strategic Voting Power
```clarity
(contract-call? .cxvg-token get-balance tx-sender)
```

## Status
**Aligned**: All tokens are SIP-standard compliant and integrated with the protocol's 60/20/20 fiscal policy. The 5-token model is fully implemented and mapped to the respective governance councils.
