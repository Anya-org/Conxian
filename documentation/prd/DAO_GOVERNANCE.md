# DAO Governance & Voting PRD (v1.1)

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

## Founder Token Reallocation

**Status**: **IMPLEMENTED** - Production Ready

### Summary

To ensure long-term decentralization and incentivize active governance, a portion of founder tokens are subject to reallocation to the automated bounty system if founder participation drops below a certain threshold.

### Functional Requirements (FR)

| ID | Requirement |
|----|-------------|
| DAO-FR-09 | Track founder voting participation per epoch. |
| DAO-FR-10 | If a founder's participation drops below 60% in an epoch, reallocate 2% of their token holdings to the automated bounty system. |
| DAO-FR-11 | The reallocation check for each founder can be triggered by anyone after the epoch has concluded. An off-chain keeper is expected to perform this action. |

### New Contracts

- **`governance-metrics.clar`**: A new contract to track founder participation metrics without using recursion.
- **`reputation-token.clar`**: A new non-transferable token to reward contributors.

### Integration

- The `dao-governance.clar` contract is integrated with `governance-metrics.clar` to track participation and `automated-bounty-system.clar` to fund bounties.
- The `automated-bounty-system.clar` is integrated with `reputation-token.clar` to award reputation tokens to bounty winners.
