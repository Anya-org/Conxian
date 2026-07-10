# Standards Audit Checklist - Session 25

## Security Module

### circuit-breaker.clar
- [ ] `is-contract-paused`: Add `@return`
- [ ] `toggle-contract-pause`: Add `@return`
- [ ] `set-admin`: Add `@return`
- [ ] `trigger-veto`: Add `@return`
- [ ] `resolve-veto`: Add `@return`

### enhanced-circuit-breaker.clar
- [ ] `toggle-global-pause`: Add `@return`
- [ ] `toggle-contract-pause`: Add `@desc`, `@param`, `@return`
- [ ] `toggle-isolation`: Add `@param`, `@return`
- [ ] `set-admin`: Add `@desc`, `@param`, `@return`

### rate-limiter.clar
- [ ] `check-rate-limit`: Add `@return`
- [ ] `set-custom-limit`: Add `@return`
- [ ] `transfer-ownership`: Add `@return`

### mev-protector.clar
- [ ] `commit-order`: Add `@param`, `@return`
- [ ] `verify-and-consume`: Add `@param`, `@return`

### proof-of-reserves.clar
- [ ] `add-attestor`: Add `@param`, `@return`
- [ ] `remove-attestor`: Add `@param`, `@return`
- [ ] `submit-attestation`: Add `@param`, `@return`
- [ ] `sync-on-chain-balance`: Add `@param`, `@return`
- [ ] `set-oracle-aggregator`: Add `@desc`, `@param`, `@return`
- [ ] `set-contract-owner`: Add `@desc`, `@param`, `@return`

### conxian-insurance-fund.clar
- [ ] (Already compliant)

### README.md
- [ ] Define: Circuit Breaker, MEV, Proof of Reserves, Insurance Fund, Veto Quorum, Rate Limiting.
- [ ] Verify Diátaxis structure.

## Compliance Module

### compliance-manager.clar (After merge)
- [ ] `register-provider`: Add `@desc`, `@param`, `@return`
- [ ] `remove-provider`: Add `@desc`, `@param`, `@return`
- [ ] `set-sanctions-provider`: Add `@desc`, `@param`, `@return`
- [ ] `check-user-compliance`: Add `@desc`, `@param`, `@return`
- [ ] `set-owner`: Add `@desc`, `@param`, `@return`
- [ ] `batch-check-compliance`: Add `@desc`, `@param`, `@return`
- [ ] `check-kyc-compliance`: Add `@desc`, `@param`, `@return`

### compliance-hooks.clar
- [ ] `set-contract-owner`: Add `@return`
- [ ] `set-compliance-manager`: Add `@return`
- [ ] `add-kyc-provider`: Add `@return`
- [ ] `remove-kyc-provider`: Add `@return`
- [ ] `verify-kyc`: Add `@return`
- [ ] `log-audit-event`: Add `@return`

### regulatory-adapter.clar
- [ ] `check-clean-hands-compliance`: Add `@return`
- [ ] `register-attestation`: Add `@return`
- [ ] `set-validator`: Add `@return`
- [ ] `transfer-ownership`: Add `@return`
- [ ] `update-authority`: Add `@return`
- [ ] `verify-and-update-compliance`: Add `@return`

### jurisdictional-sharding.clar
- [ ] `register-currency`: Add `@desc`, `@param`, `@return`
- [ ] `register-jurisdiction`: Add `@desc`, `@param`, `@return`
- [ ] `register-kyc-extended`: Add `@desc`, `@param`, `@return`
- [ ] `record-global-settlement`: Add `@desc`, `@param`, `@return`
- [ ] `record-zar-settlement`: Add `@desc`, `@param`, `@return`
- [ ] `initialize-protocol-currencies`: Add `@desc`, `@return`

### travel-rule-service.clar
- [ ] `register-vasp`: Add `@return`
- [ ] `log-travel-rule-data`: Add `@return`

### zkml-verifier.clar
- [ ] `verify-proof`: Add `@return`
- [ ] `set-admin`: Add `@desc`, `@param`, `@return`

### README.md
- [ ] Define: KYC, AML, Travel Rule (IVMS101), ZKML, SIP-018, VASP, Jurisdictional Sharding.
- [ ] Verify Diátaxis structure.
