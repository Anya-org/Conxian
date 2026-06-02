# Conxius Wallet — BOS business buildout (CON-148)

This document defines the BOS-level business role, governance controls, and documentation separation guidance for `conxius-wallet`.

Canonical wallet docs live in the wallet repo itself (`Conxian/conxius-wallet`).


- Product spec: [`conxius-wallet/docs/business/PRD.md`](https://github.com/Conxian/conxius-wallet/blob/ef68ec49891d4a7085e499732b9fa0ce5816c1e2/docs/business/PRD.md)
- Operations roadmap: [`conxius-wallet/docs/operations/ROADMAP.md`](https://github.com/Conxian/conxius-wallet/blob/ef68ec49891d4a7085e499732b9fa0ce5816c1e2/docs/operations/ROADMAP.md)
- Risk registry: [`conxius-wallet/docs/legal/RISK_REGISTRY.md`](https://github.com/Conxian/conxius-wallet/blob/ef68ec49891d4a7085e499732b9fa0ce5816c1e2/docs/legal/RISK_REGISTRY.md)
- Protocol integration map: [`conxius-wallet/docs/protocols/IMPLEMENTATION_REGISTRY.md`](https://github.com/Conxian/conxius-wallet/blob/ef68ec49891d4a7085e499732b9fa0ce5816c1e2/docs/protocols/IMPLEMENTATION_REGISTRY.md)

Note: in this repo, those artifacts live under the `conxius-wallet/` submodule when it is checked out (for example, via `git submodule update --init conxius-wallet`). The GitHub links above pin to the wallet submodule SHA used by this repo.

If `conxius-wallet` is repinned in this repo, update the SHA in the links above at the same time to avoid documentation drift.

## 1) Business-unit role (wallet operations + product delivery)

Conxius Wallet is a **flagship** repo and part of the public Conxian trust surface. It is responsible for:

- **End-user distribution**: delivering the mobile product (Android-first) via app store releases and/or signed APK/AAB distribution.
- **Sovereign self-custody boundary**: local key custody, signing, and “never exfiltrate secrets” guarantees.
- **Protocol UX + integration surface**: providing user-facing flows for Bitcoin L1 and Bitcoin-adjacent layers while keeping custody and signing local.
- **Gateway consumption (not duplication)**: consuming Conxian Gateway APIs for cross-layer coordination and partner-powered regulated flows, without embedding centralizing operational controls in the wallet.

In BOS terms: the wallet is where **user intent becomes signed action**, and it is the primary end-user trust surface for the ecosystem.

## 2) Ownership + approvals (minimum required roles)

To keep releases safe, auditable, and supportable, the wallet repo should have explicit ownership for:

- **Wallet maintainer (mobile platform owner)**: architecture, dependency policy, build/release pipeline.
- **Security/cryptography approver**: TEE/StrongBox enforcement, key lifecycle, signing surfaces, redaction/ZSE enforcement.
- **Protocol integration approver**: new chains/L2s, bridge providers, and protocol feature flags (including deprecation).
- **Release manager**: versioning discipline, staged rollouts, rollback strategy, release notes.
- **Production support owner**: incident triage, crash/ANR monitoring, escalation policy, “stop-ship” decision authority.

This is intentionally role-based (not person-based) so it can be applied regardless of staffing.

## 3) Governance controls (release + change control)

### Change control

- Enforce `CODEOWNERS` coverage for:
  - `android/` (native + signing surface)
  - cryptography/key custody modules
  - bridge/protocol integration layers
- Protect `main`:
  - disallow force-push
  - require at least 1 approving review from the relevant owners
  - require passing CI for build/test/lint
- Treat new protocol integrations as “production interfaces” even when behind flags (they create permanent support burden).

### Release control

The wallet already contains a strong starting point for release prep. Use it as a checklist, but keep sensitive details out of git:

- Release prep (public-safe only; no store account ops, no signing key custody procedures): [`conxius-wallet/docs/operations/ANDROID_RELEASE_PREP.md`](https://github.com/Conxian/conxius-wallet/blob/ef68ec49891d4a7085e499732b9fa0ce5816c1e2/docs/operations/ANDROID_RELEASE_PREP.md)
- Device readiness (public-safe only; no production endpoint mapping): [`conxius-wallet/docs/operations/DEVICE_READINESS_REPORT.md`](https://github.com/Conxian/conxius-wallet/blob/ef68ec49891d4a7085e499732b9fa0ce5816c1e2/docs/operations/DEVICE_READINESS_REPORT.md)
- Internal-only: Play Store operations + signing key custody runbook (Linear Virtual Office)

Minimum release controls:

- A single canonical versioning scheme (SemVer + monotonic Android `versionCode`).
- A tagged git release (`vX.Y.Z`) corresponding to the shipped build and `CHANGELOG.md` entry.
- Release notes and a changelog that clearly separate:
  - user-facing changes
  - security fixes
  - protocol/integration changes
- A “stop-ship” and rollback process (at least: staged rollout + last-known-good rebuild path).

### Security and compliance boundaries

- The wallet should remain **non-custodial by construction**.
- Regulated or jurisdiction-sensitive flows should be **partner-powered** and routed through gateway/partner services, not hardcoded compliance logic in the app.
- Anything that would reveal:
  - signing key custody processes
  - app store account administration
  - production endpoints and credentials
  - vendor contracts or commercial terms
  should be treated as internal-only material.

## 4) Internal-only vs public-safe separation recommendation (ZSE)

This repo (and the wallet repo) are public. To stay aligned with ZSE:

**Public-safe (keep in git)**

- Product requirements and user-facing architecture.
- High-level threat model principles (what is protected; not how keys/ops are handled in production).
- Protocol coverage matrices / integration registries.
- Sanitized risk registry (no partner-only or exploit-adjacent detail).
- Generalized build instructions that do not embed org identifiers, account names, or secrets.

**Internal-only (migrate to Linear Virtual Office; keep git as a stub that links out)**

- Incident response runbooks, escalation trees, and “stop-ship” criteria.
- App store operational details (accounts, roles, recovery codes, signing key custody/rotation procedures).
- Production environment mapping (endpoints, feature-flag matrices by environment, partner credentials).
- Any financial/commercial terms, contract redlines, or partner negotiation notes.

## 5) Documentation and business-logic gaps affecting production support

The wallet repo has extensive product/ops documentation. The main gaps for day-2 operations are:

1. **Explicit owner map**: a short “who approves what” policy (role-based) for crypto surfaces, integrations, and releases.
2. **Incident response + comms**: a production incident playbook (even if it stays internal-only).
3. **Release provenance**: a clear path from git SHA → reproducible build artifact → rollout plan.
4. **Support intake**: a canonical support channel that feeds into issues with severity/priority conventions (avoid ad-hoc DMs as the operational substrate).
5. **Public vs internal doc classification**: tag wallet docs by visibility and migrate anything operationally sensitive.

## 6) Prioritized build/repair list

**P0 (safety + release integrity)**

- Confirm branch protections + required reviewers/owners are enforced in the wallet repo.
- Ensure release signing key custody and app store admin procedures are internal-only (Linear), not in git.
- Add an explicit “stop-ship” policy and rollback path for Play Store staged rollouts.

**P1 (operational clarity + anti-drift)**

- Add a short owner/approval policy (role-based) and link it from the wallet README.
- Define a support intake path (mailbox, form, or repo discussions) that becomes issues with clear severity.
- Standardize the wallet README role line against the repo portfolio: [`REPO_PORTFOLIO.md`](./REPO_PORTFOLIO.md).

**P2 (documentation hygiene + separation)**

- Classify wallet docs as public-safe vs internal-only and migrate internal-only docs to Linear.
- Add a “production environment matrix” doc (internal-only) that maps endpoints, flags, and partner dependencies.
