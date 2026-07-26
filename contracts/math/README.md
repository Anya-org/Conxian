# Math Module

## Overview (Explanation)
The Math module provides high-precision mathematical utilities for the Conxian Protocol. It handles complex calculations for concentrated liquidity ticks, bonding curves, and risk scores, ensuring deterministic results across all Stacks nodes.

## Architecture (Explanation)
The module is a stateless utility layer:
- **Concentrated Math**: `concentrated-math.clar` provides bounded deterministic tick/price approximations and amount-delta previews for the DEX foundation.
- **Concentrated Math V2**: `concentrated-math-v2.clar` defines the bounded V2 fixed-point model used by the canonical V2 pool.
- **Utilities**: `math-utilities.clar` provides standard fixed-point arithmetic (MulDiv, Power) and scaling functions.

## Core Contracts (Reference)

### `concentrated-math.clar`
Math for tick-based liquidity.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-sqrt-ratio-at-tick` | `(tick int)` | Legacy ABI-shape wrapper; delegates to the bounded checked conversion and returns `u0` outside execution bounds. |
| `get-sqrt-ratio-at-tick-checked` | `(tick int)` | Checked conversion limited to execution ticks -10,000 through 10,000. |
| `get-tick-at-sqrt-ratio` | `(sqrt-price-x96 uint)` | Legacy ABI-shape wrapper; returns tick `0` for invalid input. The parameter name is retained for ABI compatibility but values use the 1e12 scale, not Q96. |
| `get-tick-at-sqrt-ratio-checked` | `(sqrt-price uint)` | Checked floor-to-tick inverse within the supported price range: returns the greatest supported tick whose bounded model price is less than or equal to the input. |
| `get-amount0-delta-down` / `get-amount0-delta-up` | `(sqrt-price-a uint) (sqrt-price-b uint) (liquidity uint)` | Bounded amount0 approximation with explicit floor/ceiling semantics. |
| `get-amount1-delta-down` / `get-amount1-delta-up` | `(sqrt-price-a uint) (sqrt-price-b uint) (liquidity uint)` | Bounded amount1 approximation with explicit floor/ceiling semantics. |
| `get-amount0-delta` / `get-amount1-delta` | legacy signatures | Legacy ABI-shape wrappers that round down and return `u0` for invalid input. |
| `is-valid-tick` | `(tick int)` | Check if tick is valid. |
| `is-supported-execution-tick` | `(tick int)` | Check the narrower range supported by the current bounded approximation. |
| `get-min-tick` | `()` | Get MIN_TICK. |
| `get-max-tick` | `()` | Get MAX_TICK. |

### `concentrated-math-v2.clar`

Canonical math for `concentrated-liquidity-pool-v2.clar`. It uses a fixed `1e12` sqrt-price scale and a bounded linear tick grid. It is deliberately not a Uniswap logarithmic-tick implementation and must not be described as one. The contract provides bounded tick/price conversion, principal deltas, liquidity derivation, exact-input swap steps, and checked arithmetic for V2 custody/accounting.

See the [CLP V2 executable model](../../docs/CLP_V2_EXECUTABLE_MODEL.md) for the exact formulas, rounding directions, and bounds.

### `math-utilities.clar`
Fixed-point arithmetic.

| Function | Signature | Description |
|----------|-----------|-------------|
| `stub-func` | `()` | A stub function for math utility testing. |

### `exponentiation.clar`
Power calculations.

| Function | Signature | Description |
|----------|-----------|-------------|
| `calc-pow` | `(base uint) (exponent uint)` | Calculate the power of a base to an exponent. |

## Integration Examples (How-to)

### Scaling Values
To scale a value by a precision factor:
```clarity
(contract-call? .math-utilities mul-div u100 u100000000 u100) ;; Identity scale
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/math`

## Precision and scope

- Sqrt prices use a decimal fixed-point scale of `1e12`; legacy `x96` argument
  names do not indicate Q96 values.
- Tick conversion is a deterministic bounded **linear approximation**, not
  exact CLMM or Uniswap V3 tick math.
- Checked amount helpers validate sqrt-price and liquidity limits before
  multiplication, keeping intermediates within Clarity `uint128`.
- Raw wrappers preserve only their legacy ABI return shapes, not historical
  behavior. Their invalid-input fallbacks can be indistinguishable from valid
  zero results and must never be used for settlement.
- Checked response APIs are the only execution-facing surface.
- This module is a Phase 1 preview foundation, not exact production
  concentrated-liquidity math.
