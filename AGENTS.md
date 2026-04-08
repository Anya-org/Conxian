# Conxian AGENTS.md

## BOS Operational Standards

### Sovereign-First Deployment Mandate
All Conxian core contracts must use dynamic principals fetched via `operational-treasury.clar`. Any hardcoded `ST...` or `SP...` addresses in production contract source code are considered a build-break. Jules must flag and fix these during the planning phase.

### Zero Secret Egress (ZSE) Compliance
- Sensitive operational logic and private configurations must remain in Linear or Supabase.
- Code should only contain "State Proof" logic and public-facing protocol primitives.
- Functional stubs in production paths must return explicit service errors (501/503) and fail closed.

### BitVM2 Integration
BitVM2 integration must use SNARK-based state proofs verified via `lib-conxian-core`. Verification logic must bridge Bitcoin L1 state and the BitVM2 verification engine as per CJCS v2.0.

### Repository Hygiene
- Submodule drift is monitored by the CI Contamination Guard.
- Submodule pins must be updated immediately upon validated remediation.
- No launch-critical automation may depend on personal/bootstrap wallets.
