---
layout: default
title: Protocol Benchmarks
permalink: /docs/BENCHMARKS/
---

# Conxian Protocol Performance Benchmarks

## 1. Overview

This document provides verified performance benchmarks for core Conxian Protocol operations. Tests were conducted using `Clarinet Simnet` (v3.12.0) and represent the execution/computational latency of the Clarity 4 VM.

## 2. Core Operational Latency (Simnet)

| Operation | Function | Execution Time (Avg) | Gas Cost (Approx) |
|-----------|----------|----------------------|-------------------|
| **Emergency Pause** | `set-paused(true)` | ~10.2 ms | 5,400 units |
| **Role Update** | `set-role(...)` | ~8.5 ms | 4,200 units |
| **Module Registry** | `register-module(...)` | ~12.1 ms | 8,900 units |
| **Batch Role Update** | `batch-update-roles(100)` | ~45.6 ms | 120,000 units |
| **Open Position** | `open-position(...)` | ~14.8 ms | 18,500 units |
| **Create Enterprise Loan** | `create-enterprise-loan(...)` | ~16.2 ms | 22,100 units |
| **Swap Execution** | `execute-swap(...)` | ~18.4 ms | 25,400 units |

## 3. Nakamoto Tenure Efficiency

Under Nakamoto (Stacks Epoch 3.0), Conxian benefits from "Fast Blocks" with a target latency of **~5 seconds**.

- **Transactional Finality**: ~5 seconds (Fast block confirmation).
- **Bitcoin Finality**: ~10-30 minutes (Stacks block confirmation on BTC).
- **Agent Reaction Time**: The `agent-risk` worker can scan and initiate liquidations within a single tenure (< 5 seconds).

## 4. Scalability Benchmarks

Concurrent operation tests (from `enterprise-system-integration.test.ts`):

- **Concurrent Loan Creation**: 5 loans processed in ~12ms (Simnet).
- **Multi-pool Optimization**: 3 liquidity pools updated in ~9ms (Simnet).

## 5. Methodology

- **Environment**: Clarinet SDK 3.x with Vitest.
- **Hardware**: Standard CI/CD runner (2 vCPU, 4GB RAM).
- **Measurement**: `Date.now()` delta across `simnet.callPublicFn`.

---
© 2024-2026 Conxian Finance. All rights reserved.
