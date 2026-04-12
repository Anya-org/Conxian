# Conxian-Labs bounty workflow (stricter)

This document defines the **Conxian-Labs** Linear bounty workflow and the operational rules that keep bounties claimable, reviewable, and non-confusing (especially before payouts are enabled).

## Goals

- Make "claimable" unambiguous.
- Prevent assignment/claim spam from being interpreted as an accepted claim.
- Keep payout expectations accurate until ConxianCSF is verifiably deployed and ALEX-funded payouts are explicitly enabled.

Related policy docs:

- [`docs/bounties/CON-137_COMMUNITY_FUNDING_MODEL.md`](./CON-137_COMMUNITY_FUNDING_MODEL.md)
- [`docs/bounties/CON-231_BOUNTY_CLASSIFICATION_2026-04-12.md`](./CON-231_BOUNTY_CLASSIFICATION_2026-04-12.md)

Being claimable under this workflow means maintainers will review contributions; it does not, by itself, mean the issue is community-funded or payable.

## Status model

Recommended Linear team workflow states:

- `Triage` — inbound; not yet approved for community claiming
- `Todo` — approved and claimable (see rules below)
- `Claimed` — claim accepted; contributor is the assignee, but meaningful implementation work has not started yet
- `In Progress` — claimed and actively worked
- `In Review` — submission under maintainer review (typically a PR is open)
- `Done` — accepted and closed
- `Canceled` — withdrawn, expired, or superseded
- `Duplicate` — merged into another issue

## Operating rules (normative)

### Claimability

1. Only issues in `Todo` are claimable.
2. All claimable bounty issues **must be unassigned**.

### Assignee invariants

1. Moving an issue to `Claimed`, `In Progress`, or `In Review` must set an assignee.
2. If a bounty is abandoned or times out, move it back to `Todo` and **clear the assignee**.
3. When moving a bounty issue to `Done`, keep the assignee set for payout and audit attribution.
4. When moving a bounty issue to `Canceled` or `Duplicate`, clear the assignee.

### What counts as a claim

1. Free-text "I'd like to work on this" comments do **not** count as a claim.
2. Payment details posted in threads do **not** count as a claim and must not be treated as payout instructions.
3. The canonical claim intent is a `/claim` comment on the synced GitHub issue (if GitHub sync + automation is enabled).
4. If there is no `/claim` automation, maintainers may accept a claim by explicitly assigning the issue and moving it to `Claimed`.

### Timeboxing (anti-parking)

Within **48 hours** of assignment/claim acceptance (calendar time; resets on reassignment), the assignee must open a draft PR (or link an equivalent concrete artifact, such as an in-repo design doc, a spike branch with notes, or a reproducible test harness). If not, unassign and move the issue back to `Todo`.

## Funding + payout constraints

Normative funding/payout rules are defined in [`docs/bounties/CON-137_COMMUNITY_FUNDING_MODEL.md`](./CON-137_COMMUNITY_FUNDING_MODEL.md). In particular, treat “claimable” as reviewable work, not as a payout promise, until ConxianCSF is verifiably deployed and ALEX-funded payouts are explicitly enabled.

Maintainer-only payout enablement checklist:

- [`docs/bounties/MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md`](./MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md)

Payout-enabling controls must remain maintainer-only and must not be used until ConxianCSF is verified deployed on Stacks mainnet and the ALEX launch-path funding is ready.

## Linear configuration (maintainer)

Team workflow states are configured in Linear:

`Settings → Teams → Conxian-Labs → Issue statuses & automations`

### Suggested state types

If you have to map these to Linear's state types:

- `Triage`, `Todo`: _Unstarted_
- `Claimed`, `In Progress`, `In Review`: _Started_
- `Done`: _Completed_
- `Canceled`, `Duplicate`: _Canceled_

### Suggested automations

Linear can't reliably enforce "assignee required" on state transitions, but it can still reduce operator mistakes.

Recommended automations:

1. When a **bounty** issue moves to `Todo` → clear assignee (or enforce this manually if Linear can't scope the automation to bounty-labeled issues).
2. When a **bounty** issue moves to `Canceled` or `Duplicate` → clear assignee (or enforce this manually if Linear can't scope the automation to bounty-labeled issues).
