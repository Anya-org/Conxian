# AutoVault Stacks DeFi — Design

This document outlines a Clarity-only, fully on-chain DeFi design on Stacks, leveraging Bitcoin anchoring and future BTC bridges (e.g., sBTC) for differentiation.

## Principles

- Minimal, composable core: single vault primitive with predictable accounting
- Parameterized via DAO (fees, caps, allowlists), not code changes
- Safety-first: explicit invariants, post-conditions, and conservative fee/limit defaults
- Sustainable economics: fee capture to protocol reserve, transparent emissions (if any)
- BTC-native differentiation: accept BTC-derivatives (e.g., sBTC) and anchor state to Bitcoin

## Core Contracts

- `vault.clar` (MVP)
  - Per-user balances in internal units (1:1 with deposit token initially)
  - Admin-controlled fee bps for deposit/withdraw
  - Protocol reserve accrual and events
  - Future: SIP-010 integration for real token flows

- `ft.clar` (Next)
  - SIP-010-compliant fungible token for vault share token (if needed)
  - Alternatively, make the vault share a computed value; keep internal accounting only

- `governance.clar` (Later)
  - DAO parameters: fee bps, caps, reserve recipient
  - Emergency pause/withdrawal caps via timelock/multisig

## Differentiation via Bitcoin Layers

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

## Oracles & Pricing (When needed)

- Prefer on-chain TWAPs or signed-oracle updates with minimal cadence
- Price-dependent logic behind caps/limits rather than per-tx dynamic heavy math

## Roadmap

1. Wire SIP-010 token and implement vault token accounting
2. Add Clarinet tests for invariants and fee accounting
3. Governance parameters and protocol reserve withdrawal
4. Devnet profile and deployment scripts
5. sBTC integration and BTC-native strategies

## Planned DEX Subsystem (Design Complete)

The forthcoming DEX adds constant-product automated market maker pools with a factory and router. See `DEX_DESIGN.md` for:

- Pool invariant & fee model (LP + protocol fee split)
- Registry/factory for deterministic pool creation
- Router entrypoints (add/remove liquidity, swap with slippage + deadline guards)
- Embedded cumulative price oracle (TWAP-ready)
- Integration points (treasury buybacks, analytics, automation strategies)

Future enhancements (post initial implementation): multi-hop routing, stable/weighted pools, compliance/circuit-breaker hooks, concentrated liquidity, external oracle contract, and enterprise monitoring extensions.
