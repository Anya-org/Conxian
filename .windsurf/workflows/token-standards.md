---
description: Token standards alignment for Conxian dimensional DeFi system
---

# Goal
Provide a clear, actionable standard for which Stacks SIPs Conxian should adopt across fungible tokens, creator assets, governance, liquidity, and identity, with implementation and testing guidelines.

# Decisions
- __SIP-010 (Fungible Tokens)__
  - Use for all fungible assets: governance token(s), LP tokens, bond instruments, fee/reward tokens.
  - Contracts should `impl-trait` the SIP-010 trait and expose: `transfer`, `get-balance`, `get-total-supply`, `get-name`, `get-symbol`, `get-decimals`, optional `get-token-uri`.
  - Implement `get-total-supply` via an internal `total-supply` var updated on mint/burn.
- __SIP-013 (Semi-Fungible Tokens)__
  - Use for creator drops, memberships, or batchable credentials (tiered access, editions) where fungibility exists within a class.
- __SIP-009 (Non-Fungible Tokens)__
  - Use for identity and soulbound-like credentials. Enforce transfer restrictions in the NFT contract (e.g., only mint/burn; disallow transfers to simulate SBT).
- __SIP-018 (Signed Structured Data)__
  - Use for off-chain proposal signing, execution triggers, and attestations feeding into governance/automation.
- __SIP-020 (Bitwise Ops)__
  - Use for role flags and capability-gating in vaults, or multi-role governance where low-level flags are needed.
- __SIP-021 (Nakamoto Fast Blocks)__
  - Network-level improvement. No contract changes, but plan systems (DEX/AMM, governance UI) to benefit from faster finality.
- __SIP-025 (WSTS Wallet UX)__
  - Follow for wallet-level interoperability and metadata. Align FT/NFT metadata exposure for better wallet display.

# Conxian Alignment Map
- __Dimensional Bonds (`contracts/dimensional/tokenized-bond.clar`)__
  - Standard: SIP-010 fungible token semantics for bond units.
  - External payment token: accept a SIP-010 token principal; use a trait-bound call for transfers during coupon/redemption.
  - Testing: use a `.mock-token` SIP-010-like stub; production: configurable principal stored in state.
- __Registry (`contracts/dimensional/dim-registry.clar`)__
  - Registry of dimensions/weights; token-agnostic but should reference SIP-010 IDs when weights depend on tokens.
- __Governance Tokens__
  - Standard: SIP-010. Consider time-weighted voting snapshots via read-only functions and event logs.
- __LP Tokens (when AMM/DEX module is added)__
  - Standard: SIP-010. Mint on deposit; burn on withdraw. Optional auto-compounding strategies via vault contracts.
- __Creator/Membership Layer__
  - Standard: SIP-013 for editions/passes; SIP-009 for unique identity or non-transferable badges.
- __Off-chain Governance / Automation__
  - Use SIP-018 for signed messages and proposal execution with on-chain verification.
- __Access Control / Roles__
  - Use SIP-020 bitwise flags for granular permissions across vaults/orchestrators.

# Implementation Guidelines
- __Traits__
  - `use-trait payment-token .sip-010-trait.sip-010-trait` and store a `payment-token` principal in contract state.
  - Call via `contract-call?` using the stored principal; keep calls generic to the trait interface.
- __Supply Accounting__
  - Maintain `total-supply` data-var; on mint: `(+ total-supply amount)`, on burn: `(- total-supply amount)`.
- __Error Handling__
  - For external calls, prefer `asserts! (is-ok (...)) (err <code>)` for clear control flow.
- __Metadata__
  - Expose read-only getters for name/symbol/decimals and optional `token-uri`. For NFTs, follow SIP-016 metadata where applicable.

## Dynamic Dispatch Notes (SIP-010)
- Store only the external token as a contract principal (e.g., `optional principal`), not a trait reference.
- Set the principal via `(contract-of <sip10>)` during configuration/issuance.
- Functions performing external calls (e.g., coupon claim, maturity redemption) should accept a `<sip10>` trait-typed principal parameter and use `contract-call?` with un-dotted function names.
- Expose a read-only helper like `(get-payment-token-contract)` to inspect the stored principal for diagnostics.

# Testing & Dev Environment
- __Clarinet Test Manifest__
  - Keep a minimal `Clarinet.test.toml` including: traits (SIP-010), target contracts (registry, bond), and `.mock-token`.
- __Vitest Setup__
  - Use `stacks/global-vitest.setup.ts` with `manifestPath: 'Clarinet.test.toml'` and `initBeforeEach: false` (init once per spec file).
  - In specs, assign `simnet` in `beforeAll`, and retrieve accounts in `beforeEach` to avoid undefined principals.
- __Passing Principals__
  - For external contract principals in tests use `Cl.contractPrincipal(deployer, 'mock-token')` rather than a standard principal.
- __Diagnostics__
  - Verify the stored token principal via `get-payment-token-contract` in tests.
- __Sample Calls__
  - `issue-bond(..., payment-token: Cl.contractPrincipal(deployer, 'mock-token'))`.

# Open Tasks
- [ ] Replace `.mock-token` with a configurable SIP-010 token principal for production settings.
- [ ] Ensure all SIP-010 functions are exposed and tested (including `get-total-supply`).
- [ ] Add governance token spec (SIP-010) and DAO flows using SIP-018.
