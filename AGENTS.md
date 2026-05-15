# Conxian AGENTS.md

## BOS Operational Standards

### Sovereign Enterprise Mandate (Unified Theory v2.0)
All agentic sessions must adhere to the equations defined in `docs/CONXIAN_UNIFIED_THEORY_v2.md`.
- **Execution Velocity ($V_X$)**: Prioritize AI leverage (Windsurf, Jules) to crush milestones before $O_C$ exhaustion.
- **System Autonomy ($A_S$)**: Minimize manual oversight. If a process requires manual intervention, it is a Phase 3 failure and must be remediated to $O_C \to 0$.


### Sovereign-First Deployment Mandate
All Conxian core contracts must use dynamic principals fetched via `operational-treasury.clar`. Any hardcoded `ST...` or `SP...` addresses in production contract source code are considered a build-break. Jules must flag and fix these during the planning phase.

### Zero Secret Egress (ZSE) Compliance
- Sensitive operational logic and private configurations must remain in Linear or Supabase.
- Code should only contain "State Proof" logic and public-facing protocol primitives.
- Functional stubs in production paths must return explicit service errors (501/503) and fail closed.

### Knowledge Management (BOS Knowledge Graph)
- **Crystallization**: Every session must conclude with a structured digest summarizing entities (People, Projects, Libraries, Decisions) and relationships.
- **Typed Knowledge**: Agents must prioritize structured entity extraction over flat prose to enable graph-aware traversal.
- **Verification**: All claims must be cross-referenced against the existing knowledge graph in `conxian-business/BOS_KNOWLEDGE_GRAPH.md`.

### BitVM2 Integration
BitVM2 integration must use SNARK-based state proofs verified via `lib-conxian-core`. Verification logic must bridge Bitcoin L1 state and the BitVM2 verification engine as per CJCS v2.0.

### Repository Hygiene
- Submodule drift is monitored by the CI Contamination Guard.
- Submodule pins must be updated immediately upon validated remediation.
- No launch-critical automation may depend on personal/bootstrap wallets.
