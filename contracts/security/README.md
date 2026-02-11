---
layout: default
title: Security Module
permalink: /modules/security/
---

# Security Module

## Overview

The Security Module provides specialized, single-responsibility contracts designed to protect the Conxian Protocol. It handles MEV protection, emergency circuit breakers, and rate limiting.

## Core Contracts

### Threat Mitigation

- **`mev-protector.clar`**: Implements a commit-reveal scheme for DEX operations to prevent front-running and sandwich attacks.
- **`rate-limiter.clar`**: Enforces window-based operation limits to prevent rapid-fire exploits.

### Emergency Controls

- **`circuit-breaker.clar`**: Allows authorized roles to pause critical functions during black swan events.
- **`enhanced-circuit-breaker.clar`**: Provides more granular control over protocol-wide vs module-specific pauses.

### Financial Integrity

- **`proof-of-reserves.clar`**: Mechanism for transparently verifying protocol collateral reserves via multi-attestor proofs.
- **`conxian-insurance-fund.clar`**: The protocol's safety net for covering bad debt or systemic failures.

## Integration

Security primitives are integrated across the protocol:
- `oracle-aggregator.clar` (in `oracle/`) uses circuit breakers for price deviation guards.
- `swap-router.clar` (in `dex/`) integrates with the `mev-protector`.

## Status

**Aligned**: The Security module provides multi-layered protection including the `circuit-breaker`, `mev-protector`, and `proof-of-reserves`.
