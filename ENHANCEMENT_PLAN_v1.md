# Conxian-Labs Production Enhancement Plan (v1.0)
**Directive**: cxn-arch-guardian | Systematic Alignment Audit Result

## Phase 1: Protocol Hardening & "Ghost Logic" Remediation
**Goal**: Physically implement critical logic that is currently documented or marked "Done" but missing.

1. **Revenue Automation**: Implement `revenue-automation.clar` to enforce the 100 bps Sovereign Tax.
2. **Referral Aggregator**: Implement `referral-aggregator.clar` (95% Worker / 5% Referrer split).
3. **DLC Bond Lifecycle**: Implement the full `dlc-bond.clar` and `dlc-orchestrator.clar` logic.
4. **Ubuntu Credit**: Implement the `cxn-ubuntu-credit.clar` trait for group-vouching.
5. **Decentralized RBAC**: Run the `conxian-access` remediation script to replace the hardcoded admin 'ST1PQ...GM' in all 40+ contracts with dynamic RBAC calls.

## Phase 2: Infrastructure Sovereignty & Bridging
**Goal**: Move from simulation to sovereign persistence.

1. **Tableland Integration**: Implement the `COMMIT_STATE_TO_TABLELAND` action in Conxian Nexus.
2. **NTT Relayer Productionization**: Wire actual VAA submission and hardware attestation verification into the `NttRelayer` in the Gateway.
3. **ERP OData Parser**: Implement a production-grade OData v4 parser in the Gateway to replace the current simulation.

## Phase 3: Identity & Compliance (The Lens & Pipe)
**Goal**: Complete the high-fidelity identity and messaging stack.

1. **Identity Resolvers**: Implement functional ENS, BNS, and WorldID resolution in the `conxius-wallet` Identity Service.
2. **ISO 20022 Egress**: Verify the `pacs.008` XML generation against live banking test vectors.
3. **SLA Enforcer**: Implement the SLA-anchored slashing logic in the Gateway/Nexus as specified in `docs/AGENTS.md`.

## Phase 4: Financial Intelligence & SDK Unification
**Goal**: Institutional-grade reporting and developer experience.

1. **Nexus Revenue Module**: Implement real-time ARR/MRR/Churn tracking in `conxian-nexus`.
2. **SDK Unification**: Consolidate all versions of `lib-conxian-core` into the root directory and update all sub-repos to use it as a standard Git submodule or cargo workspace member.
3. **Supabase Sync**: Map the missing `cxn_locked_principal` and `cxn_yield_generation` tables in the live Supabase instance.

---
**Status**: Ready for Sequential Execution.
