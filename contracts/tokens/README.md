---
layout: default
title: Token Module
permalink: /modules/tokens/
---

# Token Module

## Overview

The Token Module manages the lifecycle and economics of the Conxian ecosystem's specialized assets. It implements a 5-token system mapped to specialized governance councils.

## Core Assets

1. **CXD (Conxian Dividend)**: The primary revenue-bearing token. Receives 60% of protocol revenue.
2. **CXVG (Conxian Voting & Governance)**: Strategic council token for Annual General Meetings (AGM).
3. **CXS (Conxian Staking)**: Specialized for staking and yield parameter governance.
4. **CXTR (Conxian Treasury)**: Specialized for capital allocation and treasury management.
5. **CXLP (Conxian Liquidity Position)**: Represents liquidity positions, implemented as SIP-009 NFTs.

## Core Contracts

### `cxd-token.clar`
The primary SIP-010 token for the protocol. Implements supply caps and emission controls.

### `cxlp-position-nft.clar`
SIP-009 compliant NFT representing a user's liquidity position and accumulated fees.

## Integration Examples

### Checking CXD Balance
```clarity
(contract-call? .cxd-token get-balance tx-sender)
```

## Status
**Aligned**: All tokens are SIP-standard compliant and integrated with the protocol's 60/20/20 fiscal policy.
