# Proposal: Enforce proposal-only external settlement triggers in TEE

This change formalizes the rule that ISO 20022 / PAPSS / BRICS settlement messages are **never** direct execution authority.

## Scope

1. External settlement messages are accepted as **trigger material only**.
2. A proposal may be emitted **only** after TEE verification (Conclave / StrongBox / CloudTEE floor).
3. On verified trigger, start the **standard 144-block timelock** for the mapped digital asset path.
4. Preserve existing multi-sig approvals and downstream yield routing (5/5/90 productive streaming).

## Non-goals

- Introducing a new execution lane that bypasses the existing proposal → timelock → multisig → execution lifecycle.
- Embedding executable contract call payloads inside TradFi messages.

## Acceptance criteria (implementation-facing)

1. **Proposal-only**: a verified external settlement produces a proposal artifact; it cannot execute funds movement directly.
2. **Timelock**: the timelock start and release heights match the current native path (`+144` blocks).
3. **Multi-sig**: multi-sig approvals remain mandatory (no “fast path”).
4. **TEE floor**: proposal emission requires a verifiable TEE/StrongBox/CloudTEE attestation.
5. **Yield invariant**: yield routing outputs are unchanged (native vs external-triggered lock event are identical).
6. **Boundary tests** exist for parsing/attestation/execution separation (see `design.md`).
7. **Normative requirements** and negative tests are captured in `specs/external-settlement-proposal-only-tee/spec.md`.
