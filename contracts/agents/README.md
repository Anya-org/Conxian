---
layout: default
title: Agents Module
permalink: /modules/agents/
---

# Agents Module

## Overview

The Agents Module contains autonomous contracts that are designed to perform specific, automated tasks within the Conxian Protocol. These "agent" contracts often implement the `office-job-trait`, allowing them to be managed and triggered by an automation engine.

## Architecture

This module contains two distinct agent contracts:

-   **`agent-risk.clar`**: Acts as an autonomous risk manager. It is responsible for setting risk parameters, managing liquidations, and assessing the health of open positions.
-   **`agent-treasury.clar`**: Acts as an autonomous treasury manager, or "CFO". It is responsible for rebalancing the protocol's funds when certain thresholds are met.

## Public Functions

### `agent-risk.clar`

-   `set-risk-parameters(new-max-leverage uint, new-maintenance-margin uint, new-liquidation-threshold uint)`: (Admin Only) Sets the core risk parameters for the protocol.
-   `set-liquidation-rewards(min-reward uint, max-reward uint)`: (Admin Only) Sets the minimum and maximum rewards for liquidators.
-   `liquidate-position(position-id uint, liquidator principal)`: Liquidates an unhealthy position.
-   `set-insurance-fund(fund principal)`: (Admin Only) Sets the address of the insurance fund.
-   `calculate-liquidation-price(position {entry-price: uint, leverage: uint, is-long: bool})`: (Read-Only) Calculates the liquidation price for a given position.
-   `assess-position-risk(position-id uint)`: (Read-Only) Assesses the risk level of a position and returns its health factor and liquidation price.
-   `vote-on-solvency()`: Placeholder function for future governance interactions.
-   `check-work-needed()`: Implements the `office-job-trait` to check if there are any positions that need to be liquidated.
-   `do-work(job-data (buff 2048))`: Implements the `office-job-trait` to execute the liquidation of a position.

### `agent-treasury.clar`

-   `check-work-needed()`: Implements the `office-job-trait` to check if the treasury balance has exceeded the rebalancing threshold.
-   `do-work(job-data (buff 2048))`: Implements the `office-job-trait` to perform the treasury rebalancing.

## Status
**Aligned**: The Agents module (Staff) is fully integrated with the `office-manager` and Nakamoto-era automation standards.
