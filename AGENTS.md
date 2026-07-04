# Conxian Protocol: Agent Directives (July 2026 — Deep Dive Refresh)

## 1. System Build Ethos
- **Sovereign Autonomy**: All core logic must be autonomous. Avoid manual admin interventions.
- **Nakamoto Alignment**: Use `burn-block-height` for slow-path strategy and `block-height` for fast-path reflexes.
- **Defensive Engineering**: NO `unwrap-panic` in public functions or critical logic. Use `try!`, `match`, or `unwrap!` with explicit errors.
- **CXIP-013 Compliance**: All revenue must flow through the 6-way Fiscal Dam V4.
- **Root-to-Leaf Integrity**: Centralize decision logic in Risk/Treasury agents; keep Core engines as pure executive layers.

## 2. Technical Standards
- **Clarity Version**: Clarity 4 (Epoch 3.0) for Mainnet. Use `stacks-block-time` and `burn-block-height`.
- **SIP Standards**: Strict adherence to SIP-010 (FT) and SIP-009 (NFT). Transfer functions MUST handle optional memos.
- **Principal Injection**: Avoid hardcoding contract literals. Use `data-vars` for external contract principals to support modularity and resolve circular dependencies in tests.

## 3. Operational Directives
- **Dual-Clock Heartbeat**: The `trigger-epoch-update` in `ops-engine.clar` is the protocol's heartbeat. Ensure it is efficient and incentivized.
- **Predictive Risk**: `risk-manager.clar` consolidates liquidation decisions, factoring in `agent-risk` cybernetic scores.
- **Financial Accuracy**: Always normalize asset decimals (e.g., STX u6 to CXD u8) when calculating TVL or protocol-wide metrics.

## 4. Troubleshooting
- **Circular Dependencies**: If tests fail with `CircularReference`, verify that all contracts use the "Principal Injection" pattern via public setters.
- Ensure `.ops-engine` is an authorized minter in `cxd-token.clar` for keeper rewards.
- Verify `.risk-unit` is authorized to call `liquidate-position` in `dimensional-core.clar`.

## 5. Testing Protocols
- **Root-to-Leaf**: Always verify system integration starting from the `ops-engine` heartbeat.
- **Leaf-to-Root**: Ensure individual manager contracts are unit-tested before integration.
- **Dual-Mode**: Use `block-utils.clar` for any time-based or C4-native operations in tests.

## 6. Business Operations System (BOS) Logic
- **Principal Registry**: All Conxian core contracts must use dynamic principals fetched via `operational-treasury.clar`.
- **Contamination Gating**: Any hardcoded `ST...` or `SP...` addresses in `contracts/` are considered a build-break. Jules must flag and fix these during the planning phase.
- **BitVM2 Compliance**: Job Card completions (CJCS v2.0) must be verified against the BitVM2 state root in `lib/clarity-bitcoin.clar` before settlement.

---

## 7. Architecture Overview (July 2026 Audit)

### Repository Scale
- **218 Clarity contracts** across 45+ modules
- **76+ test files** (Vitest + Clarinet SDK)
- **2 Clarinet configs**: `Clarinet.toml` (217 contracts, active) and `Clarinet.complete.toml` (218 contracts, legacy)
- **Key tokens**: CXD (stablecoin), CXLP (LP), CXVG (governance), CXTR (treasury reward), CXS (stub)
- **Key NFTs**: position-nft (SIP-009 compliant), bridge-nft (NON-COMPLIANT), enhanced-governance-nft (soulbound)

### Contract Dependency Hierarchy
```
sip-standards / core-traits / defi-traits / conxian-csf-trait
    ↓
conxian-access / conxian-protocol / kyc-registry / regulatory-adapter
    ↓
cxd-token / oracle-aggregator / bme-engine / enhanced-circuit-breaker
    ↓
concentrated-liquidity-pool / swap-router / lending-manager / dimensional-engine
    ↓
agent-risk / agent-treasury / risk-unit / revenue-distributor / revenue-automation
    ↓
ops-engine (heartbeat) / alex-adapter / governance suite
```

## 8. Critical Issues (P0 — Block Deployment)

### ~~P0-1: cxd-token.clar SIP-010 Trait Type Mismatch~~ ✅ FIXED
- `get-name` and `get-symbol` now return 32-char padded strings matching the trait.

### ~~P0-2: dimensional-core.clar Missing Liquidation Authorization~~ ✅ FIXED
- `liquidate-position` now gated to `.risk-unit`, `.risk-manager`, or contract admin.

### ~~P0-3: CXIP-013 Emission Weights~~ ✅ FIXED
- Weights aligned: DEX 45% (u4500), Bounty 30% (u3000), Gov 15% (u1500), Grants 10% (u1000).
- Lending category replaced with Grants; `register-grants-activity` added.

### ~~P0-4: bme-engine swap-and-burn Stub~~ ✅ FIXED
- `swap-and-burn` now routes tokens to `.swap-router`, executes `csf-swap`, receives CXD, burns via `cxd-token.burn`.
- `revenue-distributor` pre-transfers tokens to `.bme-engine` before calling.
- `distribute-stx` now routes STX to `.swap-router`.

## 9. High-Priority Issues (P1)

### P1-1: 79 unwrap-panic Calls (63 in public functions) -- REMAINING
- 36 files affected; most common patterns: check-clean-hands-compliance, has-role, map-get?
- Key public functions: swap-router.csf-swap, dimensional-engine (8 calls), lending-manager.borrow/withdraw

### ~~P1-2: ops-engine.clar No Authorization~~ FIXED
- trigger-heartbeat, trigger-epoch-update, trigger-emergency-pause now admin-gated.

### ~~P1-3: bridge-nft.clar Non-SIP-009 Compliant~~ FIXED
- Added impl-trait, transfer, get-last-token-id, get-token-uri, get-owner.

### ~~P1-4: Testnet Deployment Plan Address Mismatch~~ FIXED
- All 18 expected-sender entries corrected to testnet deployer address.
- Mainnet manifest expanded from 14 to 55 contracts across 9 phased batches.

### ~~cxd-token.clar Burn Authorization Bug~~ FIXED
- burn function now checks burners map instead of is-minter.

## 10. Medium-Priority Issues (P2)

### P2-1: alex-adapter.clar Stub Implementation -- REMAINING
- execute-csf-swap returns placeholder values; get-csf-health returns hardcoded TVL.

### P2-2: Test Suite Cannot Run -- REMAINING
- Requires clarinet binary (not installed in CI/workspace).

### P2-3: cxs-token.clar Stub Token -- REMAINING
- transfer is no-op; all balances return 0.

### P2-4: revenue-distributor.clar Hardcoded References -- PARTIAL
- Pre-transfer logic fixed; relative contract references remain.

## 11. What Passed Audit

| Area | Status | Detail |
|------|--------|--------|
| Hardcoded principals | CLEAN | 0 ST.../SP... addresses in all 218 contracts |
| Principal injection | GOOD | All admin/owner state initialized via tx-sender |
| cxlp-token.clar SIP-010 | COMPLIANT | 32-char padded strings, correct transfer |
| cxtr-token.clar SIP-010 | COMPLIANT | 32-char padded strings, correct transfer |
| cxvg-token.clar SIP-010 | COMPLIANT | 32-char padded strings, correct transfer |
| position-nft.clar SIP-009 | COMPLIANT | Full SIP-009 interface implemented |
| bridge-nft.clar SIP-009 | COMPLIANT | Full SIP-009 interface implemented (July 2026) |
| cxd-token.clar SIP-010 | COMPLIANT | 32-char padded strings, correct burn auth (July 2026) |
| revenue-automation.clar | COMPLIANT | 100 bps fee enforced correctly |
| risk-unit.clar liquidation | COMPLIANT | Tiered thresholds, proper auth, cache management |
| operational-treasury.clar | SOLID | Principal registry, multi-path authorization |
| enhanced-circuit-breaker | PRESENT | Multi-tier isolation, global pause |
| bme-engine.clar CXIP-013 | COMPLIANT | Weights aligned: DEX 45%, Bounty 30%, Gov 15%, Grants 10% |
| dimensional-core.clar | SECURE | liquidation-position gated to risk-unit/risk-manager/admin |

## 12. Mainnet Deployment Prerequisites (ALEX Path)

Before sign-off for mainnet deployment via ALEX:

1. ~~Fix cxd-token get-name/get-symbol~~ -- DONE (P0-1)
2. ~~Add liquidation auth to dimensional-core~~ -- DONE (P0-2)
3. ~~Align BME weights with CXIP-013~~ -- DONE (P0-3)
4. ~~Implement actual swap-and-burn~~ -- DONE (P0-4)
5. ~~Add auth to ops-engine heartbeat functions~~ -- DONE (P1-2)
6. **Replace 63 public unwrap-panic calls** with proper error handling (P1-1) -- REMAINING
7. ~~Fix testnet deployment plan~~ -- DONE (P1-4)
8. ~~Implement bridge-nft SIP-009~~ -- DONE (P1-3)
9. **Install clarinet and run full test suite** -- REMAINING (P2-2)
10. ~~Verify BitVM2 attestation in clarity-bitcoin.clar~~ -- HARDENED (structural validation + audit trail; production SNARK verifier still needed)
11. **Complete alex-adapter with real ALEX contract calls** -- REMAINING (P2-1)
12. ~~Finalize mainnet manifest~~ -- DONE (v2.0.0, 55 contracts, 9 phased batches)

Progress: 9/12 complete. 3 items remain before mainnet sign-off.
