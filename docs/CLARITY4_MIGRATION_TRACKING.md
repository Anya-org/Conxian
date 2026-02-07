# Clarity 4 Migration Tracking - Mainnet Alignment

## Status

**Current:** Clarity 3 (mainnet-compatible)
**Target:** Clarity 4 (upon mainnet activation)
**Last Updated:** February 2026

---

## Mainnet Activation Criteria

Clarity 4 is NOT yet active on mainnet. The migration will be tied to:

### 1. Epoch 3.1 Activation

- **Current Mainnet Epoch:** 3.0 (Nakamoto)
- **Target Epoch:** 3.1 (Clarity 4 support)
- **Status:** Not yet scheduled

### 2. SIP-033 Implementation

Clarity 4 features we will leverage:

- `contract-hash?` - Module registry security
- `stacks-block-time` - High-precision temporal logic
- `secp256r1-verify` - Passkey/biometric support
- `get-burn-block-info?` - Bitcoin header verification

---

## Pre-Migration Checklist

### Phase 1: Preparation (Current)

- [x] All contracts compile with Clarity 3
- [x] Critical bug fixes implemented (DEX swap, lending collateral, liquidation, governance IDs)
- [x] Functional fixes verified Clarity 3 compatible
- [ ] Testnet deployment validated
- [ ] Security audit scope defined

### Phase 2: Mainnet Deployment (Clarity 3)

- [ ] Deploy current protocol to mainnet
- [ ] Establish TVL and user base
- [ ] Monitor for critical issues

### Phase 3: Clarity 4 Migration (Upon Activation)

- [ ] Monitor Stacks mainnet for Epoch 3.1 activation
- [ ] Update `Clarinet.toml` clarity-version from 3 → 4
- [ ] Update `epoch` from "3.0" → "3.1"
- [ ] Uncomment Clarity 4 features:
  - `(get-contract-hash contract)` in `conxian-protocol.clar`
  - `(stacks-block-time)` where `burn-block-height` used for precision
- [ ] Deploy upgrade via `upgrade-controller`
- [ ] Verify all contracts function correctly

---

## Tracking Commands

```bash
# Check mainnet epoch status
stacks-node get-info | jq '.epoch_id'

# Check Clarinet compatibility
clarinet check --clarity-version 4

# Monitor for Clarity 4 activation on mainnet
# (Watch Stacks Foundation announcements)
```

---

## Affected Contracts for Migration

When Clarity 4 activates, these contracts will be upgraded:

| Contract | Current Version | Clarity 4 Feature |
|----------|----------------|-------------------|
| `sip-standards` | 3 | Native trait improvements |
| `core-traits` | 3 | Enhanced trait syntax |
| `defi-traits` | 3 | Enhanced trait syntax |
| `block-utils` | 3 | `stacks-block-time`, `get-burn-block-info?` |
| `conxian-protocol` | 3 | `contract-hash?` security |
| `conxian-access` | 3 | Enhanced RBAC |
| `admin-facade` | 3 | Enhanced patterns |
| `economic-policy-engine` | 3 | `stacks-block-time` precision |
| `cxd-token` | 3 | SIP-010 optimizations |
| `cxvg-token` | 3 | Enhanced token features |
| `cxs-token` | 3 | Enhanced token features |
| `cxtr-token` | 3 | Enhanced token features |
| `cxlp-token` | 3 | Enhanced token features |

---

## Functional Fixes Preserved

These critical fixes work with both Clarity 3 and 4:

1. **DEX Swap Fix** (`concentrated-liquidity-pool.clar`)
   - Output token transfer to user
   - Clarity 3 ✅ | Clarity 4 ✅

2. **Lending Collateral Check** (`lending-manager.clar`)
   - `is-sufficiently-collateralized` function
   - Clarity 3 ✅ | Clarity 4 ✅

3. **Liquidation Logic** (`agent-risk.clar`)
   - `liquidate` and `liquidate-position` implementation
   - Clarity 3 ✅ | Clarity 4 ✅

4. **Governance IDs** (`community-voting-engine.clar`)
   - `proposal-counter` incrementing IDs
   - Clarity 3 ✅ | Clarity 4 ✅

5. **Finality Check** (`block-utils.clar`)
   - `check-finality` with 6 confirmations
   - Clarity 3 ✅ | Clarity 4 ✅

---

## Notes

- All functional fixes are Clarity 3 compatible
- No Clarity 4-specific syntax used in fixes
- Migration is purely additive (security + precision enhancements)
- Protocol will operate fully on Clarity 3 until mainnet activates Epoch 3.1

---

## Reference

- [Stacks Nakamoto Rollout](https://docs.stacks.co/nakamoto-upgrade/nakamoto-rollout-plan)
- [SIP-033: Clarity 4](https://github.com/stacksgov/sips/blob/main/sips/sip-033/sip-033-clarity-4.md)
- [Stacks Roadmap](https://stacksroadmap.com/)
