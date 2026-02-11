---
layout: default
title: Agents Module
permalink: /modules/agents/
---

# Agents Module

## Overview

The Agents Module contains autonomous contracts designed to perform automated tasks within the Conxian Protocol. These "agent" contracts implement the `office-job-trait`, allowing them to be managed and triggered by an automation engine (`ops-engine`).

## Architecture

This module contains two distinct agent contracts:

-   **`agent-risk.clar`**: Agent-Risk 2.0. Acts as an autonomous risk manager with **Predictive Perception**. It monitors liquidity depth, hashrate volatility, and mempool congestion.
-   **`agent-treasury.clar`**: Acts as an autonomous treasury manager implementing the **Fiscal Dam V3**. It dynamically rebalances revenue flows based on intelligence from `agent-risk`.

## Public Functions

### `agent-risk.clar`

-   **`get-cybernetic-intel()`**: (Read-Only) Returns a consolidated state of protocol health, GCR, and PID fees.
-   **`update-pid-rates()`**: (Public) Recalculates the Stability Fee using the PID controller.
-   **`get-current-risk-state()`**: (Read-Only) Returns "EQUILIBRIUM", "DEFENSIVE", or "CRISIS".
-   **`set-risk-parameters(max-leverage, maintenance-margin, threshold)`**: (Admin) Updates core risk parameters.
-   **`calculate-liquidation-price(position)`**: (Read-Only) Predicts liquidation price for a hypothetical position.

### `agent-treasury.clar`

-   **`run-fiscal-strategy()`**: (Public) Triggers autonomous revenue rebalancing (Fiscal Dam).
-   **`calculate-cybernetic-policy()`**: (Read-Only) Returns the target 60/20/20 or adjusted split based on current GCR.

## Status
**Aligned**: The Agents module (Staff) is fully integrated with the `ops-engine` and Nakamoto-era automation standards.
