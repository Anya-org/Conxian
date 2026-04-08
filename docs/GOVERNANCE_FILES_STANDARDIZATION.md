# Governance files standardization (public repos)

This document defines a baseline set of governance files and expected section structure for Conxian public repositories.

Baselines:

- Conxian org defaults repo: https://github.com/Conxian/.github
- Conxian orchestration repo: https://github.com/Conxian/conxius-platform

The goal is consistent discoverability for contributors and auditors (security contact, contribution rules, ownership, release discipline), while allowing explicit, documented exceptions per repository.

## Baseline file set

Public repositories should include the following files at the repository root:

- `README.md`
- `LICENSE`
- `SECURITY.md`
- `CONTRIBUTING.md`
- `CODEOWNERS`

If the repository publishes tagged releases, it should also include:

- `RELEASING.md`

## Expected structure

### README.md

Recommended sections (in order):

1. One-paragraph description and a single role line (Flagship/Supporting).
2. Purpose
3. Status
4. Ownership (link to `CODEOWNERS` — typically `CODEOWNERS`, `.github/CODEOWNERS`, or `docs/CODEOWNERS`)
5. Audience
6. Relationship to the Conxian stack (or subsystem map)
7. Quick start (only if the repo is runnable)
8. Governance and security (links to the files below)

### SECURITY.md

Required sections:

- Support policy (what branches/releases receive security fixes)
- Reporting a vulnerability (private channels only)
- Disclosure policy (coordination expectations)

### CONTRIBUTING.md

Required sections:

- Scope of the repository (what belongs here vs other repos)
- Getting started
- Branching and promotion rules (or a link to the canonical doc)
- Pull request process
- Security issues (link to `SECURITY.md`)
- Releases and versioning (link to `RELEASING.md` if present)

### CODEOWNERS

Required:

- Global owners for `*`.
- Explicit owners for high-risk areas (for example, governance files, CI/workflows, security policy, and production-critical paths).

## Justified exceptions

When a repository differs from the baselines, the exception should be explicitly documented in the repo (typically in `README.md` under "Governance and security") and justified.

Common examples:

- **License**: Some repos are MIT, others are GPL/BSL based on their role.
- **Release guidance**: Repos that do not publish tags/releases can omit `RELEASING.md` but should still document how changes are shipped.
- **CODEOWNERS shape**: Repos may use GitHub teams if they exist; otherwise use individual maintainers.

## Conxian-business exceptions

This repository (`conxian-business`) intentionally differs from the MIT baselines because:

- It is licensed under GPL v3.0.
- It is a governance/specs source of truth and includes a public/private boundary section aligned to Zero Secret Egress (ZSE).
