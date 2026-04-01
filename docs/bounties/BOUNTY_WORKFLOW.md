# Conxian-Labs bounty workflow (stricter)

This document defines the **Conxian-Labs** Linear bounty workflow and the operational rules that keep bounties claimable, reviewable, and non-confusing (especially before payouts are enabled).

## Goals

- Make "claimable" unambiguous.
- Prevent assignment/claim spam from being interpreted as an accepted claim.
- Keep payout expectations accurate until ConxianCSF is verifiably deployed and ALEX-funded payouts are explicitly enabled.

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

## Funding + payout constraints

- Assume **no dedicated bounty budget** unless explicitly funded through the ALEX launch path.
- Until ConxianCSF is fully deployed via ALEX on Stacks mainnet, the bounty workflow must not imply treasury-backed payout certainty.
- Once ConxianCSF is deployed, align bounty management, approval, and payout readiness through ConxianCSF.
- Once payouts are enabled, all bounty funds must come from the ALEX launch path.

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
