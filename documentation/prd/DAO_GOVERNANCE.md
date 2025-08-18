## DAO Governance & Voting PRD (v1.1)

**References**: `dao-governance.clar`, `dao.clar`, AIP-2 (time-weighted voting), timelock, SDK 3.5.0 testing compliance

**Status**: **STABLE** - Production Ready with SDK 3.5.0 compliance  
**Last Updated**: 2025-08-18  
**Next Review**: 2025-09-15

## Summary

On-chain proposal system with time-weighted voting & timelock execution ensuring resistance to flash accumulation & manipulation.

### Goals

- Fair vote weighting over time.  
- Transparent proposal lifecycle (create → queue → execute).  
- Parameter changes governed (vault fees, caps, pause, treasury spends).

### Functional Requirements (FR)

| ID | Requirement |
|----|-------------|
| DAO-FR-01 | Create proposal referencing target contracts + calldata. |
| DAO-FR-02 | Voting window >= configured min blocks. |
| DAO-FR-03 | Time-weight formula adds max 25% bonus for long-held tokens. |
| DAO-FR-04 | Prevent flash-loan style last-block weight spikes. |
| DAO-FR-05 | Quorum threshold enforced pre-queue. |
| DAO-FR-06 | Timelock delay enforced before execution. |
| DAO-FR-07 | Events: proposal-created, vote-cast, queued, executed, canceled. |
| DAO-FR-08 | Delegation supported without resetting time weight. |

### Non-Functional

- Deterministic weight calculation; no loops > fixed constant per vote.  
- Upgradability via new governor contract & registry pointer.

### Invariants

- DAO-INV-01: A proposal cannot execute without passing quorum & delay.  
- DAO-INV-02: Weight bonus cap enforced.

### Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Vote buying | Time factor reduces incentive for short-term capture |
| Low participation | Participation bonus encourages engagement |
| Proposal spam | Min proposal threshold tokens |

### Metrics

- Participation rate, average execution delay, proposal success %, delegation %.

### Open Questions

- Should decay apply to inactive delegates beyond N epochs?

**Changelog**:
- v1.1 (2025-08-18): SDK 3.5.0 compliance validation, production readiness confirmation  
- v1.0 (2025-08-17): Initial stable implementation

**Approved By**: Protocol WG, Governance Team  
**Mainnet Status**: **APPROVED FOR DEPLOYMENT**
