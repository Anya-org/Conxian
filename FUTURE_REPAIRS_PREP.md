# Conxian Protocol: Future Repairs & Testnet Prep (March 2026)

This document outlines the remaining steps and planned refinements for the Apex CSF v1.1.0 deployment.

## Technical Refinements

### Apex BME Optimization
- **Action**: Refine the `execute-epoch-minting` logic in `bme-engine.clar` to support dynamic emission curves based on total Stacks TVL.
- **Priority**: Medium

### External Adapter Registry
- **Action**: Build automated chainhook scanners to populate the `csf-registry` in `dex-factory.clar` when new CSF-compliant contracts are deployed.
- **Priority**: High (Nexus API Expansion)

---

## Testnet Deployment Sequence (Apex Optimized)

### Phase 1: Foundational Traits
1. Deploy `sip-standards.clar` and `conxian-csf-trait.clar`.
2. Deploy `conxian-intent-trait.clar`.

### Phase 2: Security & Governance
3. Deploy `conxian-protocol` and `conxian-access`.
4. Deploy `enhanced-circuit-breaker.clar`.
5. Initialize admin roles.

### Phase 3: Executive Engines
6. Deploy `oracle-aggregator.clar` (Register sBTC, stSTX).
7. Deploy `bme-engine.clar` and `cxd-token.clar`.
8. Deploy `concentrated-liquidity-pool.clar`.

### Phase 4: Apex Routing Layer
9. Deploy `swap-router.clar` (CSF Dynamic Dispatch).
10. Register initial CSF-compliant external protocols.

---

## Success Criteria (Apex Milestone)

- [x] CSF v1.1.0 trait compliance verified.
- [x] Universal Router successfully routes through mock CSF sources.
- [x] Circuit breaker isolation mode blocks contagion in simulation.
- [x] 100% of fees correctly reported to BME Activity Markers.

**Created**: March 15, 2026
**Status**: Apex Architecture Validated
**Next Review**: Post-Testnet Pilot
