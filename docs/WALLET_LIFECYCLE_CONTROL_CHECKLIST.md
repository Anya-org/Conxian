# Wallet Lifecycle Control Checklist — `conxius-wallet` (CON-697)

## Status

Canonical lifecycle-control evidence template for wallet `Verify`, `Release`, and `Operate` gates.

## Purpose

Use this checklist to capture commit-pinned evidence for wallet lifecycle controls before promotion and while operating the lane.

- Scope: `conxius-wallet` custody, signer, release, and rollback control evidence.
- Applies to lifecycle gates: `VER-1`, `VER-2`, `REL-1`, `REL-2`, `OPS-1`, `OPS-2`.
- Keep evidence public-safe (ZSE aligned); link sensitive records via approved private governance channels.

## Canonical cross-references

- Operating-model authority: [`docs/OPERATING_MODEL_LIFECYCLE_CONTROL_OWNERSHIP.md`](./OPERATING_MODEL_LIFECYCLE_CONTROL_OWNERSHIP.md)
- Promotion requirements: [`docs/PROMOTION_CHECKLISTS.md`](./PROMOTION_CHECKLISTS.md)
- Verify gate references:
  - [`docs/COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md`](./COMPATIBILITY_MATRIX_AND_ACCEPTANCE_GATE_CHECKLIST.md)
  - [`docs/DEPLOYMENT_VERIFICATION_MATRIX.md`](./DEPLOYMENT_VERIFICATION_MATRIX.md)
- Release and readiness references:
  - [`docs/BRANCH_AND_PROMOTION_STANDARD.md`](./BRANCH_AND_PROMOTION_STANDARD.md)
  - [`docs/MAINNET_READINESS_CONXIUS_WALLET.md`](./MAINNET_READINESS_CONXIUS_WALLET.md)
- Operate references:
  - [`docs/WALLET_SIGNER_CONTROL_VERIFICATION_REPORT.md`](./WALLET_SIGNER_CONTROL_VERIFICATION_REPORT.md)
  - [`docs/operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md`](./operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md)
  - [`docs/operations/CON-681_PHASE6_ROLLBACK_DRILL_SIMULATION.md`](./operations/CON-681_PHASE6_ROLLBACK_DRILL_SIMULATION.md)

## Verify gate (`VER-1`, `VER-2`)

### `VER-1` — Compatibility gate evidence

- [ ] Candidate commit SHA (exact):
- [ ] Compatibility matrix evidence link:
- [ ] Boundary/interface acceptance evidence link:
- [ ] Reviewer/approver:
- [ ] Date (UTC):

### `VER-2` — Runtime-lane deployment verification evidence

- [ ] Runtime lane (`dev` / `staged` / `main`):
- [ ] Deployment verification matrix evidence link:
- [ ] Build/test/security verifier output link:
- [ ] Rollback preflight evidence link:
- [ ] Reviewer/approver:
- [ ] Date (UTC):

## Release gate (`REL-1`, `REL-2`)

### `REL-1` — Promotion checklist evidence

- [ ] Promotion PR/change record link:
- [ ] Completed promotion-checklist evidence link:
- [ ] Branch lane transition (`dev` -> `staged` or `staged` -> `main`):
- [ ] Reviewer/approver:
- [ ] Date (UTC):

### `REL-2` — Release notes and readiness linkage

- [ ] Release notes/changelog record link:
- [ ] Mainnet acceptance evidence pack link (required for `staged` -> `main`):
- [ ] Mainnet readiness update link ([`docs/MAINNET_READINESS_CONXIUS_WALLET.md`](./MAINNET_READINESS_CONXIUS_WALLET.md)):
- [ ] Candidate commit SHA (exact):
- [ ] Reviewer/approver:
- [ ] Date (UTC):

## Operate gate (`OPS-1`, `OPS-2`)

### `OPS-1` — Runbook ownership and escalation evidence

- [ ] Named runbook owner(s):
- [ ] Escalation path record link:
- [ ] Wallet signer control report linkage ([`docs/WALLET_SIGNER_CONTROL_VERIFICATION_REPORT.md`](./WALLET_SIGNER_CONTROL_VERIFICATION_REPORT.md)):
- [ ] Reviewer/approver:
- [ ] Date (UTC):

### `OPS-2` — Rollback trigger and deterministic recovery evidence

- [ ] Rollback trigger definition link:
- [ ] Rollback drill/simulation evidence link:
- [ ] Last-known-good recovery evidence link:
- [ ] Post-rollback validation evidence link:
- [ ] Reviewer/approver:
- [ ] Date (UTC):

## Evidence quality rules

- Link immutable identifiers whenever possible (commit SHA, CI run URL, artifact digest, txid).
- If supporting records contain sensitive data, store privately and add a public-safe reference token/link.
- Checklist completion is mandatory for wallet release candidates that touch custody/signer/privacy boundaries.
