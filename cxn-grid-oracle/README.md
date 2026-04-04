# cxn-grid-oracle (Grid Intelligence & Orchestration)

> Current workspace release: **v1.8.2** (see [`CHANGELOG.md`](../CHANGELOG.md))

The cxn-grid-oracle module handles agnostic demand-response routing and energy orchestration for the Conxian ecosystem.

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
