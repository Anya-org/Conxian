# Conxian Metric Specifications & Data Contracts (v1.0)

## Overview
This document defines the execution-ready specifications for the five core variables of the Conxian Unified Theory ($C_R, O_C, V_X, A_S, N_E$). These metrics are used to gate project progression and evaluate autonomous scale.

---

## 1. $C_R$ (Cost of Reproduction)
**Definition**: The structural moat and difficulty of replicating the protocol's value.
- **Formula**: $C_R = \sum(Arch\_Complexity + IP\_Density + Integration\_Stickiness)$
- **Owner**: Protocol Architect
- **Data Source**: Codebase Audit (CLOC, complexity analysis), Patent/IP Registry, ERP Integration Count.
- **Refresh Cadence**: Quarterly.
- **Data Contract**: Must include count of unique industrial intent solvers and hardware-enclave bound keys.

## 2. $O_C$ (Opportunity Cost)
**Definition**: The manual hours and cognitive bandwidth consumed by the founder/human maintainers.
- **Formula**: $O_C = \sum(Manual\_Ops\_Hours \times Hourly\_Rate) + Context\_Switch\_Tax$
- **Owner**: Operations Manager
- **Data Source**: Linear Time Tracking, Helpdesk logs, manual reporting.
- **Refresh Cadence**: Monthly.
- **Data Contract**: Log all manual state-patching events in `ops-engine.clar`.

## 3. $V_X$ (Execution Velocity)
**Definition**: The speed of code shipment leveraged by agentic AI.
- **Formula**: $V_X = \frac{Milestones\_Completed}{Time\_Elapsed} \times AI\_Leverage\_Factor$
- **Owner**: Engineering Lead (Agentic)
- **Data Source**: Linear API, GitHub Commit Frequency.
- **Refresh Cadence**: Weekly.
- **Data Contract**: Track Jules/Windsurf/MCP tool utilization in commit metadata.

## 4. $A_S$ (System Autonomy)
**Definition**: The percentage of protocol operations handled programmatically without human intervention.
- **Formula**: $A_S = \frac{Automated\_Transactions}{Total\_Transactions} \times 100$
- **Owner**: BOS (Business Operations System)
- **Data Source**: `finance-metrics.clar`, On-chain transaction logs.
- **Refresh Cadence**: Real-time (On-chain).
- **Data Contract**: Pulse check from `ops-engine.clar` must register successful keeper/agent execution.

## 5. $N_E$ (Network Effects)
**Definition**: The value multiplier driven by adoption and liquidity.
- **Formula**: $N_E = log(Active\_Nodes \times TVL \times Enterprise\_Partners)$
- **Owner**: Growth & Ecosystem
- **Data Source**: Supabase Metrics, Stacks Explorer, CRM.
- **Refresh Cadence**: Monthly.
- **Data Contract**: Unified TVL report from `finance-metrics.clar`.

---

## Data Contracts Summary

| Metric | Programmatic Tracking | Refresh | Source |
|---|---|---|---|
| $C_R$ | Partial (Lint/Complexity) | Quarterly | Git/Docs |
| $O_C$ | No | Monthly | Linear/Ops |
| $V_X$ | Yes | Weekly | Linear/GitHub |
| $A_S$ | Yes | Real-time | Stacks (On-chain) |
| $N_E$ | Yes | Monthly | Stacks/CRM |
