# Repo readiness gates by control domain (CON-227)

This page defines the **minimum control gates** required for each active flagship and supporting Conxian repository (see [repo portfolio](./REPO_PORTFOLIO.md)), so we can consistently decide:

- what is safe to keep **public**,
- what can **ship** (be deployed / released) without additional controls,
- what must remain **private** (kept in Linear under ZSE), and
- what needs **additional controls** before rollout.

Canonical tracker:

- Sovereign Coordination Layer: https://sovereign.conxian.com/issue/CON-227/map-repo-readiness-gates-by-control-domain

## Current status

**Status:** Living document. `CODEOWNERS`-designated maintainers and control-domain owners should update this mapping whenever a repo is added, renamed, retired/archived, or when gate requirements change. Recommended: require review from the owners listed for this file in `CODEOWNERS`.

**Recency:** Use Git history for this file to see when the mapping was last updated.

This document defines the _required gates_ by repo and does **not** claim that those gates are already satisfied.

## How to use this document

1. For a repo, locate its row in the mapping section.
2. For each control domain, treat the required gate level as **release-blocking** for production rollout.
3. A repo can remain public if it meets **Public-safe baseline gates** (below) and does not contain ZSE-restricted content.

### Public-safe baseline (applies to all repos)

All repos (public or private) must satisfy:

- No secrets / keys / seed phrases / private endpoints committed (`.env.example` only).
- No ZSE-restricted content tracked (validated via repo-hygiene CI checks for ZSE knowledge retention).
- `SECURITY.md` present and accurate reporting flow.
- `CODEOWNERS` covers the repo and its high-risk paths.

## Control domains and gate levels

Gate levels are intentionally coarse. Use them to prevent “we can ship” ambiguity.

Legend:

- `0` = not applicable for this repo
- `1` = baseline controls
- `2` = elevated controls (security/compliance review required)
- `3` = critical controls (formal sign-off + multi-party operating controls)

> Use level `0` only after the domain has been explicitly assessed as having no meaningful exposure for that repo, with a linkable rationale in repo docs (for example, `docs/control-domains.md` or a "Repo readiness gates" section in `README.md`). When in doubt, default to at least level `1` and escalate to the relevant control-domain owner for a decision; never use `0` as a placeholder when you're unsure.

Unless otherwise specified, gate levels are cumulative: level `N` assumes the controls of all lower non-zero levels (`1..N-1`) are also in place.

### L — Legal / public-safe status

- **L1**: License clarity (SPDX-compatible where possible), contributor guidance, and a public-safe README (no claims that contradict repo visibility).
- **L2**: Explicit user-facing disclaimers (where relevant), trademark/IP review of names/logos, and third-party dependency/license review.
- **L3**: Formal legal sign-off before production rollout and any public “regulated” positioning.

### RC — Regulatory / compliance controls

- **RC1**: Clear scope boundaries (“not legal advice”, “not a compliance guarantee”), plus audit-friendly logging where applicable.
- **RC2**: Documented compliance control surface (e.g., sanctions screening hooks, policy-driven allow/deny lists, retention/audit logs).
- **RC3**: Named compliance owner + evidence trail for changes (change-control, approvals, external review where required).

### FT — Funds / treasury impact

- **FT1**: No funds can be moved; only mocks/simulations/test fixtures.
- **FT2**: Can construct/sign transactions on testnet or in isolated/dev contexts; requires key-handling docs and “no mainnet by default”.
- **FT3**: Any codepath that can move or authorize **mainnet** value; requires multi-sig / dual-control approvals, separation of duties, and an incident runbook.

### OC — On-chain execution risk

- **OC1**: Read-only chain interactions.
- **OC2**: Can deploy/upgrade on testnets or can submit transactions to production networks behind explicit flags.
- **OC3**: Mainnet deployment/upgrade tooling or protocol contracts; requires preflight checks, staged rollout plan, and security review/audit evidence.

### DC — Decentralization / custody posture

- **DC1**: Explicitly non-custodial posture; keys remain user-controlled; recovery model documented.
- **DC2**: Key material handled on-device/in-app (wallet-grade security expectations); requires threat model + secure storage and signing boundaries.
- **DC3**: Custodial or delegated custody model; requires formal custody policy, licensing/compliance posture, and operating controls.

### DR — Deployment readiness

- **DR1**: Build/run instructions + minimal smoke path.
- **DR2**: CI checks, versioning/release tags, and environment/secrets hygiene.
- **DR3**: Production runbook: monitoring, rollback, incident response, and change-control.

### OWN — Business-operating ownership

- **OWN1**: Named maintainers (`CODEOWNERS`) and repo mission.
- **OWN2**: Operating owner (service owner / product owner), escalation path, and basic SLO expectations.
- **OWN3**: RACI defined for high-risk operations (treasury, deployments, custody) and multi-party approval requirements.

## Repo mapping (required gates)

Notes:

- “Public posture” is about **GitHub visibility**, not production readiness.
- “Ship posture” is about whether the repo can be used to **deploy / release** without extra controls.

### Flagship repos (public trust surface)

| Repo | Public posture | Ship posture | L | RC | FT | OC | DC | DR | OWN |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `conxius-wallet` | Public (required) | Conditional (wallet-grade gates) | 2 | 2 | 3 | 2 | 2 | 3 | 3 |
| `conxian-gateway` | Public (required) | Conditional (service gates) | 2 | 2 | 2 | 2 | 1 | 3 | 2 |
| `Conxian` | Public (required) | Conditional (protocol gates) | 2 | 2 | 3 | 3 | 1 | 3 | 3 |
| `Conxian_UI` | Public | Conditional (UI gates) | 2 | 1 | 2 | 1 | 1 | 2 | 2 |
| `conxian-labs-site` | Public | Ship (standard web) | 1 | 0 | 0 | 0 | 0 | 2 | 1 |
| `conxius-platform` | Public | Conditional (ops/dev-stack gates) | 1 | 1 | 2 | 2 | 1 | 2 | 2 |

_Columns: L = Legal/public-safe, RC = Regulatory/compliance, FT = Funds/treasury impact, OC = On-chain execution risk, DC = Decentralization/custody posture, DR = Deployment readiness, OWN = Business-operating ownership._

### Supporting repos

Superproject note: `Conxian_UI` is checked out at path `conxian-ui/` (planned rename tracked in CON-238).

| Repo | Public posture | Ship posture | L | RC | FT | OC | DC | DR | OWN |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `lib-conxian-core` | Public | Ship (library) | 1 | 0 | 0 | 0 | 0 | 2 | 1 |
| `lib-conclave-sdk` | Public | Conditional (crypto/supply-chain gates) | 1 | 0 | 0 | 0 | 0 | 2 | 2 |
| `conxian-nexus` | Public | Conditional (service gates) | 1 | 2 | 1 | 1 | 0 | 3 | 2 |
| `conxius_orbit` | Public | Conditional (deployment tool gates) | 1 | 1 | 3 | 3 | 0 | 3 | 3 |
| `.github` | Public | Conditional (org-infra / high-blast-radius, elevated review) | 1 | 0 | 0 | 0 | 0 | 2 | 1 |
| `conxian-business` | Public | Ship (docs/specs) | 1 | 1 | 0 | 0 | 0 | 2 | 1 |

_Columns: L = Legal/public-safe, RC = Regulatory/compliance, FT = Funds/treasury impact, OC = On-chain execution risk, DC = Decentralization/custody posture, DR = Deployment readiness, OWN = Business-operating ownership._

## Interpretation / decisions

### What can ship without additional controls

Repos that can generally ship without additional org-level gates beyond the per-domain levels in this table:

- have a Ship posture of `Ship (...)` (not `Conditional (...)`)
- have no control domain at level `3` (all are `0–2`)

These repos still must meet the public-safe baseline and standard engineering hygiene (for example, no secrets in the repo and basic CI checks).

### What must stay private (content-level, not necessarily repo-level)

Regardless of repo visibility, the following content **must not be tracked in GitHub** and should live in Linear under ZSE:

- treasury signing procedures, key custody details, seed phrases, private endpoints
- partner/customer confidential details
- internal M&A / strategy artifacts that create asymmetric risk

### What needs additional controls before rollout

Any repo with `FT = 3` and/or `OC = 3` is “break-glass” territory and needs formal operating controls before production rollout (for on-chain repos, this includes mainnet rollout).

Service surfaces (for example, repos that expose a production-facing network service, such as `conxian-gateway` and `conxian-nexus`) with `RC >= 2` and `DR >= 3` require an operating owner + incident posture before production use.

## Follow-ups (recommended)

1. `conxius-wallet` posture confirmed as non-custodial; keep `DC = 2` to reflect wallet-grade on-device key handling and signing boundaries.
2. Add a lightweight “evidence” section per flagship repo (links to CI, release tags, runbooks in Linear) without embedding sensitive details.
3. Reconcile public messaging in the `conxian-business` repo description with ZSE language (avoid stating it contains non-public docs if it is public).
