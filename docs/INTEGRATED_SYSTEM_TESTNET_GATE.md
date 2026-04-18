# Integrated system testnet gate (dev) (CON-487)

This document defines the **full-system public-testnet gate** for the `dev` lane.

Goal: before any change is treated as eligible for **Mainnet promotion** (via `dev` -> `staged` -> `main`), we must be able to prove that the **integrated Conxian system** works end-to-end on public testnet.

Canonical trackers:

- Linear: https://linear.app/conxian-labs/issue/CON-487/define-testnet-gate-for-integrated-system-validation
- GitHub (synced thread): https://github.com/Conxian/conxius-platform/issues/511

This gate is intentionally **public-safe**:

- It defines what must be proven.
- It does not include secrets, signer identities, private endpoints, or operational procedures (ZSE).

Related policy:

- `docs/BRANCH_AND_PROMOTION_STANDARD.md`
- `docs/BRANCHING_AND_PROMOTION_POLICY.md`
- `openspec/specs/mainnet-acceptance-evidence-pack/spec.md` (required for `staged` -> `main`)

## Definitions

- **Public testnet**: Stacks Testnet (and Bitcoin Testnet/Signet where relevant) using public infrastructure, not a local simnet.
- **Integrated system**: protocol contracts + wallet signing + Gateway + Nexus + UI + platform orchestration (`conxius-platform`) working together.
- **Evidence**: commit-pinned artifacts that a reviewer can validate without access to secrets (tx ids, block heights, verifier output, sanitized logs).

## When this gate applies

This gate is required before promoting a change out of `dev` when the change can affect any of:

- Conxian protocol contract behavior or deploy plans (`Conxian/contracts/**`, `Conxian/deployments/**`).
- Wallet or signer behavior (transaction construction, signing, network selection).
- Gateway/Nexus indexing, state proof, or any production-boundary API surface.
- Platform orchestration wiring that can change what runs, how it connects, or what it points at.

If a change is documentation-only or strictly local-dev ergonomics with no runtime impact, this gate is not required.

## Evidence format (minimum)

For a `dev` PR (or a `dev` -> `staged` promotion request), attach a single “Integrated testnet validation record” that includes:

- Commit SHA(s) under validation.
- The public-testnet window used for validation (block height range).
- The contract publish set and how it was verified.
- A small list of transaction ids that exercise the required end-to-end flows.
- A short list of any deviations (and whether they are blockers).

Evidence must remain public-safe. If a supporting runbook/log contains sensitive material, store it outside git (per ZSE) and link it from Linear.

## Gate requirements (must all be satisfied)

### 1) Protocol deployment + source integrity (Stacks testnet)

Goal: prove that the intended `dev` contract set exists on-chain, and that the on-chain sources match the repo pin when required.

- [ ] The intended full-system publish set is commit-pinned in `Conxian/deployments/full-system.testnet-plan.yaml`.
- [ ] `python3 scripts/verify_testnet_deployment.py` passes against that plan (exit code `0`).
- [ ] If any contract source changed in the PR, verification is executed with `--strict-source-match` and no drift is reported.

Notes:

- This gate is about the **public testnet**, not Clarinet simnet.
- If the deploy plan changes, the plan update and its verification output are part of the required evidence.

### 2) Protocol behavior (on-chain invariants)

Goal: prove that the protocol’s safety and correctness invariants hold on testnet for the changed surface area.

- [ ] For each contract entrypoint changed, there is at least one successful public-testnet transaction exercising it.
- [ ] Access control is proven both ways for at least one sensitive action:
  - an unauthorized caller is rejected, and
  - an authorized caller succeeds.
- [ ] Fail-closed behavior is proven for at least one “integration boundary” path touched by the change (no silent success when a dependency/proof is missing).
- [ ] If any pause/isolation mechanism is in scope, the “pause blocks actions” behavior is proven on testnet.

If the change touches the CSF routing surface, include evidence for:

- [ ] `swap-router` behavior through at least one CSF-compliant integration (e.g., via `alex-adapter`).

### 3) Wallet + signer behavior

Goal: prove that real clients can construct and sign transactions correctly on testnet, without unsafe defaults.

- [ ] A wallet client successfully constructs and signs the transactions used in the protocol behavior proofs.
- [ ] Network selection is explicit (testnet is not inferred by default, and mainnet is not reachable “by accident”).
- [ ] Failure handling is validated for at least one rejected/failed transaction path (clear error surfaced; no ambiguous partial success).

Authority model alignment:

- [ ] The signer role used in testnet validation matches the BOS custody model (wallet classes and separation rules in `docs/BOS_WALLET_CONTROL_MODEL.md`).
- [ ] No launch-critical automation path depends on a personal or bootstrap wallet.

### 4) Treasury assumptions + principal resolution

Goal: ensure testnet validation reflects mainnet control assumptions (roles, vault custody, and dynamic principal resolution).

- [ ] Value-bearing custody lives in contract principals (vault/treasury contracts) rather than standard principals.
- [ ] Any role/principal resolution needed for treasury/yield operations is performed dynamically (via `operational-treasury.clar`), not by hardcoding principals in production contract sources.
- [ ] At least one treasury-adjacent flow in scope is exercised end-to-end on testnet (intent -> signed tx -> on-chain result -> indexed observation).

### 5) Deployment readiness (cross-surface)

Goal: prove that the full stack can be operated in a testnet configuration and stays healthy.

- [ ] `conxius-platform` can run a full-stack configuration wired to public testnet.
- [ ] Gateway and Nexus both:
  - start successfully,
  - remain healthy for a validation window, and
  - ingest/index the testnet transactions produced in this gate.
- [ ] Any production-boundary service surfaces fail closed when required dependencies are missing.

### 6) Cross-surface integration checks

Goal: prove that state changes are visible across surfaces (wallet/UI/API/indexers) with no “split brain.”

- [ ] After broadcasting each proof transaction, the Gateway/Nexus surfaces reflect the update (state/event/proof) without manual database intervention.
- [ ] A user-facing surface (UI or wallet) can observe the updated state using only supported APIs (no direct database reads).

## No-go conditions

Any of the following makes the gate fail:

- Any required contract in the full-system testnet plan is missing on-chain.
- Any required `--strict-source-match` check reports drift.
- Any value-bearing path silently succeeds when a dependency/proof is missing (must fail closed).
- Any testnet validation depends on a personal/bootstrap wallet for launch-critical automation.
- Any cross-surface state divergence that cannot be explained and bounded.

## Output of this gate (what “done” looks like)

This gate is considered satisfied when the evidence record exists, is public-safe, and covers all required sections above.

Promotion rule reminder: there is no direct `dev` -> `main` path. Promotion remains ordered: `dev` -> `staged` -> `main`.
