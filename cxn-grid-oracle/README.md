# cxn-grid-oracle (Grid Intelligence & Orchestration)

The cxn-grid-oracle module handles agnostic demand-response routing and energy orchestration.

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
