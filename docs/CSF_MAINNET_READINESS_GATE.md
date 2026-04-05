# CSF mainnet readiness gate (CON-129)

This is the single canonical gate artifact for deciding **Go / Conditional Go / No-Go** for ConxianCSF mainnet launch, plus an explicit **payout-readiness** decision tied to the ALEX funding path.

Canonical trackers:

- Linear: https://linear.app/conxian-labs/issue/CON-129/csf-mainnet-readiness-gate
- GitHub (synced thread): https://github.com/Conxian/conxius-platform/issues/101

Related operating order + cross-domain proof gates:

- `docs/CSF_FIRST_OPERATING_SEQUENCE_AND_PROOF_GATES.md` (CON-426)

## Current gate status (snapshot)

**As of:** 2026-04-04

- **Launch recommendation:** `No-Go`
- **Payout readiness (ALEX-funded bounties):** `Not payout-ready`

Rationale (high level): multiple launch-critical checks are not yet evidenced as complete, and the ALEX-funded payout path is explicitly gated on mainnet deployment completion.

Explicit payout readiness rule:

- **No payout-ready commitments** until:
  1. ConxianCSF is fully deployed on Stacks mainnet via the ALEX path, and
  2. the ALEX vault funding source is verified as the sole bounty funding source.

### Evidence snapshot (repo pins)

This repo pins the following dependency SHAs via submodules (commit: `0e8b8eeddf8beee842234681e3e65123896ac7fc`):

- `Conxian` @ `d1bfeeba963fbb5f35f00ed748f136c8ea6687e6` (https://github.com/Conxian/Conxian)
- `lib-conxian-core` @ `2329353a1bee04c137b16b819a46e84530b2b1f4` (https://github.com/Conxian/lib-conxian-core)
- `conxius-platform` @ `d57efecb273fa5e28c0f3ddbf6d20434f0113ef1` (https://github.com/Conxian/conxius-platform)
- `conxian-gateway` @ `f8eefa8970381c77e422919adfc1c91f336fac10` (https://github.com/Conxian/conxian-gateway)
- `conxius-wallet` @ `fc56d889634a020de05dd69b22bf119bf72961d0` (https://github.com/Conxian/conxius-wallet)

Additional pinned repos (supporting surfaces):

- `conxian-ui` @ `bf64c3587f173f1d00404990471255a62a8d7d2d` (https://github.com/Conxian/Conxian_UI)
- `conxian-nexus` @ `f30d5f0581bb944c3d7db3327e2d626a5445db41` (https://github.com/Conxian/conxian-nexus)
- `conxian-labs-site` @ `1c3043e7eed31afd8e47429e2749a28f297aeae9` (https://github.com/Conxian/conxian-labs-site)
- `lib-conclave-sdk` @ `02f3b42aeb209b57e19cfe6c68d028613ce9a65b` (https://github.com/Conxian/lib-conclave-sdk)
- `stacksorbit` @ `ab079ec6ca246d686ea152531e96911880dd9520` (https://github.com/Conxian/stacksorbit)

## Working rules (enforced by this gate)

- Classify dependencies as **blocker**, **supporting**, or **unrelated**.
- Only expose work as **bounty-ready** when it is scoped for external contribution.
- Do not treat synced comments as claim events without automation.
- Assume no dedicated bounty budget is approved unless explicitly funded through the ALEX launch path.
- Until ConxianCSF is fully deployed via ALEX on the Stacks blockchain, do not treat bounty issues as payout-ready commitments.
- Once deployment is complete, align bounty claims, approvals, and payouts through the deployed ConxianCSF system and the ALEX-funded treasury path.

## Dependency classification (current snapshot)

### Blockers

- Mainnet launch program (internal): https://linear.app/conxian-labs/issue/CON-10/mainnet-launch
- Mainnet checklist (internal): https://linear.app/conxian-labs/issue/CON-7/mainnet-checklist
- Admin principal centralization risk remediation (security): https://linear.app/conxian-labs/issue/CON-61/security-remediate-hardcoded-admin-principal-centralization-risk
- ConxianCSF internal wallet + ALEX deployment readiness (signers + treasury wiring): https://linear.app/conxian-labs/issue/CON-136/conxiancsf-internal-wallet-and-alex-deployment-readiness
- Fix mainnet deploy plan principals (mainnet uses `SP...`, not testnet `ST...`): https://linear.app/conxian-labs/issue/CON-371/fix-mainnet-release-plan-principals-stsp
- Remove tracked runtime config / artifacts in Conxian (includes `.env`): https://linear.app/conxian-labs/issue/CON-183/secret-and-artifact-cleanup-conxian
- Verify wallets, signers, and approval controls for launch: https://linear.app/conxian-labs/issue/CON-233/verify-wallets-signers-and-approval-controls-for-launch
- Align security/incident contact inbox across repos: https://linear.app/conxian-labs/issue/CON-374/align-securityincident-contact-inbox-across-repos
- Confirm bounty funding and payout activation for mainnet (ALEX path): https://linear.app/conxian-labs/issue/CON-230/confirm-bounty-funding-and-payout-activation-for-mainnet
- Dependency drift risk (lib consolidation): https://linear.app/conxian-labs/issue/CON-67/infra-consolidate-lib-conxian-core-to-prevent-dependency-drift

### Supporting

- Vault deployment research: https://linear.app/conxian-labs/issue/CON-54/ops-research-clarity-contract-deployment-for-vaults
- ZKML verification in gateway (DeFi-adjacent, not required for minimal CSF deploy unless explicitly included in the release plan): https://linear.app/conxian-labs/issue/CON-70/issue-001-integrate-zkml-verification-in-gateway-guardian-attestation
- Clarity sharding logic (guardian): https://linear.app/conxian-labs/issue/CON-71/issue-002-implement-clarity-sharding-logic-guardian-sovereignty

### Unrelated (defer)

- Offline-first POS sync: https://linear.app/conxian-labs/issue/CON-78/con-75-bounty-gateway-edge-offline-first-pos-sync

### Missing dependency references (must be reconciled)

The CON-129 description previously referenced issues that no longer exist in Linear (confirmed as of 2026-04-04) (`CON-130`, `CON-64`, `CON-65`, `CON-79`).

Track replacements and/or removals under: https://linear.app/conxian-labs/issue/CON-375/reconcile-deleted-issue-refs-in-con-129-con-130646579

Treat CON-375 as a **documentation blocker** for this gate until the replacements/removals are fully reconciled.

## Bounty-ready subset (externalizable candidates only)

Only mark work bounty-ready when it is:

1. tightly scoped,
2. unblocked by internal secrets/config/deployment steps, and
3. reviewable via a linked PR + verification evidence.

Current candidates based on assignment + scope (not payout-ready until the ALEX path is verified):

- https://linear.app/conxian-labs/issue/CON-67/infra-consolidate-lib-conxian-core-to-prevent-dependency-drift
- https://linear.app/conxian-labs/issue/CON-54/ops-research-clarity-contract-deployment-for-vaults

## Mainnet deployment stages (checklist)

### 1) Code and dependency readiness

- [ ] All direct mainnet-supporting repos reviewed (`Conxian/Conxian`, `lib-conxian-core`, `conxius-platform`, `conxian-gateway`, wallet-facing components).
- [ ] No P0 secret, governance, or tracked-artifact blockers remain.
- [ ] Dependency alignment confirmed across pinned SHAs (see “Evidence snapshot”).
- [ ] All dependency issues referenced by the CON-129 gate exist in Linear (or have explicit replacement links recorded), and this document is updated accordingly.

### 2) Test readiness

- [ ] Unit / integration / contract / smoke tests pass on release candidates.
- [ ] No known failing CI checks remain on deployment branches.
- [ ] Post-build artifacts are reproducible and not committed to source control.

### 3) Security and config readiness

- [ ] No tracked `.env` or other secret-bearing runtime config remains in any mainnet-supporting repo (only template/example files are committed).
- [x] This repo currently satisfies the above (only `.env.example` is tracked).
- [ ] Deployment keys, signer paths, and wallet ownership model confirmed internally (no secrets committed).
- [ ] Admin principal and centralization-risk items remediated or explicitly accepted before go-live.

### 4) Network and deployment readiness

- [ ] ALEX deployment prerequisites complete.
- [ ] Stacks network target, fee assumptions, deployment sequencing, and rollback plan defined.
- [ ] Testnet-to-mainnet gaps reconciled (principals, config, and any network-specific assumptions).
- [ ] Preflight checks, post-deploy verification checks, and monitoring expectations documented.

Canonical deployment plan (must be commit-pinned in the go/no-go record):

- `Conxian/deployments/mainnet-release-plan.yaml`

### 5) Funding and payout readiness

- [ ] ALEX launch source of funds confirmed as the only bounty funding path.
- [ ] Payout contract path, approval controls, and operating rules documented.
- [ ] No bounty issue marked payout-ready until both mainnet deployment and ALEX funding path are verified.

For the maintainer-only payout enablement procedure (ALEX-funded), follow:

- `docs/bounties/MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md`

## Claim workflow constraints (until automation)

- Do not treat synced issue comments (Linear/GitHub) as claim events.
- Require a linked PR/commit/diff + verification evidence for any work that is treated as “submitted”.

### 6) Go / No-Go decision

- [ ] All P0 blockers closed.
- [ ] All required tests passing.
- [ ] All network/deployment checks complete.
- [ ] Launch recommendation explicitly recorded as `Go`, `Conditional Go`, or `No-Go` (with evidence links).
