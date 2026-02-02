---
layout: default
title: Yield Module
permalink: /modules/yield/
---

# Yield Module

## Overview

The Yield Module provides a set of contracts for optimizing yield generation and automating yield-related tasks. This module includes implementations for automated strategy selection, cross-protocol integration, and auto-compounding.

## Core Contracts

### `yield-optimizer.clar`

This contract analyzes various yield-generating strategies and rebalances funds to achieve the optimal annual percentage yield (APY). It includes functions for:

* Strategy selection based on risk tolerance and yield targets
* Performance tracking and strategy analytics
* Risk-adjusted optimization with real-time monitoring

### `auto-compounder.clar`

This contract automates the process of compounding yield for connected vaults. It includes functions for:

* Optimized compounding frequency
* Cross-protocol integration for maximum yield opportunities

## Status

**Aligned**: The Yield module is fully operational, featuring the `cxd-staking` engine and automated yield optimizers that enforce the 60% revenue distribution policy.
