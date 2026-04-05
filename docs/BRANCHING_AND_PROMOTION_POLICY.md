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
4. **Mainnet Acceptance Evidence**: Promotion from `staged` to `main` requires a strict "Mainnet Acceptance Evidence Pack" that satisfies all controls defined in the canonical spec: [`openspec/specs/mainnet-acceptance-evidence-pack/spec.md`](../openspec/specs/mainnet-acceptance-evidence-pack/spec.md).

   The pack typically demonstrates:
   - mainnet-only production scope
   - no stub, mock, placeholder, or testnet residue in production paths
   - successful production validation
   - release-readiness sign-off
   - clear owner accountability for the promoted code
5. **Production Merge**: Only after the evidence pack is verified can `staged` be merged into `main`. **Direct merges from `dev` to `main` are strictly prohibited.**

## 3. Enforcement (CI/CD Gates)

- **Main Branch Protection**: `main` must be protected with required reviews and passing status checks.
- **Contamination Guard**: CI suites on `main` and `staged` must scan for and reject "MOCK_", "stub-func", "placeholder", and other non-production patterns.
- **Submodule Integrity**: Parent repositories (like `conxian-business`) must ensure all submodules are pinned to their respective production-ready commits before merging to `main`.

---
**Verified by:** Jules (cxn-arch-guardian)
**Date:** April 5, 2026
