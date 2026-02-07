# Future Repairs Preparation Checklist

## Overview

This document tracks preparation items for upcoming repair phases following the completion of P1-P6 priority repairs (January 2026).

---

## Completed Work (P1-P6)

✅ **Sovereign Handoff**: Timelock execution, admin transfers, 5-step handoff orchestration  
✅ **Regulatory Gaps**: Provider-based compliance, KYC/AML attestation  
✅ **Tokenomics Clarity**: Supply caps, 60/20/20 immutability  
✅ **ICO Hardening**: Compliance gating, purchase caps  
✅ **NFT Economics**: CXLP Position NFT full implementation  
✅ **Operational Safety**: Rate limiter, proof-of-reserves  

---

## Pre-Testnet Deployment Preparation

### Contract Validation

- [ ] Run `clarinet check` on all 12 modified contracts
- [ ] Verify no unresolved contract references in modified files
- [ ] Verify no unresolved variable references (e.g., `stacks-block-time` in cxd-token.clar)
- [ ] Check trait conformance for all implemented traits

### Test Suite Preparation

- [ ] Update unit tests for timelock execution flow
- [ ] Create compliance provider registration tests
- [ ] Add ICO purchase cap validation tests
- [ ] Write CXLP NFT mint/transfer tests
- [ ] Test rate limiter window reset logic
- [ ] Validate proof-of-reserves attestation flow

### Integration Tests

- [ ] Sovereign handoff end-to-end (all 5 steps)
- [ ] Compliance check integration with ICO
- [ ] Tokenomics: Mint up to max supply boundary
- [ ] Rate limiting under load simulation
- [ ] Proof-of-reserves with multiple attestors

### Documentation Preparation

- [ ] API documentation for new public functions
- [ ] Sovereign handoff runbook for testnet
- [ ] Compliance provider integration guide
- [ ] Tokenomics spec update (supply caps)
- [ ] Security audit preparation notes

---

## Potential Future Repair Areas (P7+)

Based on gap analysis and remaining items:

### P7: Cross-Chain Integration

- **Wormhole Outbox**: Hardcoded address resolution
- **Bridge NFTs**: Cross-chain asset verification
- **Oracle Aggregators**: DIA, Chainlink adapter completeness

### P8: DEX Completion

- **Concentrated Liquidity Pool**: Integration with CXLP Position NFT
- **Multi-Hop Router V3**: Path optimization and slippage
- **Batch Auction**: MEV-resistant trading

### P9: Lending Protocol

- **Interest Rate Model**: Utilization curve tuning
- **Liquidation Manager**: Incentive structure
- **Collateral Manager**: LTV ratios and oracle integration

### P10: Governance Enhancement

- **Proposal Engine**: Full trait-based proposal types
- **Voting**: Quadratic voting integration
- **Reputation Engine**: Clean-hands reputation weighting

### P11: Agent Systems

- **Agent Risk**: Automated risk parameter adjustment
- **Agent Treasury**: Autonomous rebalancing
- **Office Manager**: Task queue optimization

### P12: Developer Experience

- **Clarinet Configuration**: Contract reference cleanup
- **Testing Framework**: Comprehensive coverage
- **Deployment Scripts**: StacksOrbit integration

---

## Dependencies to Resolve

### Unresolved Contract References (Pre-existing)

The following are in contracts NOT modified during P1-P6 and require separate repair:

- `ST*...dimensional-core` in agent-risk.clar:217
- `ST*...cxvg-token` in proposal-executor.clar:28
- `ST*...admin-facade` in conxian-protocol.clar:38
- `ST*...regulatory-adapter` in cxd-staking.clar:42
- `ST*...block-utils` in dimensional-core.clar:461
- `ST*...conxian-protocol` in oracle files
- `ST*...conxian-access` in circuit-breaker.clar:35

**Action**: Create P12 "Clarinet Configuration" repair to systematically replace all hardcoded addresses with relative references.

---

## Testnet Deployment Sequence

### Phase 1: Core Infrastructure

1. Deploy traits first
2. Deploy core contracts (conxian-access, admin-facade, conxian-protocol)
3. Deploy timelock
4. Verify handoff readiness

### Phase 2: Compliance & Tokens

5. Deploy compliance contracts
2. Deploy token contracts (with max supply verification)
3. Deploy allocation-policy
4. Test token minting up to cap

### Phase 3: DeFi & NFT

9. Deploy CXLP Position NFT
2. Deploy ICO offering
3. Test ICO with compliance gating
4. Verify purchase caps

### Phase 4: Security

13. Deploy rate-limiter
2. Deploy proof-of-reserves
3. Configure operation limits
4. Add attestors

### Phase 5: Sovereign Handoff

17. Execute handoff step 1 (conxian-access)
2. Execute handoff step 2 (admin-facade)
3. Execute handoff step 3 (timelock)
4. Execute handoff step 4 (operational-treasury)
5. Execute handoff step 5 (regulatory-adapter)
6. Finalize handoff
7. Verify all ownership transferred

---

## Security Audit Scope

### High Priority for Audit

- [ ] Timelock proposal execution logic
- [ ] Rate limiter bypass vectors
- [ ] Proof-of-reserves attestation manipulation
- [ ] Compliance provider authorization
- [ ] ICO cap enforcement
- [ ] CXD supply cap enforcement

### Medium Priority

- [ ] CXLP NFT transfer safety
- [ ] Allocation policy lock mechanism
- [ ] Sovereign handoff step ordering
- [ ] Event log completeness

### Low Priority

- [ ] Read-only function accuracy
- [ ] Event naming consistency
- [ ] Error code uniqueness

---

## Resources Required

### Development

- Clarinet 3.12+ with Epoch 3.0 support
- Node.js 18+ for testing
- StacksOrbit for deployment automation

### Testnet

- STX for contract deployment (~50 contracts)
- Test wallets for compliance provider simulation
- Mock oracle feeds for PoR testing

### Documentation

- API spec templates
- Runbook templates
- Audit preparation templates

---

## Timeline Estimate

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Contract Validation | 1 day | None |
| Test Suite Updates | 2-3 days | Validation complete |
| Testnet Deployment | 1 day | Tests passing |
| Handoff Execution | 1 day | Deployment complete |
| Integration Testing | 2 days | Handoff complete |
| Audit Preparation | 2 days | Integration complete |

**Total**: ~9-10 days to audit-ready state

---

## Success Criteria

- [ ] All 12 repaired contracts pass `clarinet check`
- [ ] Test coverage >80% for new functions
- [ ] Sovereign handoff executes successfully on testnet
- [ ] ICO processes 100+ test purchases with compliance
- [ ] Rate limiter blocks excessive operations
- [ ] Proof-of-reserves validates with 3+ attestors
- [ ] Documentation complete for auditors

---

**Created**: January 31, 2026  
**Status**: Awaiting P1-P6 test validation before proceeding  
**Next Review**: Upon testnet deployment completion
