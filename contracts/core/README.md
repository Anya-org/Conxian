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
| `register-module` | `(register-module (name (string-ascii 32)) (contract principal))` | Registers or updates a functional module (e.g., "dex", "lending"). |
| `get-module` | `(get-module (name (string-ascii 32)))` | Returns the contract principal and active status for a given module name. |
| `get-protocol-status` | `(get-protocol-status)` | Returns global status including compliance, pause state, and current tenure-id. |

### `dimensional-engine.clar`
The primary facade for multi-dimensional position management, collateral, and risk.

| Function | Signature | Description |
|----------|-----------|-------------|
| `open-position` | `(open-position (manager <position-manager-trait>) (token principal) (amount uint) (leverage uint) (long bool) (slippage-limit (optional uint)) (metadata (optional (string-utf8 1024))))` | Opens a leveraged position via the specified manager. |
| `close-position` | `(close-position (manager <position-manager-trait>) (position-id uint))` | Closes an existing position and settles collateral. |
| `liquidate-position` | `(liquidate-position (manager <position-manager-trait>) (position-id uint))` | Forces closure of an undercollateralized position. |
| `check-position-health` | `(check-position-health (risk <risk-manager-trait>) (position-id uint))` | returns the health factor for a specific position. |

### `economic-policy-engine.clar`
Automated monetary policy and parameter adjustment system.

| Function | Signature | Description |
|----------|-----------|-------------|
| `update-market-parameters` | `(update-market-parameters (asset principal) (new-utilization uint) (price-volatility uint))` | Updates interest rates and collateral factors for a specific asset. |
| `update-price-feed` | `(update-price-feed (asset principal) (price uint) (confidence uint))` | Records a new price for an asset. |
| `subscribe` | `(subscribe)` | Activates a user subscription for access to advanced monetary functions. |
| `auto-adjust-parameters` | `(auto-adjust-parameters (asset principal))` | Automatically triggers a parameter update based on latest price data. |

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| `u1000` | `ERR_UNAUTHORIZED` | Caller is not authorized for this operation. |
| `u1001` | `ERR_PAUSED` | Operation rejected because the protocol is paused. |
| `u5000` | `ERR_CONTRACT_PAUSED` | Specific contract is paused. |
| `u5001` | `ERR_NON_COMPLIANT` | Caller or operation does not meet compliance requirements. |
| `u1006` | `ERR_NO_SUBSCRIPTION` | User does not have an active subscription for this feature. |

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
