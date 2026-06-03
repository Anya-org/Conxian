# Canonical Naming Standard

This document defines how Conxian names public product surfaces, advanced/operator surfaces, and BOS/internal surfaces.

## Purpose

Prevent naming drift across repositories, READMEs, documentation, and user-facing applications.

## Naming layers

### 1. Public product naming
Use this language in:
- public apps
- public marketing and website copy
- public-safe README top sections
- default UI labels

Characteristics:
- simple
- standard
- user-comprehensible
- avoids unexplained acronyms and internal jargon

Examples:
- Swap
- Pools
- Positions
- Governance
- Wallet
- API key
- Dashboard
- Protocol
- Website

### 2. Advanced/operator naming
Use this language in:
- advanced product screens
- operator dashboards
- technical docs aimed at builders/operators
- observability/runbook UI where the audience is known

Characteristics:
- technical but still comprehensible
- can mention routing, attestation, telemetry, operator, policy, runtime
- should still avoid unnecessary internal-only acronyms unless explained

Examples:
- Telemetry
- Attestation
- Operator dashboard
- Runtime status
- Policy approval
- Release governance

### 3. BOS/internal naming
Use this language in:
- BOS docs
- governance control docs
- internal operating model docs
- ZSE-aware planning and control material

Characteristics:
- may use BOS/SAB/ZSE and similar internal constructs
- must be accurate and consistent
- should not leak into public UX by default

Examples:
- BOS
- SAB
- ZSE
- control domain
- lifecycle gate
- sovereign coordination layer

## Repo role naming rule

Every repo should have one stable role line.

### Format
- `Flagship — <one-line purpose>`
- `Supporting — <one-line purpose>`

### Requirements
- GitHub description and README role line should match in meaning
- one repo should not have multiple competing identities across BOS docs

## `conxian_ui` rule

`conxian_ui` must have one canonical identity.

Recommended canonical identity:
- **public web interface layer**

Allowed secondary description:
- can include advanced/operator capabilities where relevant

Not recommended as the primary identity unless the product is intentionally repositioned:
- sovereign operator dashboard
- sovereign protocol terminal
- reference-only UI

## Public-safe glossary rule

If a public-safe BOS document uses specialized acronyms or internal terminology, it should do at least one of:
- define the acronym on first use
- link to a glossary/canonical explanation
- move the term into secondary/advanced material instead of headline copy

## Naming rules by product area

### DeFi / liquidity / trading
Use standard user-facing terminology such as:
- Swap
- Pools
- Liquidity
- Positions
- Fees
- Route
- Price impact
- Minimum received
- APY

### Governance
Use:
- Governance
- Proposals
- Voting
- Delegation
- Voting history
- Proposal rules

### Developer platform
Use:
- SDK
- API
- API key
- Integration
- Configuration
- Installation
- Hosted API
- Production support

## Terms to avoid as primary public labels

- terminal
- protocol execution interface
- liquidity vector
- system auth
- custody interface
- mandate builder
- GTM integration
- system identity

## Maintenance rule

Any new repo description, README role line, or public UI label should be checked against this naming standard before merge.

## Related work
- `conxian-business` issue #718
- `conxian_ui` issue #130
