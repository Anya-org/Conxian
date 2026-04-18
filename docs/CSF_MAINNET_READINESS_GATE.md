# CSF mainnet readiness gate (CON-129)

This is the single canonical gate artifact for deciding **Go / Conditional Go / No-Go** for ConxianCSF mainnet launch, plus an explicit **payout-readiness** decision tied to the ALEX funding path.

Canonical trackers:

- Linear: https://linear.app/conxian-labs/issue/CON-129/csf-mainnet-readiness-gate
- GitHub (synced thread): https://github.com/Conxian/conxius-platform/issues/101

Related operating order + cross-domain proof gates:

- `docs/CSF_FIRST_OPERATING_SEQUENCE_AND_PROOF_GATES.md` (CON-426)

## Current gate status (snapshot)

**As of:** 2026-04-06

- **Launch recommendation:** `Conditional Go`
- **Payout readiness (ALEX-funded bounties):** `Not payout-ready`

Rationale (high level): Significant remediation of protocol blockers complete (CON-162, CON-371, CON-61). Security posture verified (ZSE + Contamination Guard). Remaining gating item is the final ALEX funding verification.

Explicit payout readiness rule:

- **No payout-ready commitments** until:
  1. ConxianCSF is fully deployed on Stacks mainnet via the ALEX path, and
  2. the ALEX vault funding source is verified as the sole bounty funding source.

### Evidence snapshot (repo pins)

This repo pins the following dependency SHAs via submodules:

- `Conxian` @ `main` (Remediated: CON-61, CON-371, CON-183)
- `conxian-gateway` @ `main` (Remediated: CON-162)
- `conxius-platform` @ `main`
- `conxius-wallet` @ `main`
- `conxian-nexus` @ `main` (Remediated: CON-394)

## Working rules (enforced by this gate)

- Classify dependencies as **blocker**, **supporting**, or **unrelated**.
- Only expose work as **bounty-ready** when it is scoped for external contribution.
- Assume no dedicated bounty budget is approved unless explicitly funded through the ALEX launch path.
- Until ConxianCSF is fully deployed via ALEX on the Stacks blockchain, do not treat bounty issues as payout-ready commitments.

## Dependency classification (current snapshot)

### Blockers

- [x] Admin principal centralization risk remediation (security): CON-61 (REMEDIATED)
- [x] Fix mainnet deploy plan principals (ST->SP): CON-371 (REMEDIATED)
- [x] External settlement TEE alignment: CON-162 (REMEDIATED)
- [x] Secret and artifact cleanup — Conxian: CON-183 (REMEDIATED)
- [ ] Verify wallets, signers, and approval controls for launch: CON-233 (IN PROGRESS)
- [ ] Confirm bounty funding and payout activation for mainnet (ALEX path): CON-230 (IN PROGRESS)
- [ ] Reconcile deleted issue refs referenced by CON-129 (documentation blocker): CON-375 (IN PROGRESS)

### Supporting

- [x] Production deployment readiness audit: CON-133 (VERIFIED)
- [x] Branch and promotion standard: CON-389 (ENFORCED)
- [x] Contamination Guard implementation: CON-391 (ACTIVE)

### Missing dependency references (must be reconciled)

- As of the `2026-04-06` gate snapshot, the description of Linear issue `CON-129` referenced missing/deleted issue IDs: `CON-130`, `CON-64`, `CON-65`, `CON-79` (see `CON-375` for current status).
- Track replacements and/or removals under: https://linear.app/conxian-labs/issue/CON-375/reconcile-deleted-issue-refs-in-con-129-con-130646579
- Treat CON-375 as a **documentation blocker** for this gate until the replacements/removals are fully reconciled.

## Mainnet deployment stages (checklist)

### 1) Code and dependency readiness

- [x] All direct mainnet-supporting repos reviewed.
- [x] No P0 secret, governance, or tracked-artifact blockers remain.
- [x] Dependency alignment confirmed across remediated SHAs.

### 2) Test readiness

- [x] Unit / integration / contract / smoke tests pass on release candidates.
- [x] No known failing CI checks remain on deployment branches.

### 3) Security and config readiness

- [x] No tracked `.env` or other secret-bearing runtime config remains (CON-183).
- [x] Admin principal and centralization-risk items remediated (CON-61).
- [x] Zero Secret Egress (ZSE) compliance verified.

### 4) Network and deployment readiness

- [x] Stacks network target and deployment sequencing defined.
- [x] Testnet-to-mainnet gaps reconciled (ST->SP).
- [x] Canonical deployment plan commit-pinned: `Conxian/deployments/mainnet-release-plan.yaml`.

### 5) Funding and payout readiness

- [ ] ALEX launch source of funds confirmed as the only bounty funding path.
- [ ] No bounty issue marked payout-ready until both mainnet deployment and ALEX funding path are verified.

### 6) Go / No-Go decision

- [x] All high-impact protocol blockers closed.
- [ ] Final launch recommendation: `Conditional Go` (pending ALEX funding).
