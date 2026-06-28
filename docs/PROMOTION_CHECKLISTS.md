# Promotion checklists (feature -> dev -> staged -> main)

These checklists define the required evidence and safety assertions for promoting work through the portfolio’s environment branches.

Branch roles and the required promotion path are defined in:

- `docs/BRANCHING_AND_PROMOTION_POLICY.md`
- `docs/BRANCH_AND_PROMOTION_STANDARD.md`
- `openspec/specs/git-management/spec.md`

CI enforcement:

- `.github/workflows/branch-promotion-policy.yml` enforces the ordered promotion path.
- The same workflow enforces that PR descriptions targeting `dev`, `staged`, and `main` include the relevant checklist sections below.

## 1) Feature branch -> `dev` (local validation)

Use this checklist for PRs that merge a feature branch into `dev`.

### Feature -> dev promotion checklist

- [ ] I targeted `dev` (not `staged`/`main`) and the change is appropriate for testnet/non-production validation.
- [ ] I ran the relevant local validation for the touched areas (examples: `python3 scripts/bos_repo_check.py`, `cargo test`, `npm test`, `npm --prefix showcase-dapp run lint`).
- [ ] The PR is scoped and does not mix unrelated changes (especially across `.github/`, `openspec/`, `docs/`, `scripts/`).
- [ ] If this change touches wallets/signers/treasury/deployment surfaces, I described the change boundary and the expected runtime lane (`dev`/testnet).

## 2) `dev` -> `staged` (integrated testnet validation -> mainnet candidate)

Use this checklist for promotion PRs that move a testnet-validated change from `dev` into `staged`.

`staged` is a mainnet-candidate branch: it must be safe to promote to `main` after completing the Mainnet Acceptance Evidence Pack requirements.

### Dev -> staged promotion checklist

- [ ] Integrated testnet validation completed on `dev` and is linked here (Stacks testnet + Bitcoin testnet/signet as applicable).
- [ ] Required CI checks are green for the exact promotion candidate commit.
- [ ] Wallet / signer / treasury boundary checks are explicitly recorded:
  - no launch-critical automation depends on personal or bootstrap wallets
  - production principals are not hardcoded (contracts fetch principals dynamically where required)
  - signer scope is correct for the runtime lane (no mainnet keys used in testnet contexts)
- [ ] If this promotion includes wallet custody/signer/privacy scope, [`docs/WALLET_LIFECYCLE_CONTROL_CHECKLIST.md`](./WALLET_LIFECYCLE_CONTROL_CHECKLIST.md) is updated with `VER-1`, `VER-2`, and `REL-1` evidence for the exact candidate commit.
- [ ] Deployment boundary checks are explicitly recorded:
  - no testnet endpoints/default networks leak into production paths
  - environment-specific behavior is guarded by the branch/runtime lane (not ad-hoc conditionals)
- [ ] Any required submodule pins, lockfiles, and artifact provenance are updated for the promotion candidate.

## 3) `staged` -> `main` (mainnet acceptance)

Promotion to `main` is only allowed from `staged` and MUST include a Mainnet Acceptance Evidence Pack.

### Mainnet acceptance evidence pack

Provide the evidence pack directly in the PR description under this heading, or link to a versioned in-repo file per `openspec/specs/mainnet-acceptance-evidence-pack/spec.md`.

- [ ] If wallet custody/signer/privacy scope is included, link the completed [`docs/WALLET_LIFECYCLE_CONTROL_CHECKLIST.md`](./WALLET_LIFECYCLE_CONTROL_CHECKLIST.md) entry with `REL-2`, `OPS-1`, and `OPS-2` evidence.
