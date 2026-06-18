# CI/CD Infrastructure Triage Report (June 2026)

## Overview
As part of the "protocol-first" narrowing and hardening cycle, a comprehensive triage of the repository's CI/CD infrastructure was conducted to resolve failing checks and align with the portfolio architecture.

## 1. Repaired Workflows
- **Invalid Checkout Version**: Resolved issues in `dependency-review.yml` and `sovereign-guard.yml` where `actions/checkout@v6` was being used (invalid version). These have been pinned to `v4`.
- **UI Validation Gap**: Implemented `conxian-ui-ci.yml` to provide dedicated PR validation for the `ui/` directory, ensuring builds and tests are enforced before merge.
- **Sovereign Guard**: Verified that the Contamination Guard (`scripts/verify_contamination_guard.py`) correctly excludes the `ui/` and `gateway/` subtrees from principal leakage checks to allow for devnet-specific configurations.

## 2. Test Environment Status (Simnet)
- **Status**: TECHNICAL BETA
- **Issues**: A known "Simulation Gap" exists where Clarity 4 keyword shims and certain cross-contract dependency resolutions (e.g., `alex-adapter` -> `conxian-protocol`) fail in the current sandbox environment despite correct TOML configuration.
- **Root Cause**: The Simnet/Clarinet SDK environment in the sandbox occasionally fails to resolve internal contract calls when using the `Proxy` initialization pattern in `tests/setup-test-env.ts`.
- **Mitigation**: Critical logic verification should be performed using `clarinet check` and manual `clarinet console` validation until the Simnet SDK stability improves.

## 3. Narrowing Triage
- **Gateway Subtree**: Triage confirmed that the `gateway/` subtree contains runtime concerns (Express, ISO 20022 parsing) that belong in a dedicated service repository.
- **UI Subtree**: The `ui/` directory has been initialized with a protocol-facing reference and CI enforcement, awaiting relocation.

## 4. Failing Check Resolution (External Repos)
- **conxius-platform**: Checks for `synergy-test`, `Server (Full Stack)`, and `Cloud (Blueprint validation)` were identified as failing in the `conxius-platform` repository.
- **Triage Recommendation**: These failures likely stem from the same "Simulation Gap" or dependency drift identified in the protocol core. Relocating these runtime concerns to dedicated repos will simplify their CI environment and restore a clean pass/fail signal.
