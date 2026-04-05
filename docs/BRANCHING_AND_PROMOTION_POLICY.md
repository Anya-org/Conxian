# Branching and Promotion Policy (CON-381, CON-389)

To ensure the integrity of the Conxian Production Environment, all repositories in the portfolio must adhere to the following branch model and promotion gates.

## 1. Branch Taxonomy

| Branch | Network / Scope | Rules |
| --- | --- | --- |
| `main` | **Mainnet-Only** | Only production-ready, mainnet-validated code. No stubs, mocks, or placeholders. |
| `staged` | Mainnet Candidate | Pre-production validation branch for mainnet releases. The only branch allowed to merge into `main`. |
| `dev` | **Testnet-Only** | Default development branch. Non-production validation and testnet-oriented logic. |
| `feat/*`, `fix/*` | Local/Asynchronous | Ephemeral branches for individual work. Must merge into `dev`. |

## 2. Required Promotion Path

1. **Development & Unit Testing**: All work starts on feature branches and is merged into `dev` after passing standard CI checks and unit tests.
2. **Testnet Validation**: Functional validation is performed on the `dev` branch against testnet (Stacks Testnet, Bitcoin Testnet/Signet).
3. **Staging (Promotion Candidate)**: Once testnet validation is complete, code is promoted from `dev` to `staged`.
4. **Mainnet Acceptance Evidence**: Promotion from `staged` to `main` requires a strict "Mainnet Acceptance Evidence Pack" that satisfies all requirements defined in the canonical spec: [`openspec/specs/mainnet-acceptance-evidence-pack/spec.md`](../openspec/specs/mainnet-acceptance-evidence-pack/spec.md).

   The pack typically demonstrates:
   - mainnet-only production scope
   - no stub, mock, placeholder, or testnet residue in production paths
   - successful production validation
   - release-readiness sign-off
   - clear owner accountability for the promoted code
5. **Production Merge**: Only after the evidence pack is verified can `staged` be merged into `main`. **Direct merges from `dev` to `main` are strictly prohibited.**

## 3. Enforcement (CI/CD Gates)

-- **Protected Branches**: `main` and `staged` must be protected with required reviews and passing status checks.
- **Contamination Guard**: CI suites on `main` and `staged` must run a blocking scan for and reject non-production patterns, and the scan must be explicitly scoped to avoid false positives.
  - **Scope**: Run as a required status check on pull requests targeting `main` and `staged`. Scan only production source trees (repo-defined allowlist; e.g., `contracts/**`, `src/**`).
  - **Exclusions**: Explicitly exclude `docs/**`, `audit/**`, `**/*.md`, and test/mocks/fixtures paths.
  - **Patterns**: Prefer precise patterns over broad substrings (avoid generic terms like "placeholder" unless heavily scoped). Include stable stub sentinels used across the portfolio (e.g., `[STUB]`).
  - **Example**:
    ```bash
    # Repo-defined allowlist (update these globs to match this repo's production paths)
    RG_GLOBS=(
      --glob 'contracts/**'
      --glob 'src/**'
      --glob '!**/docs/**'
      --glob '!**/audit/**'
      --glob '!**/*.md'
      --glob '!**/test/**'
      --glob '!**/tests/**'
      --glob '!**/__tests__/**'
      --glob '!**/fixtures/**'
      --glob '!**/mocks/**'
    )

    if ! rg --files "${RG_GLOBS[@]}" -- . | head -n 1 | grep -q .; then
      echo "ERROR: contamination allowlist matched no files; update the allowlist globs"
      exit 2
    fi

    if rg -n "${RG_GLOBS[@]}" -- 'MOCK_[A-Z0-9_]+|\bstub-func\b|\[STUB\]' .; then
      echo 'ERROR: non-production patterns detected in production paths'
      exit 1
    else
      status=$?
      if [ "$status" -ne 1 ]; then
        echo "ERROR: contamination scan failed (rg exit ${status})"
        exit "$status"
      fi
    fi

    # status == 1: no matches; scan passes
    exit 0
    ```
- **Submodule Integrity**: Parent repositories (like `conxian-business`) must ensure all submodules are pinned to their respective production-ready commits before merging to `main`.

---
**Verified by:** Jules (cxn-arch-guardian)
**Date:** April 5, 2026
