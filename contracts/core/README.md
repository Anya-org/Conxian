# Core Module

## Overview (Explanation)
The Core module is the central nervous system of the Conxian Protocol. It manages the global protocol state, module registration, administrative access control, and protocol-wide security. Following the 2026 upgrade, it features an **Enhanced Circuit Breaker** for inter-protocol isolation.

## Architecture (Explanation)
Following the Hexagonal Architecture pattern, the Core module separates its executive logic from its security and heartbeat layers.
- **Executive**: Managed by `conxian-protocol.clar` (Registry).
- **Security**: Orchestrated by `enhanced-circuit-breaker.clar`.
- **Temporal Heartbeat**: Triggered via `ops-engine.clar` for protocol-wide state synchronization.

## Core Contracts (Reference)

### `conxian-protocol.clar`
The root state contract and module registry.

| Function | Signature | Description |
|----------|-----------|-------------|
| `set-paused` | `(set-paused (new-paused bool))` | Toggles the global protocol pause state. |
| `get-protocol-admin` | `(get-protocol-admin)` | Returns the active administrative principal. |

### `enhanced-circuit-breaker.clar`
Multi-tier protocol security and CSF isolation.

| Function | Signature | Description |
|----------|-----------|-------------|
| `toggle-contract-pause` | `(toggle-contract-pause (target principal))` | Pauses a specific protocol module. |
| `toggle-isolation` | `(toggle-isolation (protocol principal))` | Isolate an external CSF protocol to prevent contagion. |
| `is-contract-paused` | `(is-contract-paused (target principal))` | Returns the combined global and local pause state. |

### `ops-engine.clar`
The Apex Heartbeat engine.

| Function | Signature | Description |
|----------|-----------|-------------|
| `trigger-epoch-update` | `(trigger-epoch-update (cxd-token <sip-010-trait>))` | Synchronizes protocol fees and BME epoch updates. |

## Integration Examples (How-to)

### Checking CSF Isolation
Before routing liquidity through an external protocol, the router verifies its isolation status:
```clarity
(let ((isolated (unwrap-panic (contract-call? .enhanced-circuit-breaker is-isolated source))))
  (asserts! (not isolated) (err u504))
)
```

## Testing (How-to)
1. Run system heartbeat tests: `npx vitest run tests/system`
2. Verify isolation logic: `npx vitest run tests/csf-full-system.test.ts`

## Status (Reference)
- Implementation: Apex v1.1.0 (Nakamoto-Aligned)
- Audit Status: Internally Verified (March 2026)
- Standard: Hexagonal Architecture, Sovereign BME Engine
