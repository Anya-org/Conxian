# BOS private-repo repo-check workflow (CON-454)

This document defines a reusable **repo-check workflow** for Conxian private repositories.

Goal: a consistent way to validate **public/private boundary**, **secret exposure**, **repo hygiene**, **governance baselines**, and **release maturity**, and to produce review output that is easy to hand off.

## Checklist (run in order)

### 0) Confirm boundary assumptions

Even for private repositories, treat the repo as **public for boundary purposes**:

- No secrets or key material in Git.
- No internal-only operational/strategy/legal detail in Git beyond public-safe stubs that point to Linear.

### 1) Secret exposure and sensitive configuration

1. Ensure `.env`-style files are not tracked (`.env.example` is ok).
2. Run repo secret scanning (CI): `.github/workflows/secret-scan.yml` (gitleaks).
3. Run tracked-path hygiene checks locally:

```bash
python3 scripts/verify_tracked_artifacts.py
```

### 2) Generated artifacts, vendored dependencies, and runtime outputs

Run the tracked-artifact verifier (this flags vendored deps like `node_modules/`, build outputs, and other common generated/runtime paths):

```bash
python3 scripts/verify_tracked_artifacts.py
```

If a tracked artifact is intentional, allowlist it with a narrow pattern in `.github/artifact-scan-allowlist.txt`.

### 3) Public/private separation (ZSE)

Confirm ZSE knowledge retention and migration rules are satisfied:

```bash
python3 scripts/verify_knowledge_retention.py
```

### 4) Governance baselines

Confirm the repo has the baseline governance and release docs:

- `README.md`
- `LICENSE`
- `SECURITY.md`
- `CONTRIBUTING.md`
- `CODEOWNERS`
- `GOVERNANCE.md`
- `CHANGELOG.md`
- `RELEASING.md`

Then run the governance baseline verifier:

```bash
python3 scripts/verify_repo_governance_baseline.py
```

### 5) Release/versioning discipline and required checks

1. Validate changelog structure and tag expectations:

```bash
python3 scripts/verify_release_hygiene.py
```

2. Confirm required CI checks exist and run on PRs to `dev`, `staged`, and `main`:

- `.github/workflows/conxian-unified-ci.yml`
- `.github/workflows/dependency-review.yml`
- `.github/workflows/secret-scan.yml`
- `.github/workflows/branch-promotion-policy.yml`

### 6) Portfolio clarity (for BOS superprojects)

If the repo vendors other repos (git submodules), confirm:

1. Submodules are pinned correctly:

```bash
python3 scripts/verify_submodule_integrity.py
git submodule status --recursive
```

2. Portfolio docs are up to date:

- `docs/REPO_PORTFOLIO.md`
- `docs/PORTFOLIO_BUSINESS_UNIT_MAP.md`

## One-command runner

For local reviews, this repo provides a convenience runner that executes the repo-check verifiers in a standard order:

```bash
python3 scripts/bos_repo_check.py
```

## Remediation sequence (recommended)

When findings are present, remediate in this order:

1. **Secrets and secret-adjacent files**
   - rotate/revoke first, then remove from git history as needed
2. **ZSE boundary violations**
   - migrate internal-only documents to Linear and replace with public-safe stubs
3. **Tracked artifacts / generated outputs**
   - `git rm --cached <path>` then expand `.gitignore`
4. **Governance baseline gaps**
   - add/repair `SECURITY.md`, `CODEOWNERS`, release docs, etc.
5. **Release maturity gaps**
   - ensure `CHANGELOG.md` discipline, tags, and required checks

## Prioritized findings (this repository, as of April 8, 2026)

### Security

- **Secret scanning coverage gap (fixed):** `secret-scan.yml` previously only ran on `main`. It now runs on PRs and pushes targeting `dev`, `staged`, and `main`.
- **Filename-level secret hygiene (already enforced):** `scripts/verify_tracked_artifacts.py` blocks common secret-bearing filenames (for example `.env`, `.env.*` except templates, and private key formats).

### Hygiene

- **No single “repo-check” entrypoint (fixed):** added `scripts/bos_repo_check.py` to run the BOS hygiene + governance verifiers locally in a consistent order.
- **Submodule pin drift (fixed):** updated the `conxian-nexus` and `lib-conxian-core` gitlink pins to match the current upstream default branches so `scripts/verify_submodule_integrity.py` remains a stable gate.

### Governance

- **Governance baseline CI gate missing (fixed):** added `scripts/verify_repo_governance_baseline.py` and wired it into the `Repo Hygiene` job in `.github/workflows/conxian-unified-ci.yml`.
- **Visibility language drift (partially fixed):** several top-level docs used the sentence “This repository is public.” While the repo is private today, Conxian policy is to treat it as public for boundary purposes.
  - Updated `GOVERNANCE.md`, `docs/BOS_BUSINESS_BUILDOUT.md`, `docs/DOCUMENTATION_ALIGNMENT_INDEX.md`, and `docs/templates/ZSE_STUB_TEMPLATE.md`.
  - Remaining stub docs should be updated opportunistically as they’re touched.

### Release maturity

- **Required-check guidance (improved):** `.github/RELEASE_HYGIENE.md` now lists the governance baseline verifier as part of the expected always-on repo hygiene suite.

## Ownership handoff (template)

Use this format to hand off a repo-check review to the responsible owners.

- **Repo owners (CODEOWNERS):** see `CODEOWNERS` (`*` rule)
- **Security owner:** repo owners unless a narrower owner is defined in `CODEOWNERS`
- **Release owner:** repo owners unless a narrower owner is defined in `CODEOWNERS` / `RELEASING.md`

Handoff note template:

```text
Owner: <GitHub handle(s) from CODEOWNERS>
Scope: <security | hygiene | governance | release>
Finding: <1 sentence>
Recommended remediation: <1-3 concrete steps>
Evidence: <link to CI run / file path / script output excerpt>
```
