This is an audit artifact for CON-402.

Snapshot date: 2026-04-05 (UTC)

Scope (repo commit + git submodule pins at snapshot time):

- `conxian-business`: `4d98df40459927465a081f1df5e535bdd6508b16`
- `lib-conxian-core`: `2329353a1bee04c137b16b819a46e84530b2b1f4`
- `lib-conclave-sdk`: `02f3b42aeb209b57e19cfe6c68d028613ce9a65b`

Audit intent: identify testnet-only logic, mocks, placeholders, or unsafe fallbacks that can execute in production code paths ("fail open" or "silently simulate").

## Findings

### lib-conxian-core

- **Crypto stub in production API surface (high risk):** `src/musig2.rs` exposes `aggregate_public_keys()` which (at snapshot) returned the first sorted key as a placeholder aggregated key.
  - Impact: any downstream use would silently produce an invalid aggregated key (dangerous footgun for Taproot/MuSig2 flows).
  - Mainnet status: present in snapshot; should be feature-gated or fixed before any mainnet use.
  - Remediation PR: https://github.com/Conxian/lib-conxian-core/pull/30

- **Gateway engine contains multiple simulated/heuristic behaviors (mainnet readiness blocker unless explicitly gated):** `gateway/src/engine/mod.rs` includes logic labeled as simulated for:
  - on-chain reserves verification and reserve growth
  - BitVM2 health/challenge status
  - compliance checks (string contains "bad")
  - ZKML proof "verification" (string prefix check)
  - identity resolution and ERP sync
  - protocol fee metrics derived from request count
  - Impact: if deployed, these code paths can report plausible but incorrect operational/security/financial status.
  - Mainnet status: present in snapshot; should be explicitly gated to fail closed in any mainnet deployment.
  - Suggested next step: gate simulation-only paths behind an explicit build feature or runtime config that fails closed in production.

### lib-conclave-sdk

- **Mock CloudEnclave available in non-test builds (high risk):** `src/enclave/cloud.rs` is explicitly a mock implementation with a fixed dummy key and mock attestation report.
  - At snapshot, it was compiled by default via `pub mod cloud;`.
  - Mainnet status: present in snapshot; should not be available in default (production) builds.
  - Remediation PR: https://github.com/Conxian/lib-conclave-sdk/pull/22

- **Hard-coded timestamps / fixed-epoch validation (medium risk, breaks freshness invariants):** `1710000000` appeared in:
  - business attribution generation (`src/protocol/business.rs`)
  - enclave attestation reports (`src/enclave/android_strongbox.rs`, `src/enclave/cloud.rs`)
  - attribution expiration checks (`src/protocol/rails/mod.rs`)
  - Mainnet status: present in snapshot; should be removed before enforcing freshness invariants in production.
  - Remediation PR: https://github.com/Conxian/lib-conclave-sdk/pull/22

- **Attestation verification is explicitly simulated (mainnet readiness blocker):** `src/enclave/attestation.rs` notes simulated certificate chain verification and does not cryptographically validate the attestation signature.
  - Impact: a structurally valid (but forged) report can pass verification.
  - Mainnet status: present in snapshot; should be treated as a hard blocker for mainnet rail execution.
  - Suggested next step: define a strict verification contract (chain validation + signature validation + timestamp/freshness bounds) and ensure production rail execution fails closed when strict verification is unavailable.

## Notes on “staged-to-main” acceptance

For strict staged-to-main gating, the main non-negotiable safety property is that placeholder/simulated implementations must be either:

1. unbuildable in production artifacts (feature-gated), or
2. runtime-gated to fail closed with an actionable error.

In both libs above, there are several places where behavior is currently "fail open" (returns plausible output) rather than "fail closed".
