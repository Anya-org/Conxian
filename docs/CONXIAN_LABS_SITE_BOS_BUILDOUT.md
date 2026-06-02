# conxian-labs-site — BOS business buildout (CON-172)

This document defines the BOS-level business role, governance controls, and documentation separation guidance for the public `conxian-labs-site` repository.

## 1) Business-unit role (Public Communication)

Per the repo portfolio, `conxian-labs-site` is an **operating function** repo:

- **Portfolio classification**: `Operating function — Public marketing and documentation site.`
- **Business Purpose (External)**: Serve as the definitive public entry point for Conxian, providing high-level narratives, documentation portals, and community-facing information.
- **Business Purpose (Internal)**: Act as the primary channel for communicating system status, roadmap updates, and ecosystem growth to external stakeholders.

## 2) Workflow Governance and Approval Paths

- **Brand Integrity**: All content changes must align with Conxian brand guidelines and messaging standards.
- **Approval Model**: PRs require review from the Communications/Marketing lead (`@botshelomokoka`).
- **Update Rhythm**: Site updates should be coordinated with major protocol or product releases to maintain narrative consistency.

## 3) Separating Public Messaging from Internal Strategy

- **Public Messaging**: Landing page copy, public documentation, and community blog posts (Git).
- **Internal Strategy**: Detailed M&A narratives, confidential partnership notes, and granular financial projections (Linear Virtual Office).

## 4) Business Logic and Documentation Gaps

- **Gap**: Missing standardized "Press Kit" for external media.
- **Gap**: Lack of explicit "Release Support" requirements for updating site documentation during product launches.

## 5) Prioritized Build/Repair List

**P0 (Site Integrity)**
- Audit for ZSE compliance (remove any accidental strategy leaks).
- Ensure all repository links point to the canonical flagship repositories.

**P1 (Communication Maturity)**
- Add standardized `README.md` (Purpose, Status, Ownership, Releases).
- Implement explicit review gates for strategic copy changes.

**P2 (Documentation Alignment)**
- Standardize `CHANGELOG.md` for the website itself.
- Migrate any internal-only roadmap drafts to Linear.
