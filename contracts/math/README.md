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
| `get-sqrt-ratio-at-tick` | `(get-sqrt-ratio-at-tick (tick int))` | Returns the square root of the price ratio for a specific tick. |
| `get-tick-at-sqrt-ratio` | `(get-tick-at-sqrt-ratio (sqrt-ratio-x96 uint))` | Returns the tick index for a given square root ratio. |

### `math-utilities.clar`
Fixed-point arithmetic.

| Function | Signature | Description |
|----------|-----------|-------------|
| `mul-div` | `(mul-div (a uint) (b uint) (c uint))` | Performs `(a * b) / c` with internal 128-bit precision. |

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/math`

## Status (Reference)
- Implementation: Finalized (v1.2.0)
- Audit Status: Internally Verified
- Precision: 128-bit internal
- Standard: Fixed-Point Arithmetic
