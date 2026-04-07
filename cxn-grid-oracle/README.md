# cxn-grid-oracle (Grid Intelligence & Orchestration)

> Current workspace release: **v1.9.0** (see [`CHANGELOG.md`](../CHANGELOG.md))

The cxn-grid-oracle module handles agnostic demand-response routing and energy orchestration for the Conxian ecosystem.

## Purpose

- Define a public-safe input/output schema for grid intelligence signals used by Conxian orchestration.
- Document expected fields and semantics so downstream components can integrate consistently.

## Status

alpha — This module currently provides schema documentation and governance scaffolding; production integrations should treat it as non-stable.

## Universal Oracle Schema

### JSON Input
```json
{
  "current_kw_price": 0.12,
  "forecasted_1hr_price": 0.15,
  "grid_stress_flag": false,
  "current_hash_price": 0.000042
}
```

### JSON Output
```json
{
  "target_state": "NOMINAL",
  "instruction_id": "uuid-v4",
  "timestamp": 123456789
}
```

## Governance

This module is part of the Conxian Sovereign Autonomous Business (SAB).

- [**LICENSE**](./LICENSE) (GPL-3.0-only)
- [**NOTICE**](./NOTICE)
- [**CONTRIBUTING.md**](../CONTRIBUTING.md)
- [**SECURITY.md**](../SECURITY.md)

---
**Sovereign Autonomous Business (SAB)**. © Conxian-Labs. Licensed under GPL-3.0-only. Powered by Bitcoin.
