# AutoVault Stacks DeFi — Design

This document outlines the live AutoVault on-chain DeFi architecture (current implementation + in-progress subsystems) on Stacks, leveraging Bitcoin anchoring and future BTC bridges (e.g., sBTC) for differentiation.  
For detailed product-level requirements, see `documentation/prd/` (e.g., `VAULT.md`, `DAO_GOVERNANCE.md`, `DEX.md`).

## Principles

- Minimal, composable core: single vault primitive with predictable accounting
- Parameterized via DAO (fees, caps, allowlists), not code changes
- Safety-first: explicit invariants, post-conditions, and conservative fee/limit defaults
- Sustainable economics: fee capture to protocol reserve, transparent emissions (if any)
- BTC-native differentiation: accept BTC-derivatives (e.g., sBTC) and anchor state to Bitcoin


## Core Contracts (See [`STATUS.md`](./STATUS.md) for live list)

- Vault, Treasury, DAO Governance, Timelock, Analytics, Registry
- Token Layer: AVG, AVLP, gov-token, creator-token
- Security: Circuit Breaker, Emergency Pause, Multi-sig Treasury
- Infrastructure: Bounty System, Monitoring, Traits (SIP-010, vault-trait, etc.)

For detailed product requirements, see [`prd/`](./prd/) and for deployment/test status, see [`TESTNET_DEPLOYMENT_VERIFICATION.md`](../TESTNET_DEPLOYMENT_VERIFICATION.md).

## Differentiation via Bitcoin Layers (Planned / Partially Enabled)

- Accept sBTC (or wrapped BTC) as primary collateral asset
- Anchor protocol state to Bitcoin via Stacks settlement
- BTC-native strategies (e.g., BTC LSTs or staking derivatives) when available

## Security & Upgrades

- No code upgrade in-place; deploy new versions and migrate via proxy/dispatcher pattern
- Use Clarity post-conditions for critical user flows
- Use events for all state-changing actions; support off-chain indexing
- Exhaustive input checks; prefer u* operations and explicit bounds

## Gas/Cost Optimization

- Minimize map writes; write only when balances change
- Batch parameter updates; avoid per-user loops
- Use read-only calls for getters and price queries
- Compact events; avoid oversized payloads

## Oracles & Pricing (Planned)

- Prefer on-chain TWAPs or signed-oracle updates with minimal cadence
- Price-dependent logic behind caps/limits rather than per-tx dynamic heavy math

## Roadmap (Delta vs Original Plan)

Completed (v1.1):

1. SIP-010 token integration (governance & auxiliary tokens)
2. Comprehensive test suites (unit, integration, production validation, circuit breaker)
3. Governance + time-weighted voting + timelock + automation
4. Treasury reserve & buyback logic
5. Circuit breaker & enterprise monitoring layer

In Progress / Experimental:

1. DEX Subsystem (AMM core, router, variants, math library)
2. Multi-hop routing & advanced pool types (stable, weighted)

Upcoming:

1. Concentrated liquidity & oracle standardization
2. Strategy adapter + oracle trait finalization
3. sBTC integration & BTC-native strategies
4. Vault v2 trait-conformant wrapper or implementation

## DEX Subsystem (Foundational State)

Implemented (baseline): `dex-factory`, `dex-pool`, `dex-router`, `math-lib`, `pool-trait`.

Prototypes / Experimental: `stable-pool`, `weighted-pool`, `multi-hop-router`, `mock-dex`.

Design References: `DEX_DESIGN.md`, `DEX_IMPLEMENTATION_ROADMAP.md`, `DEX_ECOSYSTEM_BENCHMARK.md`.

Next Steps:

- Harden pool math (precision validation, invariant tests)
- Integrate circuit-breaker hooks (volatility halts)
- Add TWAP oracle surfaces & external oracle trait
- Advance multi-hop path selection and gas profiling

Deferred: Concentrated liquidity, compliance hooks, external oracle aggregator, batch auction / MEV protections.

Updated: Aug 17, 2025
