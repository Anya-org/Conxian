---
layout: default
title: Agents Module
permalink: /modules/agents/
---

# Agents Module

## Overview

The Agents Module contains autonomous contracts that are designed to perform specific, automated tasks within the Conxian Protocol. These "agent" contracts implement the `office-job-trait`, allowing them to be managed and triggered by an automation engine.

## Architecture

This module contains two distinct agent contracts:

-   **`agent-risk.clar`**: Agent-Risk 2.0. Acts as an autonomous risk manager with **Predictive Perception**. It monitors liquidity depth, hashrate volatility, and mempool congestion to determine the protocol's risk state.
-   **`agent-treasury.clar`**: Acts as an autonomous treasury manager implementing **PID Control Theory**. It dynamically rebalances revenue flows between stakers and the insurance fund based on the intelligence provided by `agent-risk`.

## Public Functions

### `agent-risk.clar`

-   `set-predictive-params(new-liquidity-depth uint, new-hash-rate-volatility uint, new-mempool-congestion uint)`: (Admin Only) Updates the predictive perception inputs.
-   `assess-system-risk()`: (Read-Only) Calculates a composite risk score (0-10000).
-   `get-current-risk-state()`: (Read-Only) Returns the current state: "EQUILIBRIUM", "PREEMPTIVE", or "DEFENSIVE".
-   `set-risk-parameters(new-max-leverage uint, new-maintenance-margin uint, new-liquidation-threshold uint)`: (Admin Only) Sets core risk parameters.
-   `set-liquidation-rewards(min-reward uint, max-reward uint)`: (Admin Only) Sets rewards for liquidators.
-   `liquidate(position-id uint)`: Simplified liquidation trigger.
-   `liquidate-position(position-id uint, liquidator principal)`: Full liquidation execution.
-   `assess-position-risk(position-id uint)`: (Read-Only) Returns health factor and risk level for a position.
-   `calculate-liquidation-price(position {entry-price: uint, leverage: uint, is-long: bool})`: (Read-Only) Predicts liquidation price.
-   `check-work-needed()`: Implements `office-job-trait`. Checks for liquidatable positions.
-   `do-work(job-data (buff 2048))`: Implements `office-job-trait`. Executes liquidation.

### `agent-treasury.clar`

-   `check-work-needed()`: Implements `office-job-trait`. Checks if rebalancing is required based on risk score or balance.
-   `do-work(job-data (buff 2048))`: Implements `office-job-trait`. Executes PID-controlled rebalancing of revenue flows via `cxd-treasury`.

## Status
**Aligned**: The Agents module (Staff) is fully integrated with the `office-manager` and Nakamoto-era automation standards. It provides the "Staff" intelligence for the protocol's autonomous fiscal policy.
