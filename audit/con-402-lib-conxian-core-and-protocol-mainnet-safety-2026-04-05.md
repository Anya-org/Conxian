# CON-402: Protocol mainnet safety audit (snapshot 2026-04-05)

Canonical issue: https://linear.app/conxian-labs/issue/CON-402/audit-lib-conxian-core-and-protocol-libraries-for-mainnet-safety

Remediation PRs (tracked outside this repo):

- https://github.com/Conxian/lib-conxian-core/pull/30 (merged 2026-04-05T12:19:18Z)
- https://github.com/Conxian/lib-conclave-sdk/pull/22 (merged 2026-04-05T12:17:25Z)

Snapshot date: 2026-04-05 (UTC)

Scope (repo commit + git submodule pins at snapshot time):

- `conxian-business`: `4d98df40459927465a081f1df5e535bdd6508b16`
- `lib-conxian-core`: `2329353a1bee04c137b16b819a46e84530b2b1f4`
- `lib-conclave-sdk`: `02f3b42aeb209b57e19cfe6c68d028613ce9a65b`

## Reproducibility

Prerequisites:

- Git
- Python 3.11+ (scripts are stdlib-only; no `pip install` required)
- Optional: set `GH_TOKEN`/`GITHUB_TOKEN` to avoid GitHub API rate limiting (used by `verify_submodule_integrity.py`)

From a clean checkout in the repository root:

```bash
git checkout 4d98df40459927465a081f1df5e535bdd6508b16
git submodule sync --recursive
git submodule update --init --recursive
python3 scripts/verify_knowledge_retention.py
python3 scripts/verify_submodule_integrity.py
git submodule status --recursive
```

Success criteria:

- Both Python scripts exit `0` and print `Success: ...`.
- The SHAs printed by `git submodule status --recursive` match the commit IDs listed in the `Scope` section above.

Audit intent: identify testnet-only logic, mocks, placeholders, or unsafe fallbacks that can execute in production code paths ("fail open" or "silently simulate").

## Findings

### lib-conxian-core

- **Crypto stub in production API surface:** `src/musig2.rs` exposes `aggregate_public_keys()` which (at snapshot) returned the first sorted key as a placeholder aggregated key.
  - Severity: high
  - Evidence: https://github.com/Conxian/lib-conxian-core/blob/2329353a1bee04c137b16b819a46e84530b2b1f4/src/musig2.rs#L33-L60
  - Impact: any downstream use would silently produce an invalid aggregated key (dangerous footgun for Taproot/MuSig2 flows).
  - Mainnet status: present in snapshot; should be feature-gated or fixed before any mainnet use.
  - Remediation PR: https://github.com/Conxian/lib-conxian-core/pull/30

- **Gateway engine contains multiple simulated/heuristic behaviors:** `gateway/src/engine/mod.rs` includes simulated logic in several areas.
  - Severity: high (mainnet readiness blocker unless explicitly gated)
  - Evidence:
    - on-chain reserves verification and reserve growth: https://github.com/Conxian/lib-conxian-core/blob/2329353a1bee04c137b16b819a46e84530b2b1f4/gateway/src/engine/mod.rs#L735-L743
    - BitVM2 health/challenge status: https://github.com/Conxian/lib-conxian-core/blob/2329353a1bee04c137b16b819a46e84530b2b1f4/gateway/src/engine/mod.rs#L772-L784
    - compliance checks: https://github.com/Conxian/lib-conxian-core/blob/2329353a1bee04c137b16b819a46e84530b2b1f4/gateway/src/engine/mod.rs#L925-L934
    - ZKML proof "verification": https://github.com/Conxian/lib-conxian-core/blob/2329353a1bee04c137b16b819a46e84530b2b1f4/gateway/src/engine/mod.rs#L936-L949
    - identity resolution and ERP sync: https://github.com/Conxian/lib-conxian-core/blob/2329353a1bee04c137b16b819a46e84530b2b1f4/gateway/src/engine/mod.rs#L1165-L1210
    - protocol fee metrics derived from request count: https://github.com/Conxian/lib-conxian-core/blob/2329353a1bee04c137b16b819a46e84530b2b1f4/gateway/src/engine/mod.rs#L965-L973
  - Impact: if deployed, these code paths can report plausible but incorrect operational/security/financial status.
  - Mainnet status: present in snapshot; should be explicitly gated to fail closed in any mainnet deployment.
  - Suggested next step: gate simulation-only paths behind an explicit build feature or runtime config that fails closed in production.

### lib-conclave-sdk

- **Mock CloudEnclave available in non-test builds:** `src/enclave/cloud.rs` is explicitly a mock implementation with a fixed dummy key and mock attestation report.
  - Severity: high
  - Evidence:
    - module is included by default: https://github.com/Conxian/lib-conclave-sdk/blob/02f3b42aeb209b57e19cfe6c68d028613ce9a65b/src/enclave/mod.rs#L1-L3
    - fixed dummy key + mock attestation report: https://github.com/Conxian/lib-conclave-sdk/blob/02f3b42aeb209b57e19cfe6c68d028613ce9a65b/src/enclave/cloud.rs#L9-L38
  - At snapshot, it was compiled by default via `pub mod cloud;`.
  - Mainnet status: present in snapshot; should not be available in default (production) builds.
  - Remediation PR: https://github.com/Conxian/lib-conclave-sdk/pull/22

- **Hard-coded timestamps / fixed-epoch validation:** The fixed timestamp `1710000000` (Unix timestamp = 2024-03-09T16:00:00Z) is used in multiple places.
  - Severity: medium
  - Evidence:
    - business attribution generation: https://github.com/Conxian/lib-conclave-sdk/blob/02f3b42aeb209b57e19cfe6c68d028613ce9a65b/src/protocol/business.rs#L143-L185
    - enclave attestation reports:
      - https://github.com/Conxian/lib-conclave-sdk/blob/02f3b42aeb209b57e19cfe6c68d028613ce9a65b/src/enclave/android_strongbox.rs#L79-L91
      - https://github.com/Conxian/lib-conclave-sdk/blob/02f3b42aeb209b57e19cfe6c68d028613ce9a65b/src/enclave/cloud.rs#L25-L37
    - attribution expiration checks: https://github.com/Conxian/lib-conclave-sdk/blob/02f3b42aeb209b57e19cfe6c68d028613ce9a65b/src/protocol/rails/mod.rs#L132-L154
  - Impact: fixed timestamps weaken freshness guarantees and can cause stale or replayed data to be treated as valid in production.
  - Mainnet status: present in snapshot; should be removed before enforcing freshness invariants in production.
  - Remediation PR: https://github.com/Conxian/lib-conclave-sdk/pull/22

- **Attestation verification is explicitly simulated:** `src/enclave/attestation.rs` includes a simulated certificate chain check and does not cryptographically validate the attestation signature.
  - Severity: high (mainnet readiness blocker)
  - Evidence: https://github.com/Conxian/lib-conclave-sdk/blob/02f3b42aeb209b57e19cfe6c68d028613ce9a65b/src/enclave/attestation.rs#L22-L54
  - Impact: a structurally valid (but forged) report can pass verification.
  - Mainnet status: present in snapshot; should be treated as a hard blocker for mainnet rail execution.
  - Remediation status: pending as of snapshot (no remediation PR linked in this audit).
  - Suggested next step: define a strict verification contract (chain validation + signature validation + timestamp/freshness bounds) and ensure production rail execution fails closed when strict verification is unavailable.

## Notes on “staged-to-main” acceptance

For strict staged-to-main gating, the main non-negotiable safety property is that placeholder/simulated implementations must be either:

1. unbuildable in production artifacts (feature-gated), or
2. runtime-gated to fail closed with an actionable error.

In both libs above, there are several places where behavior is currently "fail open" (returns plausible output) rather than "fail closed".
