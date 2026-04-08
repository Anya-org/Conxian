# Branch and promotion standard (dev/staged/main)

This repository (and the broader Conxian portfolio) uses a three-branch model to keep testnet validation, mainnet candidate validation, and mainnet production releases cleanly separated.

## Branch roles

- `dev`: testnet-only and non-production validation.
- `staged`: mainnet candidate validation.
- `main`: mainnet-only production code.

## Promotion rules

- Allowed promotion path: `dev` -> `staged` -> `main`.
- Emergency hotfix path: `hotfix/*` -> `staged` -> `main`.
- Direct promotion from `dev` to `main` is not allowed.
- Promotions into `staged` or `main` must originate from an in-repo branch (not a fork).

In practice, “promotion” means opening a pull request from the source branch into the target branch.

## Standard workflow

1. Create a feature branch from `dev`.
2. Open a PR into `dev` and validate the change in a testnet/non-production context.
3. When the change is a mainnet candidate, open a promotion PR from `dev` into `staged`.
4. After mainnet-candidate validation completes and approvals are in place, open a promotion PR from `staged` into `main`.

For emergency fixes, open a promotion PR from `hotfix/*` into `staged`, then promote `staged` into `main`.

## Enforcement

### Ownership and business-unit boundaries

`CODEOWNERS` is the source of truth for review routing.

- Any change that crosses a business-unit boundary or touches governance/release-policy surfaces (`openspec/`, `.github/`, `docs/`, `scripts/`) must receive review from the owners defined in `CODEOWNERS`.

### CI and branch protections

GitHub Actions provides the check surface; branch protection rules decide what is required.

At a minimum:

- `staged` and `main` should require the repo hygiene suite and the branch promotion policy check.
- `main` should require all mainnet-acceptance checks relevant to the changed business unit(s).

Reference: `.github/RELEASE_HYGIENE.md`.
