# Specifications: Sovereign Data Migration & Institutional Egress

(Note: Technical requirements are formally defined in `specs/sovereign-data-migration-institutional-egress/spec.md`.)

## 1. Phase 5 clean-break requirements
- **SPEC-SDM-001**: Supabase MUST NOT be correctness-critical.
- **SPEC-SDM-002**: Neon MUST NOT be correctness-critical.
- **SPEC-SDM-003**: Derived datasets MUST be deterministic rebuilds from Stacks L1.

## 2. Verifiable analytics requirements
- **SPEC-AN-001**: Proof/visual-proof datasets MUST be checkpointed on-chain.
- **SPEC-AN-002**: Analytics providers MAY change without changing dataset truth.

## 3. Institutional egress (subledger) requirements
- **SPEC-IE-001**: Egress is standardized read-only subledger export.
- **SPEC-IE-002**: Egress datasets MUST be verifiable against on-chain checkpoints.
- **SPEC-IE-003**: Egress datasets MUST NOT contain secrets or enclave-only material.

## 4. Developer experience requirements
- **SPEC-DEV-001**: Local development MUST run without Supabase/Neon dependencies.
