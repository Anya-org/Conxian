> **Note:** This document has been updated to reflect the current state of the codebase as of September 2025. It describes a mix of implemented and planned contracts.

# Conxian Stacks DeFi — Design

This document outlines the live Conxian on-chain DeFi architecture (current implementation + in-progress subsystems) on Stacks.
For detailed product-level requirements, see `documentation/prd/`.

## Principles

- Minimal, composable core: single vault primitive with predictable accounting
- Parameterized via DAO (fees, caps, allowlists), not code changes
- Safety-first: explicit invariants, post-conditions, and conservative fee/limit defaults
- Sustainable economics: fee capture to protocol reserve, transparent emissions (if any)
- BTC-native differentiation: accept BTC-derivatives (e.g., sBTC) and anchor state to Bitcoin

## Core Contracts

_**Note:** This section describes the intended architecture. Not all contracts are implemented._

- **Implemented:**
    - `vault.clar` – Share-based accounting, caps, dynamic fees, precision math integration
    - `cxvg-token.clar`, `cxd-token.clar`, `cxlp-token.clar`, `cxtr-token.clar`, `cxs-token.clar` – Token layer & migration logic
    - `protocol-invariant-monitor.clar` - Monitors key invariants and triggers automated protection mechanisms. _(Note: Contains bugs that prevent tests from passing)_
- **Partially Implemented (DEX Subsystem):**
    - `dex-factory.clar`, `dex-pool.clar`, `dex-router.clar`
- **Not Implemented:**
    - `treasury.clar`
    - `dao-governance.clar` / `dao.clar`
    - `timelock.clar`
    - `analytics.clar`
    - `registry.clar`
    - `bounty-system*.clar`
    - `dao-automation.clar`
    - `circuit-breaker.clar`
    - `enterprise-monitoring.clar`

- **Traits & Interfaces (All Implemented):**
    - `vault-trait`, `vault-admin-trait`, `strategy-trait`, `pool-trait`, `sip-010-trait`.

## Differentiation via Bitcoin Layers (Planned / Partially Enabled)

- Accept sBTC (or wrapped BTC) as primary collateral asset
- Anchor protocol state to Bitcoin via Stacks settlement
- BTC-native strategies (e.g., BTC LSTs or staking derivatives) when available

## Security & Upgrades

- No code upgrade in-place; deploy new versions and migrate via proxy/dispatcher pattern
- Use Clarity post-conditions for critical user flows
- Use events for all state-changing actions; support off-chain indexing
- Exhaustive input checks; prefer u* operations and explicit bounds

## Roadmap (Delta vs Original Plan)

Completed (v1.1):

1. SIP-010 token integration (governance & auxiliary tokens)
2. ~~Comprehensive test suites (unit, integration, production validation, circuit breaker)~~ _(Note: Test suite is currently failing)_
3. ~~Governance + time-weighted voting + timelock + automation~~ _(Note: Not implemented)_
4. ~~Treasury reserve & buyback logic~~ _(Note: Not implemented)_
5. ~~Circuit breaker & enterprise monitoring layer~~ _(Note: Not implemented)_

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

Updated: Sep 04, 2025
