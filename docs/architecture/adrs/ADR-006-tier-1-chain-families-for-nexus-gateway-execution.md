# ADR-006: Tier 1 chain families for Nexus/Gateway execution

## Status
Accepted

## Context
`docs/NEXUS_GATEWAY_UNIVERSAL_CHAIN_ARCHITECTURE.md` defines an adapter-family implementation model and leaves the Tier 1 execution families as an explicit open question.

To sequence delivery in `conxian-nexus` and `conxian-gateway`, we need a single approved Tier 1 scope for:
- Nexus indexing, finality, proof, and trust-classification work
- Gateway capabilities, transaction-preparation, and routing/policy work

This ADR records the approved decision from CON-789 and the linked `conxian-business` issue discussion.

Decision references:
- Linear: https://linear.app/conxian-labs/issue/CON-789/research-and-decide-tier-1-chain-families-for-nexus-and-gateway#comment-7e4ccd52
- GitHub: https://github.com/Conxian/conxian-business/issues/735#issuecomment-4645699391

## Decision
The Tier 1 chain families for Nexus/Gateway execution are:
- Bitcoin/UTXO
- EVM
- Cosmos/IBC

The following families are explicitly deferred from Tier 1 execution scope:
- Solana/SVM
- Move
- Substrate

Execution implication:
- Nexus should prioritize production-grade ingestion, finality handling, and proof/state projection for the three Tier 1 families.
- Gateway should prioritize production-grade capabilities negotiation, unsigned-transaction preparation, and policy/routing for the same three Tier 1 families.
- Deferred families remain roadmap candidates and require a follow-up ADR before being promoted into Tier 1 execution commitments.

## Consequences
- Nexus/Gateway implementation order is now explicit and aligned to one Tier 1 family set.
- Backlog planning, acceptance gates, and integration contracts should treat Bitcoin/UTXO, EVM, and Cosmos/IBC as required first-class execution paths.
- Solana/SVM, Move, and Substrate work can continue as research/prototype tracks, but not as Tier 1 delivery commitments.
- Future Tier 1 expansion must add or supersede this decision with a new ADR.
