# Math Module

## Overview (Explanation)
The Math module provides high-precision mathematical utilities for the Conxian Protocol. It handles complex calculations for concentrated liquidity ticks, bonding curves, and risk scores, ensuring deterministic results across all Stacks nodes.

## Architecture (Explanation)
The module is a stateless utility layer:
- **Concentrated Math**: `concentrated-math.clar` handles tick-to-price and price-to-tick conversions for the DEX.
- **Utilities**: `math-utilities.clar` provides standard fixed-point arithmetic (MulDiv, Power) and scaling functions.

## Core Contracts (Reference)

### `concentrated-math.clar`
Math for tick-based liquidity.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-sqrt-ratio-at-tick` | `(tick int)` | Returns the square root of the price ratio for a specific tick. |
| `get-tick-at-sqrt-ratio` | `(sqrt-price-x96 uint)` | Returns the tick index for a given square root ratio. |
| `get-amount0-delta` | `(sqrt-price-a-x96 uint) (sqrt-price-b-x96 uint) (liquidity uint)` | Calculate amount0 delta for a given liquidity and price range. |
| `get-amount1-delta` | `(sqrt-price-a-x96 uint) (sqrt-price-b-x96 uint) (liquidity uint)` | Calculate amount1 delta for a given liquidity and price range. |
| `is-valid-tick` | `(tick int)` | Check if tick is valid. |
| `get-min-tick` | `()` | Get MIN_TICK. |
| `get-max-tick` | `()` | Get MAX_TICK. |

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

## Status (Reference)
- Implementation: Finalized (v1.2.0)
- Audit Status: Internally Verified
- Precision: 128-bit internal
- Standard: Fixed-Point Arithmetic
