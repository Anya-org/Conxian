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

-   **`agent-risk.clar`**: Agent-Risk 2.0. Acts as an autonomous risk manager with **Predictive Perception**. It monitors liquidity depth, hashrate volatility, and mempool congestion to determine the protocol's risk state.
-   **`agent-treasury.clar`**: Acts as an autonomous treasury manager implementing **PID Control Theory**. It dynamically rebalances revenue flows between stakers and the insurance fund based on the intelligence provided by `agent-risk`.

## Public Functions

### `agent-risk.clar`

-   `set-predictive-params(liquidity uint, hashrate uint, mempool uint)`: (Admin Only) Updates the predictive perception inputs.
-   `assess-system-risk()`: (Read-Only) Calculates a composite risk score (0-10000).
-   `get-current-risk-state()`: (Read-Only) Returns the current state: "EQUILIBRIUM", "PREEMPTIVE", or "DEFENSIVE".
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
