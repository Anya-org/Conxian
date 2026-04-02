# Fiscal Vault Oracle

> Current workspace release: **v1.8.2** (see [`CHANGELOG.md`](../CHANGELOG.md))

The **Fiscal Vault Oracle** is the autonomous financial engine of the Conxian Business Operations System (BOS). It powers the **OpenClaw** engine, which manages the Bitcoin treasury and debt issuance with hardware-attested security.

## Purpose

- **Treasury Rebalancing**: Automated rebalancing of sBTC yield against institutional LSEG pricing.
- **Debt Issuance**: Orchestrating Bitcoin-native DLC Bonds and settlement.
- **State Persistence**: Committing regulatory-shielded state to the global BOS state machine.

## Key Components

- **OpenClaw Engine**: TEE-enclosed execution environment for financial logic.
- **[BOS Integration Map](./BOS_INTEGRATION_MAP.md)**: Detailed mapping of state transitions and triggers.
- **[Bitcoin Bond Specification](./BITCOIN_BOND_DLC.json)**: JSON schema for DLC-based debt instruments.

## Guardrails

- **50bps Pricing Constraint**: Rebalancing logic must remain within 50bps of institutional data.
- **144-Block Time-Lock**: All debt issuance state changes require Bitcoin-level finality.

## Governance

This module is part of the Conxian Sovereign Autonomous Business (SAB).

See [`GOVERNANCE.md`](../GOVERNANCE.md) for CONTRIBUTING, SECURITY, and LICENSE.

---
🛡️ **Sovereign Autonomous Business (SAB)**. © 2026 Conxian-Labs. Powered by Bitcoin.
