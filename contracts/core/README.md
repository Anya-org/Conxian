# Core Module

## Overview (Explanation)
The Core module is the central nervous system of the Conxian Protocol. It manages the global protocol state, module registration, administrative access control, and the "Dimensional Engine" which orchestrates complex DeFi operations. It ensures that all protocol actions adhere to the SAXaaP manifesto: "Code is Law, Logic is Sovereign."

## Architecture (Explanation)
Following the Hexagonal Architecture pattern, the Core module separates its executive logic (Engines) from its storage and management logic (Managers).
- **Ports**: Defined via traits in `contracts/traits/core-traits.clar`.
- **Adapters**: Concrete implementations like `dimensional-engine.clar` which interface between users and internal managers.
- **Core State**: Managed primarily in `conxian-protocol.clar`, which acts as the registry for all other modules.

## Core Contracts (Reference)

### `conxian-protocol.clar`
The root state contract and module registry for the entire protocol.

| Function | Signature | Description |
|----------|-----------|-------------|
| `set-paused` | `(set-paused (new-paused bool))` | Toggles the global protocol pause state. Admin only. |
| `get-protocol-status` | `(get-protocol-status)` | Returns global status including compliance, pause state, and current tenure-id. |
| `get-protocol-admin` | `(get-protocol-admin)` | Returns the principal that is currently the owner/administrator of the protocol registry. |
| `is-paused` | `(is-paused)` | Returns whether the protocol is currently in a paused state. |

### `dimensional-engine.clar`
The primary facade for multi-dimensional position management, collateral, and risk.

| Function | Signature | Description |
|----------|-----------|-------------|
| `open-position` | `(open-position (manager <position-manager-trait>) (token principal) (amount uint) (leverage uint) (long bool) (slippage-limit (optional uint)) (metadata (optional (string-utf8 1024))))` | Opens a leveraged position via the specified manager. |
| `close-position` | `(close-position (manager <position-manager-trait>) (position-id uint) (token principal) (slippage-limit (optional uint)))` | Closes an existing position and settles collateral via the specified manager. |
| `liquidate-position` | `(liquidate-position (risk-manager <risk-manager-trait>) (position-id uint))` | Forces closure of an undercollateralized position via the risk manager. |
| `check-position-health` | `(check-position-health (risk-manager <risk-manager-trait>) (position-id uint))` | Returns the health factor for a specific position via the risk manager. |
| `deposit-funds` | `(deposit-funds (collateral-manager <collateral-manager-trait>) (amount uint) (token-trait <sip-010-trait>))` | Deposits funds into a specific collateral manager. |
| `withdraw-funds` | `(withdraw-funds (collateral-manager <collateral-manager-trait>) (amount uint) (token-trait <sip-010-trait>))` | Withdraws funds from a specific collateral manager. |

### `economic-policy-engine.clar`
Automated monetary policy and parameter adjustment system.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-current-interest-rate` | `(get-current-interest-rate)` | Returns the current system-wide interest rate (e.g., u500 for 5%). |
| `get-reserve-factor` | `(get-reserve-factor)` | Returns the system-wide reserve factor (e.g., u1000 for 10%). |
| `get-revenue-distributor` | `(get-revenue-distributor)` | Returns the principal of the active revenue distributor. |

## Integration Examples (How-to)

### Checking Protocol Compliance
Before executing any state-changing user actions, external modules should verify protocol health:
```clarity
(let ((status (unwrap! (contract-call? .conxian-protocol get-protocol-status) (err u999))))
  (asserts! (get compliant status) (err u5001))
  (asserts! (not (get paused status)) (err u1001))
)
```

### Opening a Position via the Facade
To open a position, use the `dimensional-engine` which handles the coordination between the position manager and the risk engine:
```clarity
(contract-call? .dimensional-engine open-position
  .position-manager
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.cxd-token
  u1000000
  u200 ;; 2x Leverage
  true ;; Long
  none ;; No slippage limit
  none ;; No metadata
)
```

### Subscribing to Economic Updates
Users can pay a fee to access premium monetary features:
```clarity
(contract-call? .economic-policy-engine subscribe)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/core`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal Architecture, 60/20/20 Revenue Split
