# Trust & Proof Messaging for Public Surfaces

This document defines how Conxian communicates trust signals on public surfaces (homepages, trust pages, pinned repos, and repository `README` sections) without leaking internal-only material.

The goal is to make every claim:

- understandable by the intended audience
- verifiable with public evidence
- conservative (no over-claims)
- consistent across repos and sites

## Definitions

**Public surface**
Any page, repository, or artifact visible to non-members (GitHub, website, docs sites, package registries).

**Claim**
A short statement about security, governance, maturity, or scope.

**Proof**
A public artifact that supports the claim (policy doc, changelog, CI config, release tags, audit report, spec).

## Trust pillars (what we communicate)

### 1) Security posture

**What we can say (safe, public):**

- How to report vulnerabilities.
- Which security practices are enforced at the repository boundary (e.g., secret hygiene, disclosure path, dependency scanning, code review ownership).
- What is _not_ promised (e.g., “not audited”, “experimental”) when appropriate.

**What to show (proof artifacts):**

- `SECURITY.md` (vulnerability reporting + disclosure expectations)
- `.github/workflows/*` (what automated checks run)
- `CODEOWNERS` (review ownership)

**What not to say (avoid internal leakage / over-claim):**

- details of incident response playbooks
- internal monitoring/alerting specifics
- “audited” unless a public, third-party audit report exists and is linked
- “production-ready” without an explicit definition and evidence

### 2) Governance standards

**What we can say:**

- Where specs and decision artifacts live (OpenSpec, changelog, PR history).
- How contribution and review work at a high level.
- Which parts of governance are public vs. handled in a private workspace.

**What to show:**

- `CONTRIBUTING.md`
- `CODEOWNERS`
- `openspec/` (public specs and change artifacts)
- `CHANGELOG.md` (decision / change log)

**What not to say:**

- private roadmap dates, strategy docs, partner negotiations
- internal discussions copied verbatim

### 3) Repo maturity (status + expectations)

Every flagship repository should declare an explicit **Status** (pick one) and keep it consistent across:

- pinned repo description
- top of `README`
- trust page listing

**Status taxonomy:**

- **Incubating**: interfaces and architecture may change frequently.
- **Beta**: core interfaces are stabilizing; breaking changes are possible but controlled.
- **Stable**: breaking changes are rare and intentional; documented migration paths exist.
- **Deprecated**: no new features; security-only fixes or archived.

To avoid ambiguity and implied guarantees, do not describe repositories as “production-ready” on public surfaces. Use the Status labels above instead.

**Proof expectations by status (examples):**

- Incubating: clear scope + changelog updates.
- Beta: minimum CI checks + basic test coverage + versioned releases.
- Stable: explicit versioning policy + release tags + changelog discipline + clear upgrade notes.
- Deprecated: clearly marked as deprecated across README, pinned description, and trust pages; document the last supported version and what happens next (maintenance-only, archived, replaced).

### 4) Release discipline

**What we can say:**

- How releases are versioned.
- Where to find release notes.
- How breaking changes are communicated.

**What to show:**

- GitHub Releases / tags (when applicable)
- `CHANGELOG.md`

**What not to say:**

- forward-looking promises as guarantees (“will ship by …”)

### 5) Audience fit

Public messaging should make it obvious who a repo/page is for.

Use one of these audience labels (or a small set):

- **Institutions / compliance reviewers**: wants policies, boundaries, proof artifacts.
- **Integrators / developers**: wants APIs, examples, compatibility, changelog.
- **Researchers**: wants specs, assumptions, references.
- **Contributors**: wants contribution and review model.

### 6) Portfolio boundaries (what is in-scope)

Each flagship surface should clearly state:

- what the project is responsible for
- what it is explicitly not responsible for
- where “internal-only” details live (without linking to private material)

The key is to prevent category errors (e.g., a reader assuming a research repo is a production service).

## Standard README section (drop-in template)

Add a **Trust & Proof** section to flagship `README`s.

```md
## Trust & Proof

**Status:** {Incubating | Beta | Stable | Deprecated}

**Scope:** What this repo does (1–2 sentences). What it does not do (1 sentence).

**Security:** See `SECURITY.md` for vulnerability reporting. This repository does not accept sensitive reports via public issues.

**Governance:** Changes are tracked via pull requests. Ownership is defined in `CODEOWNERS`. Contribution guidance is in `CONTRIBUTING.md`.

**Specs (when applicable):** When present, open specifications live under `openspec/` (or this repo’s documented specs directory).

**Releases:** See `CHANGELOG.md` for version history. If this repo uses GitHub Releases/tags, they also reflect the release history.
```

Notes:

- Keep the `Status` value identical across README, pinned description, and trust page listing.
- If the repo is not versioned via GitHub releases, say so explicitly and point at `CHANGELOG.md`.
- In actual READMEs and trust pages, prefer Markdown links for these proof artifacts.
- Ensure all referenced proof artifacts in the section exist in the repo. If any are intentionally missing, add them or remove/adjust the corresponding line.

## Pinned repo descriptions (examples)

Pinned repo descriptions should be short, conservative, and evidence-forward.

Pinned repo descriptions don’t support Markdown-formatted links. Prefer referencing proof artifacts by name/path (for example, `SECURITY.md`, `CHANGELOG.md`, `openspec/`); put clickable Markdown links in surfaces that support them (READMEs and trust pages).

1. `Sovereign operations system (BOS). Specs in openspec/. Status: Beta.`
2. `Conxian Gateway + state proofs. Security policy in SECURITY.md. Status: Incubating.`
3. `Reference implementation + OpenSpec artifacts. See CHANGELOG.md. Status: Stable.`

## Website trust page structure (recommended)

Keep the trust page as a set of proof blocks that link to public artifacts.

- **Security disclosure**: link to `SECURITY.md`
- **Governance & ownership**: link to `CODEOWNERS` and contribution policy
- **Specs & decision logs**: link to OpenSpec and changelog
- **Release discipline**: link to releases/tags + changelog
- **Portfolio boundaries**: list flagship repos with `Status`, `Scope`, and links

## Homepage proof blocks (recommended)

Homepage proof blocks should be claim + link (no long text).

- **Security disclosure path**: `SECURITY.md`
- **Open specs**: OpenSpec baseline
- **Traceable changes**: `CHANGELOG.md` + PR history
- **Clear ownership**: `CODEOWNERS`
- **Contribution model**: `CONTRIBUTING.md`
- **License clarity**: `LICENSE`

## Consistency rules

1. **No orphan claims**: every trust claim must reference a public proof artifact; link to it when the surface supports links.
2. **No internal detail**: never copy internal-only strategy, legal, or incident content into public surfaces.
3. **Prefer boundaries over hype**: “what this is / is not” beats marketing adjectives.
4. **One vocabulary**: use the Status taxonomy above everywhere.
