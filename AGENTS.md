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

### P0-1: cxd-token.clar SIP-010 Trait Type Mismatch
- `get-name` returns `(string-ascii 14)` — trait expects `(string-ascii 32)`
- `get-symbol` returns `(string-ascii 3)` — trait expects `(string-ascii 32)`
- **Will fail Clarity trait verification at deployment.** Fix: pad to 32 chars like cxlp-token.clar does.

### P0-2: dimensional-core.clar Missing Liquidation Authorization
- `liquidate-position` is callable by ANYONE (only checks pause state)
- AGENTS.md requires `.risk-unit` authorization, but there's NO auth check
- risk-unit.clar properly gates the `liquidate` function, but dimensional-core bypasses it entirely
- Fix: Add `asserts! (is-eq contract-caller .risk-unit)` or authorization check

### P0-3: CXIP-013 Emission Weights — All Values Wrong
- Spec: DEX 45% / Bounty 30% / Gov 15% / Grants 10%
- Code: DEX 40% / Lending 30% / Bounty 20% / Gov 10% (Grants missing entirely)
- "Lending" category does not exist in CXIP-013; "Strategic Grants" is absent

### P0-4: bme-engine swap-and-burn is a Stub
- `swap-and-burn` only prints an event and increments a counter — NO actual swap
- `burn-protocol-fees` only increments `total-burned` — NO actual burn
- `distribute-stx` in revenue-distributor is a stub (print only)
- 100% buy-back-and-burn policy declared but NOT implemented

## 9. High-Priority Issues (P1)

### P1-1: 79 unwrap-panic Calls (63 in public functions)
- 36 files affected; most common patterns: check-clean-hands-compliance, has-role, map-get?
- Key public functions: swap-router.csf-swap, dimensional-engine (8 calls), lending-manager.borrow/withdraw, revenue-distributor.distribute-token
- verification-checklist.md falsely claims "No unwrap-panic in executive paths" (checked complete)

### P1-2: ops-engine.clar — No Authorization
- `trigger-heartbeat`, `trigger-epoch-update`, `trigger-emergency-pause` — CALLABLE BY ANYONE
- `admin` data-var is set but never checked
- Anyone can trigger epoch updates or emergency pauses at will

### P1-3: bridge-nft.clar — Completely Non-SIP-009 Compliant
- No `impl-trait` declaration, no `transfer`, no `get-last-token-id`, no `get-token-uri`, no `get-owner`
- Only has `cross-chain-mint` and admin endpoint management

### P1-4: Testnet Deployment Plan Address Mismatch
- `full-system.testnet-plan.yaml` uses Devnet address `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM` as `expected-sender`
- Plan-level `deployer` is `ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P`
- Previous testnet deployment failed: 88/91 contracts failed
- Mainnet manifests only deploy ~20 contracts vs 91 needed

## 10. Medium-Priority Issues (P2)

### P2-1: alex-adapter.clar — Stub Implementation
- `execute-csf-swap` returns placeholder values (amount-out = amount-in, mock 30bps fee)
- `claim-conxian-yield` returns `(ok amount)` without actual logic
- `get-csf-health` returns hardcoded TVL (u100000000000) and utilization (u50)

### P2-2: Test Suite Cannot Run
- Requires `clarinet` binary (not installed in CI/workspace)
- `verification-checklist.md` calls out "Vitest suite executed without skips (blocked pending Simnet principal resolution fixes)"

### P2-3: cxs-token.clar — Stub Token
- `transfer` is `(ok true)` no-op, never calls `ft-transfer?`
- All balances always return 0

### P2-4: revenue-distributor.clar — Hardcoded bme-vault Reference
- `bme-vault` defaults to `.bme-engine` (relative, OK) but `distribute-token` uses hardcoded `.bme-engine` and `.cxd-token` references
- `get-operational-treasury` returns hardcoded `.operational-treasury`

## 11. What Passed Audit

| Area | Status | Detail |
|------|--------|--------|
| Hardcoded principals | ✅ CLEAN | 0 ST.../SP... addresses in all 218 contracts |
| Principal injection | ✅ GOOD | All admin/owner state initialized via tx-sender |
| cxlp-token.clar SIP-010 | ✅ COMPLIANT | 32-char padded strings, correct transfer |
| cxtr-token.clar SIP-010 | ✅ COMPLIANT | 32-char padded strings, correct transfer |
| cxvg-token.clar SIP-010 | ✅ COMPLIANT | 32-char padded strings, correct transfer |
| position-nft.clar SIP-009 | ✅ COMPLIANT | Full SIP-009 interface implemented |
| revenue-automation.clar | ✅ COMPLIANT | 100 bps fee enforced correctly |
| risk-unit.clar liquidation | ✅ COMPLIANT | Tiered thresholds, proper auth, cache management |
| operational-treasury.clar | ✅ SOLID | Principal registry, multi-path authorization |
| enhanced-circuit-breaker | ✅ PRESENT | Multi-tier isolation, global pause |

## 12. Mainnet Deployment Prerequisites (ALEX Path)

Before sign-off for mainnet deployment via ALEX:

1. **Fix cxd-token get-name/get-symbol** — pad to 32 chars (P0-1)
2. **Add liquidation auth to dimensional-core** — gate liquidate-position (P0-2)
3. **Align BME weights with CXIP-013** — DEX 45%, Bounty 30%, Gov 15%, Grants 10% (P0-3)
4. **Implement actual swap-and-burn** — route through swap-router (P0-4)
5. **Add auth to ops-engine heartbeat functions** — admin-gate trigger-heartbeat/epoch-update/emergency-pause (P1-2)
6. **Replace 63 public unwrap-panic calls** with proper error handling (P1-1)
7. **Fix testnet deployment plan** — correct expected-sender, add phased batches (P1-4)
8. **Implement bridge-nft SIP-009** or remove from NFT classification (P1-3)
9. **Install clarinet and run full test suite** — verify no regressions
10. **Verify BitVM2 attestation in clarity-bitcoin.clar** — ensure not still a stub
11. **Complete alex-adapter with real ALEX contract calls** — remove placeholder values
12. **Finalize mainnet manifest** with all 91 contracts in correct dependency order
