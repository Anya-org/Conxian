# Verification Checklist: Clarity 4 / Nakamoto Release Readiness

## 1. Syntax & Manifest Compliance
- [ ] All contracts in `Clarinet.toml` are set to `clarity-version = 4`.
- [ ] Project epoch is set to `3.0` in `Clarinet.toml`.
- [ ] Deployment plan (`deployments/default.simnet-plan.yaml`) updated to `epoch: "3.0"` and `clarity-version: 4`.

## 2. Primitive Verification
- [ ] **Temporal Logic**: `stacks-block-time` replaces `block-height` and `burn-block-height` for all time-locks, yield, and vesting.
- [ ] **Security**: `contract-hash?` implemented in module registry to prevent unauthorized injection.
- [ ] **Sovereignty**: `restrict-assets?` implemented in critical asset-moving functions (e.g., `vault.clar`).
- [ ] **Identity**: `secp256r1-verify` implemented in `conxian-access.clar` for Passkey support.
- [ ] **Transparency**: `to-ascii?` used in event logs for human-readable audit trails.

## 3. Module-Specific Refactors
- [ ] **Root**: `conxian-protocol.clar`, `conxian-access.clar`, `admin-facade.clar`.
- [ ] **Treasury/Yield**: `cxd-staking.clar`, `dao-treasury.clar`, `founder-vesting.clar`, `revenue-distributor.clar`.
- [ ] **DeFi**: `lending-manager.clar`, `economic-policy-engine.clar`, `swap-manager.clar`.
- [ ] **Compliance**: `regulatory-adapter.clar`.

## 4. Operational & Strategic Readiness
- [ ] Gap analysis reflects current implementation state and future Sovereign Investment risks.
- [ ] Roadmap updated to show Clarity 4 Milestone completion.
- [ ] PRD technical specs aligned with `stacks-block-time` and second-precision math.

## 5. Automated Testing
- [ ] `npm run check` passes with zero Clarity 4 syntax errors.
- [ ] `npm test` passes (once simnet/SDK environment is fully aligned with Epoch 3.0).
